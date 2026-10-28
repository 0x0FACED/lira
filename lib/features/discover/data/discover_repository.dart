import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/discover_item.dart';
import '../domain/discover_source.dart';
import 'discover_epub.dart';
import 'discover_feed_parser.dart';

class DiscoverRepository {
  DiscoverRepository({Dio? dio, Directory? directory, DateTime Function()? now})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
              headers: {'User-Agent': 'Lira/Discover (offline reading)'},
            ),
          ),
      _directory = directory,
      _now = now ?? DateTime.now;

  final Dio _dio;
  final Directory? _directory;
  final DateTime Function() _now;
  final _memory = <String, _Snapshot>{};
  final _inFlight = <String, Future<_Snapshot>>{};
  final _retryAfter = <String, DateTime>{};

  Future<Directory> _cacheDirectory() async =>
      _directory ??
      Directory(
        p.join((await getApplicationSupportDirectory()).path, 'discover'),
      );
  String _key(DiscoverSource source) => sha256
      .convert(utf8.encode('${source.id}\n${_endpoint(source)}'))
      .toString();

  Uri _endpoint(DiscoverSource source) {
    if (source.kind == DiscoverSourceKind.rfc) {
      return Uri.https('www.rfc-editor.org', '/rfc-index.xml');
    }
    if (source.kind != DiscoverSourceKind.rss || source.feedUrl == null) {
      throw UnsupportedError('This source is search-only: ${source.id}');
    }
    return canonicalDiscoverUrl(Uri.parse(source.feedUrl!));
  }

  Future<DiscoverFeed> feed(
    DiscoverSource source, {
    bool refresh = false,
  }) async {
    final snapshot = await _snapshot(source, refresh: refresh);
    return DiscoverFeed(
      items: source.kind == DiscoverSourceKind.rfc
          ? snapshot.items.take(40).toList(growable: false)
          : snapshot.items,
      updatedAt: snapshot.updatedAt,
      isStale: snapshot.isStale,
    );
  }

  Future<List<DiscoverItem>> search(DiscoverSource source, String query) async {
    if (query.trim().isEmpty) return const [];
    final snapshot = await _snapshot(source);
    final items = snapshot.items;
    return Isolate.run(() => searchDiscoverMetadata(items, query));
  }

  Future<_Snapshot> _snapshot(DiscoverSource source, {bool refresh = false}) {
    final key = _key(source);
    return _inFlight[key] ??= _load(source, key, refresh: refresh).whenComplete(
      () {
        _inFlight.remove(key);
      },
    );
  }

  Future<_Snapshot> _load(
    DiscoverSource source,
    String key, {
    required bool refresh,
  }) async {
    var cached = _memory[key];
    final directory = await _cacheDirectory();
    final file = File(p.join(directory.path, '$key.json'));
    if (cached == null) {
      try {
        final raw = await file.readAsString();
        final sourceId = source.id;
        cached = await Isolate.run(() => _decodeSnapshot(raw, sourceId));
      } on FileSystemException {
        // A missing cache must not mask the source's actual network result.
      } on FormatException {
        // Interrupted or obsolete cache files are not usable offline data.
      } on TypeError {
        // Treat invalid cache field types in the same way as malformed JSON.
      }
    }
    final now = _now().toUtc();
    final ttl = source.kind == DiscoverSourceKind.rfc
        ? const Duration(hours: 24)
        : const Duration(minutes: 30);
    if (!refresh &&
        cached != null &&
        (now.difference(cached.updatedAt) < ttl ||
            (_retryAfter[key]?.isAfter(now) ?? false))) {
      _memory[key] = cached;
      return cached;
    }
    try {
      final response = await _dio.getUri<String>(
        _endpoint(source),
        options: Options(responseType: ResponseType.plain),
      );
      final raw = response.data;
      if (raw == null || raw.trim().isEmpty) {
        throw const FormatException('The source returned an empty response');
      }
      final items = await Isolate.run(() => parseDiscoverMetadata(raw, source));
      final snapshot = _Snapshot(items, now);
      // Encoding the complete RFC index is CPU work too, not just XML parsing.
      final encoded = await Isolate.run(
        () => jsonEncode({
          'version': 1,
          'updatedAt': now.toIso8601String(),
          'items': items.map((item) => item.toJson()).toList(),
        }),
      );
      try {
        await directory.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(encoded, flush: true);
        await temporary.rename(file.path);
      } on FileSystemException {
        // Fresh content remains usable if the device cannot persist metadata.
      }
      _retryAfter.remove(key);
      _memory[key] = snapshot;
      return snapshot;
    } catch (_) {
      if (cached == null) rethrow;
      final stale = _Snapshot(cached.items, cached.updatedAt, isStale: true);
      _memory[key] = stale;
      _retryAfter[key] = now.add(const Duration(minutes: 5));
      return stale;
    }
  }

  Future<Uint8List> buildEpub(DiscoverItem item) =>
      DiscoverEpubBuilder(_dio).build(item);

  void close() => _dio.close();
}

class _Snapshot {
  const _Snapshot(this.items, this.updatedAt, {this.isStale = false});
  final List<DiscoverItem> items;
  final DateTime updatedAt;
  final bool isStale;
}

_Snapshot _decodeSnapshot(String raw, String sourceId) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  if (json['version'] != 1)
    throw const FormatException('Unknown Discover cache version');
  final items = (json['items'] as List<dynamic>)
      .map((item) => DiscoverItem.fromJson(item as Map<String, dynamic>))
      .toList();
  if (items.isEmpty ||
      items.any(
        (item) =>
            item.sourceId != sourceId ||
            item.id != discoverMaterialId(item.url),
      )) {
    throw const FormatException('Invalid Discover cache items');
  }
  return _Snapshot(items, DateTime.parse(json['updatedAt'] as String));
}
