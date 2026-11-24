import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

/// Validated ISBNs are represented as ISBN-13, including ISBN-10 inputs.
String? normalizeIsbn(String value) {
  var digits = value
      .trim()
      .replaceFirst(
        RegExp(r'^(?:urn:isbn:|isbn(?:-1[03])?\s*:)\s*', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'[\s-]'), '')
      .toUpperCase();
  if (RegExp(r'^\d{9}[\dX]$').hasMatch(digits)) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += (10 - i) * (digits[i] == 'X' ? 10 : int.parse(digits[i]));
    }
    if (sum % 11 != 0) return null;
    digits = '978${digits.substring(0, 9)}';
    var sum13 = 0;
    for (var i = 0; i < 12; i++) {
      sum13 += int.parse(digits[i]) * (i.isEven ? 1 : 3);
    }
    return '$digits${(10 - sum13 % 10) % 10}';
  }
  if (!RegExp(r'^97[89]\d{10}$').hasMatch(digits)) return null;
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += int.parse(digits[i]) * (i.isEven ? 1 : 3);
  }
  return sum % 10 == 0 ? digits : null;
}

class OpenLibraryCandidate {
  OpenLibraryCandidate({
    required this.workKey,
    this.editionKey,
    required this.title,
    required List<String> authors,
    required List<String> subjects,
    this.coverId,
    this.coverFromEdition = false,
    this.language,
    this.year,
    List<String> isbns = const [],
  }) : authors = List.unmodifiable(authors),
       subjects = List.unmodifiable(subjects),
       isbns = List.unmodifiable(isbns);

  final String workKey;
  final String? editionKey;
  final String title;
  final List<String> authors;
  final List<String> subjects;
  final int? coverId;
  final bool coverFromEdition;
  final String? language;
  final int? year;
  final List<String> isbns;

  String get author => authors.join(', ');
  Uri get sourceUri => Uri.https('openlibrary.org', editionKey ?? workKey);
}

class OpenLibraryCover {
  const OpenLibraryCover({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Public, credential-free metadata transport. Inject a dedicated HTTP client
/// for tests; the provider supplies the application's SOCKS-aware client.
class OpenLibraryClient {
  OpenLibraryClient({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
    this.searchInterval = const Duration(seconds: 1),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration requestTimeout;
  final Duration searchInterval;
  final _searchCache = LinkedHashMap<String, List<OpenLibraryCandidate>>();
  final _searchPending = <String, Future<List<OpenLibraryCandidate>>>{};
  final _coverCache = LinkedHashMap<int, OpenLibraryCover?>();
  final _coverPending = <int, Future<OpenLibraryCover?>>{};
  final _aborts = <Completer<void>>{};
  final _clock = Stopwatch()..start();
  Future<void> _searchQueue = Future.value();
  Duration? _lastSearch;
  int _coverBytes = 0;
  bool _closed = false;

  static const _fields =
      'key,title,author_name,subject,cover_i,editions,'
      'editions.key,editions.title,editions.isbn,editions.cover_i,'
      'editions.language,editions.publish_year,first_publish_year';
  static const _maxJsonBytes = 2 * 1024 * 1024;
  static const _maxCoverBytes = 8 * 1024 * 1024;
  static const _coverCacheBytes = 16 * 1024 * 1024;
  static const _maxExactDocuments = 1000;

  Future<List<OpenLibraryCandidate>> search({
    String? isbn,
    String? title,
    String? author,
    String? language,
  }) {
    if (_closed)
      return Future.error(StateError('Open Library client is closed'));
    final exact = isbn == null ? null : normalizeIsbn(isbn);
    // An invalid supplied ISBN must never turn into a fuzzy title search.
    if (isbn != null && exact == null) return Future.value(const []);
    final cleanTitle = _text(title);
    final cleanAuthor = _text(author);
    if (exact == null && cleanTitle == null && cleanAuthor == null) {
      return Future.value(const []);
    }
    final parameters = <String, String>{
      if (exact != null) 'q': 'isbn:$exact',
      if (exact == null && cleanTitle != null) 'title': cleanTitle,
      if (exact == null && cleanAuthor != null) 'author': cleanAuthor,
      if (exact == null && _preferredLanguage(language) != null)
        'lang': _preferredLanguage(language)!,
      'fields': _fields,
      'limit': exact == null ? '20' : '100',
    };
    final key = Uri.https(
      'openlibrary.org',
      '/search.json',
      parameters,
    ).toString();
    final cached = _searchCache.remove(key);
    if (cached != null) {
      _searchCache[key] = cached;
      return Future.value(cached);
    }
    final pending = _searchPending[key];
    if (pending != null) return pending;
    if (_searchPending.length >= 32) {
      return Future.error(StateError('Too many pending Open Library searches'));
    }
    final future = _search(parameters, exact)
        .then((results) {
          final immutable = List<OpenLibraryCandidate>.unmodifiable(results);
          if (!_closed) {
            _searchCache[key] = immutable;
            if (_searchCache.length > 32)
              _searchCache.remove(_searchCache.keys.first);
          }
          return immutable;
        })
        .whenComplete(() {
          _searchPending.remove(key);
        });
    _searchPending[key] = future;
    return future;
  }

  Future<List<OpenLibraryCandidate>> _search(
    Map<String, String> parameters,
    String? exact,
  ) async {
    final candidates = <String, OpenLibraryCandidate>{};
    var offset = 0;
    while (true) {
      final page = await _queuedJson(
        Uri.https('openlibrary.org', '/search.json', {
          ...parameters,
          if (offset > 0) 'offset': '$offset',
        }),
      );
      final docs = page['docs'];
      if (docs is! List)
        throw const FormatException('Missing Open Library docs');
      if (exact != null && page['numFoundExact'] == false) {
        throw const FormatException('Incomplete ISBN search');
      }
      final total = _integer(page['numFound'] ?? page['num_found']);
      if (exact != null && total != null && total > _maxExactDocuments) {
        throw const FormatException('ISBN search is too large to disambiguate');
      }
      for (final doc in docs.whereType<Map>()) {
        final workKey = _key(doc['key'], 'works', 'W');
        if (workKey == null) continue;
        final editions = doc['editions'];
        final editionDocs = editions is Map && editions['docs'] is List
            ? (editions['docs'] as List).whereType<Map>().toList()
            : <Map>[];
        final count = editions is Map ? _integer(editions['numFound']) : null;
        // The search API currently returns at most one edition. Expand only
        // when necessary, so a shared ISBN cannot look uniquely confirmed.
        final expanded =
            exact != null && count != null && count > editionDocs.length;
        final records = expanded
            ? await _matchingEditions(workKey, exact)
            : editionDocs;
        if (records.isEmpty && exact == null) {
          final candidate = _candidate(doc, null, detail: false);
          if (candidate != null)
            candidates.putIfAbsent(workKey, () => candidate);
        }
        for (final edition in records) {
          final candidate = _candidate(doc, edition, detail: expanded);
          if (candidate == null) continue;
          if (exact != null &&
              (candidate.editionKey == null ||
                  !candidate.isbns.contains(exact))) {
            continue;
          }
          candidates.putIfAbsent(
            candidate.editionKey ?? workKey,
            () => candidate,
          );
        }
      }
      if (exact == null) break;
      offset += docs.length;
      if (total != null && offset >= total) break;
      if (docs.isEmpty || (total == null && docs.length < 100)) {
        if (total != null && offset < total) {
          throw const FormatException('Incomplete ISBN search page');
        }
        break;
      }
      if (offset >= _maxExactDocuments) {
        throw const FormatException('ISBN search is too large to disambiguate');
      }
    }
    return candidates.values.toList(growable: false);
  }

  Future<List<Map>> _matchingEditions(String workKey, String isbn) async {
    final matches = <Map>[];
    var offset = 0;
    while (true) {
      final page = await _queuedJson(
        Uri.https('openlibrary.org', '$workKey/editions.json', {
          'limit': '100',
          'offset': '$offset',
        }),
      );
      final entries = page['entries'];
      if (entries is! List)
        throw const FormatException('Missing work editions');
      final total = _integer(page['size']);
      if (total != null && total > _maxExactDocuments) {
        throw const FormatException('Too many editions to confirm an ISBN');
      }
      for (final edition in entries.whereType<Map>()) {
        if (_isbns(edition, detail: true).contains(isbn)) matches.add(edition);
      }
      offset += entries.length;
      if (total != null && offset >= total) break;
      if (entries.isEmpty || (total == null && entries.length < 100)) {
        if (total != null && offset < total) {
          throw const FormatException('Incomplete work editions');
        }
        break;
      }
      if (offset >= _maxExactDocuments) {
        throw const FormatException('Too many editions to confirm an ISBN');
      }
    }
    return matches;
  }

  static OpenLibraryCandidate? _candidate(
    Map work,
    Map? edition, {
    required bool detail,
  }) {
    final workKey = _key(work['key'], 'works', 'W');
    final title = _text(edition?['title']) ?? _text(work['title']);
    if (workKey == null || title == null) return null;
    final editionKey = _key(edition?['key'], 'books', 'M');
    final cover = detail
        ? _positiveIds(edition?['covers']).firstOrNull
        : _positive(edition?['cover_i']);
    final languageValue = edition?['language'] ?? edition?['languages'];
    final languages = languageValue is List ? languageValue : [languageValue];
    final language = languages
        .map((value) {
          if (value is Map) value = value['key'];
          return _text(value)?.replaceFirst('/languages/', '');
        })
        .whereType<String>()
        .firstOrNull;
    return OpenLibraryCandidate(
      workKey: workKey,
      editionKey: editionKey,
      title: title,
      authors: _strings(work['author_name'], limit: 32),
      subjects: _strings(work['subject'], limit: 256),
      coverId: cover ?? _positive(work['cover_i']),
      coverFromEdition: cover != null,
      language: language,
      year: editionKey == null
          ? _year(work['first_publish_year'])
          : _editionYear(edition!, detail: detail),
      isbns: edition == null ? const [] : _isbns(edition, detail: detail),
    );
  }

  Future<Map> _queuedJson(Uri uri) {
    final operation = _searchQueue.then((_) async {
      if (_closed) throw StateError('Open Library client is closed');
      final previous = _lastSearch;
      if (previous != null) {
        final wait = searchInterval - (_clock.elapsed - previous);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      if (_closed) throw StateError('Open Library client is closed');
      _lastSearch = _clock.elapsed;
      final response = await _download(
        uri,
        cover: false,
        maxBytes: _maxJsonBytes,
      );
      final decoded = jsonDecode(utf8.decode(response!));
      if (decoded is! Map)
        throw const FormatException('Invalid Open Library response');
      return decoded;
    });
    _searchQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<OpenLibraryCover?> fetchCover(int coverId) {
    if (_closed)
      return Future.error(StateError('Open Library client is closed'));
    if (coverId <= 0) return Future.value(null);
    if (_coverCache.containsKey(coverId)) {
      final cached = _coverCache.remove(coverId);
      _coverCache[coverId] = cached;
      return Future.value(cached);
    }
    final pending = _coverPending[coverId];
    if (pending != null) return pending;
    if (_coverPending.length >= 8) {
      return Future.error(StateError('Too many pending Open Library covers'));
    }
    final future = _loadCover(coverId)
        .then((cover) {
          if (!_closed) {
            _coverCache[coverId] = cover;
            _coverBytes += cover?.bytes.length ?? 0;
            while (_coverCache.length > 16 || _coverBytes > _coverCacheBytes) {
              _coverBytes -=
                  _coverCache.remove(_coverCache.keys.first)?.bytes.length ?? 0;
            }
          }
          return cover;
        })
        .whenComplete(() {
          _coverPending.remove(coverId);
        });
    _coverPending[coverId] = future;
    return future;
  }

  Future<OpenLibraryCover?> _loadCover(int id) async {
    Uint8List? bytes;
    try {
      bytes = await _download(
        Uri.https('covers.openlibrary.org', '/b/id/$id-L.jpg', {
          'default': 'false',
        }),
        cover: true,
        maxBytes: _maxCoverBytes,
      );
    } on _OversizedResponse {
      return null;
    }
    if (bytes == null ||
        bytes.length < 4 ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[bytes.length - 2] != 0xff ||
        bytes.last != 0xd9)
      return null;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      // Inspect encoded dimensions before allocating pixels. Decode only a
      // thumbnail for validation, not a full potentially enormous image.
      if (width < 32 ||
          height < 32 ||
          width > 4096 ||
          height > 4096 ||
          width * height > 4 * 1024 * 1024)
        return null;
      codec = await descriptor.instantiateCodec(
        targetWidth: math.min(64, width),
        targetHeight: math.min(64, height),
      );
      image = (await codec.getNextFrame()).image;
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (pixels == null) return null;
      final minimum = [255, 255, 255];
      final maximum = [0, 0, 0];
      for (var i = 0; i + 3 < pixels.lengthInBytes; i += 4) {
        for (var channel = 0; channel < 3; channel++) {
          final value = pixels.getUint8(i + channel);
          minimum[channel] = math.min(minimum[channel], value);
          maximum[channel] = math.max(maximum[channel], value);
        }
      }
      if (!List.generate(
        3,
        (i) => maximum[i] - minimum[i],
      ).any((range) => range > 12)) {
        return null;
      }
      return OpenLibraryCover(bytes: bytes, width: width, height: height);
    } catch (_) {
      // Invalid image data is not a transport error and must not replace a cover.
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  Future<Uint8List?> _download(
    Uri initial, {
    required bool cover,
    required int maxBytes,
  }) async {
    final abort = Completer<void>();
    _aborts.add(abort);
    final timer = Timer(requestTimeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    final deadline = _clock.elapsed + requestTimeout;
    Duration remaining() {
      final duration = deadline - _clock.elapsed;
      if (duration <= Duration.zero)
        throw TimeoutException('Open Library request timed out');
      return duration;
    }

    var uri = initial;
    try {
      for (var redirects = 0; redirects <= 5; redirects++) {
        if (_closed) throw StateError('Open Library client is closed');
        final request =
            http.AbortableRequest('GET', uri, abortTrigger: abort.future)
              ..followRedirects = false
              ..headers.addAll({
                'Accept': cover ? 'image/jpeg' : 'application/json',
                'User-Agent': 'Lira (https://github.com/0x0FACED/lira/issues)',
              });
        final response = await _client.send(request).timeout(remaining());
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers['location'];
          await response.stream.listen(null).cancel();
          if (location == null || redirects == 5) {
            throw http.ClientException('Invalid Open Library redirect', uri);
          }
          final next = uri.resolve(location);
          if (!_allowedRedirect(next, cover: cover)) {
            throw http.ClientException('Unsafe Open Library redirect', next);
          }
          uri = next;
          continue;
        }
        if (cover && response.statusCode == 404) {
          await response.stream.listen(null).cancel();
          return null;
        }
        if (response.statusCode != 200) {
          await response.stream.listen(null).cancel();
          throw http.ClientException(
            'Open Library HTTP ${response.statusCode}',
            uri,
          );
        }
        if ((response.contentLength ?? 0) > maxBytes) {
          await response.stream.listen(null).cancel();
          throw const _OversizedResponse();
        }
        final iterator = StreamIterator(response.stream);
        final builder = BytesBuilder(copy: false);
        try {
          while (await iterator.moveNext().timeout(remaining())) {
            if (iterator.current.length > maxBytes - builder.length) {
              throw const _OversizedResponse();
            }
            builder.add(iterator.current);
          }
        } finally {
          await iterator.cancel();
        }
        return builder.takeBytes();
      }
      throw http.ClientException('Too many Open Library redirects', uri);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
    }
  }

  static bool _allowedRedirect(Uri uri, {required bool cover}) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.port != 443)
      return false;
    if (!cover) return uri.host == 'openlibrary.org';
    // Covers redirect to archive.org ZIP members, then ia*.us.archive.org.
    return uri.host == 'covers.openlibrary.org' ||
        uri.host == 'archive.org' ||
        uri.host.endsWith('.archive.org');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
    _searchCache.clear();
    _coverCache.clear();
    _coverBytes = 0;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.isEmpty || text.length > 2048 ? null : text;
  }

  static List<String> _strings(Object? value, {required int limit}) {
    if (value is! List) return const [];
    return value
        .map(_text)
        .whereType<String>()
        .take(limit)
        .toSet()
        .toList(growable: false);
  }

  static int? _integer(Object? value) => value is int ? value : null;
  static int? _positive(Object? value) =>
      value is int && value > 0 ? value : null;
  static int? _year(Object? value) =>
      value is int && value > 0 && value <= 9999 ? value : null;
  static int? _editionYear(Map edition, {required bool detail}) {
    if (detail) {
      final date = _text(edition['publish_date']);
      final year = date == null ? null : RegExp(r'\b\d{4}\b').firstMatch(date);
      return year == null ? null : _year(int.tryParse(year[0]!));
    }
    final years = edition['publish_year'];
    return years is List ? years.map(_year).whereType<int>().firstOrNull : null;
  }

  static Iterable<int> _positiveIds(Object? value) =>
      value is List ? value.map(_positive).whereType<int>() : const <int>[];

  static String? _key(Object? value, String collection, String suffix) {
    final text = _text(value);
    if (text == null) return null;
    final id = text.replaceFirst('/$collection/', '');
    return RegExp('^OL[0-9]+$suffix\$').hasMatch(id)
        ? '/$collection/$id'
        : null;
  }

  static List<String> _isbns(Map edition, {required bool detail}) {
    final values = detail
        ? [
            ...(edition['isbn_10'] is List
                ? edition['isbn_10'] as List
                : const []),
            ...(edition['isbn_13'] is List
                ? edition['isbn_13'] as List
                : const []),
          ]
        : (edition['isbn'] is List ? edition['isbn'] as List : const []);
    return values
        .whereType<String>()
        .map(normalizeIsbn)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  static String? _preferredLanguage(String? value) {
    final language = value?.trim().toLowerCase().split(RegExp('[-_]')).first;
    if (language == null) return null;
    if (RegExp(r'^[a-z]{2}$').hasMatch(language)) return language;
    return const {
      'eng': 'en',
      'rus': 'ru',
      'ukr': 'uk',
      'bel': 'be',
      'fra': 'fr',
      'fre': 'fr',
      'deu': 'de',
      'ger': 'de',
      'spa': 'es',
      'ita': 'it',
      'por': 'pt',
      'nld': 'nl',
      'dut': 'nl',
      'pol': 'pl',
      'ces': 'cs',
      'cze': 'cs',
      'slk': 'sk',
      'slo': 'sk',
      'dan': 'da',
      'swe': 'sv',
      'nor': 'no',
      'fin': 'fi',
      'isl': 'is',
      'ell': 'el',
      'gre': 'el',
      'tur': 'tr',
      'ara': 'ar',
      'heb': 'he',
      'fas': 'fa',
      'per': 'fa',
      'hin': 'hi',
      'ben': 'bn',
      'jpn': 'ja',
      'zho': 'zh',
      'chi': 'zh',
      'kor': 'ko',
      'vie': 'vi',
      'ind': 'id',
      'ron': 'ro',
      'rum': 'ro',
      'hun': 'hu',
      'bul': 'bg',
      'srp': 'sr',
      'hrv': 'hr',
      'slv': 'sl',
      'lit': 'lt',
      'lav': 'lv',
      'est': 'et',
    }[language];
  }
}

class _OversizedResponse implements Exception {
  const _OversizedResponse();
}
