import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../domain/models/search_result_item.dart';

// Published in the Alternatives menu on https://annas-archive.gd/.
const List<String> defaultAnnaArchiveMirrors = [
  'https://annas-archive.gd',
  'https://annas-archive.pk',
  'https://annas-archive.gl',
];

enum AnnaArchiveFailureKind { network, http, challenge, markup, unavailable }

class AnnaArchivePageException implements Exception {
  const AnnaArchivePageException({
    required this.uri,
    required this.kind,
    required this.message,
    this.statusCode,
    this.responseExcerpt = '',
  });

  final Uri uri;
  final AnnaArchiveFailureKind kind;
  final String message;
  final int? statusCode;
  final String responseExcerpt;

  @override
  String toString() =>
      'Anna’s Archive ${kind.name} at $uri'
      '${statusCode == null ? '' : ' (HTTP $statusCode)'}: $message';
}

class AnnaArchiveAttempt {
  const AnnaArchiveAttempt(this.uri, this.error, this.stackTrace);
  final Uri uri;
  final Object error;
  final StackTrace stackTrace;
}

/// Keeps every original transport/parser error, rather than turning a failed
/// source into an apparently successful, empty catalog.
class AnnaArchiveException implements Exception {
  AnnaArchiveException(Iterable<AnnaArchiveAttempt> attempts)
    : attempts = List.unmodifiable(attempts);

  final List<AnnaArchiveAttempt> attempts;

  @override
  String toString() =>
      attempts.map((attempt) => '${attempt.uri}: ${attempt.error}').join('; ');
}

class AnnaArchiveClient {
  AnnaArchiveClient({
    Dio? dio,
    List<String>? mirrors,
    Map<String, String>? cookies,
    String? userAgent,
    String? sessionOrigin,
  }) : _dio = dio ?? Dio(),
       _userAgent = userAgent,
       _mirrors = _parseMirrors(mirrors ?? defaultAnnaArchiveMirrors) {
    _dio.options.connectTimeout ??= const Duration(seconds: 12);
    if (cookies != null && cookies.isNotEmpty) {
      final origin = sessionOrigin == null
          ? _mirrors.first
          : _parseMirrors([sessionOrigin]).single;
      final index = _mirrors.indexOf(origin);
      if (index == -1) {
        throw ArgumentError('The session origin must be a configured mirror');
      }
      if (cookies.entries.any(
        (entry) =>
            !_cookieName.hasMatch(entry.key) ||
            _invalidCookieValue.hasMatch(entry.value),
      )) {
        throw ArgumentError('Invalid source session cookie syntax');
      }
      // Browser clearance can be IP/UA bound. It is supplied by the user, not
      // generated here, and must never be forwarded to a different mirror.
      _cookies[origin.origin] = Map.of(cookies);
      _activeMirror = index;
    }
  }

  final Dio _dio;
  final String? _userAgent;
  final List<Uri> _mirrors;
  final _cookies = <String, Map<String, String>>{};
  int _activeMirror = 0;

  static final _md5 = RegExp(r'^[a-fA-F0-9]{32}$');
  static final _format = RegExp(
    r'^(epub|pdf|djvu|mobi|azw3|fb2|txt|docx?|rtf|cbr|cbz|zip)$',
    caseSensitive: false,
  );
  static final _size = RegExp(
    r'^\d+(?:[.,]\d+)?\s*(?:[KMGT]i?B|bytes?)$',
    caseSensitive: false,
  );
  static final _whitespace = RegExp(r'\s+');
  static final _cookieName = RegExp(r'^[!#$%&\x27*+\-.^_`|~0-9A-Za-z]+$');
  static final _invalidCookieValue = RegExp(r'[\x00-\x20\x7f;]');
  static final _deletedCookie = RegExp(
    r'(?:^|;)\s*max-age=0(?:;|$)',
    caseSensitive: false,
  );
  static final _downloadExtension = RegExp(
    r'\.(?:epub|pdf)$',
    caseSensitive: false,
  );

  Future<List<SearchResultItem>> search(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    return _onMirrors((mirror) async {
      final uri = mirror.replace(
        path: '/search',
        queryParameters: {
          'q': term,
          'ext': ['epub', 'pdf'],
          'display': 'list',
        },
      );
      final page = await _getPage(uri);
      return _parseSearch(page.document, page.uri);
    });
  }

  Future<List<String>> getDownloadLinks(String md5) async {
    final hash = md5.trim().toLowerCase();
    if (!_md5.hasMatch(hash)) {
      throw ArgumentError.value(md5, 'md5', 'Expected a 32-character MD5');
    }
    return _onMirrors((mirror) async {
      final page = await _getPage(mirror.resolve('/md5/$hash'));
      final panel = page.document.querySelector('#md5-panel-downloads');
      if (panel == null) {
        throw _markup(page.uri, 'Missing file download panel');
      }
      final links = <String>{};
      final failures = <AnnaArchiveAttempt>[];
      final visited = <Uri>{};
      var hasMediatedDownload = false;
      for (final anchor in panel.querySelectorAll('a.js-download-link[href]')) {
        final uri = _webUri(page.uri, anchor.attributes['href']);
        if (uri == null || !visited.add(uri)) continue;
        if (uri.path.startsWith('/fast_download/') ||
            uri.path.startsWith('/slow_download/')) {
          hasMediatedDownload = true;
          continue;
        }
        if (_isDirectDownload(uri, anchor)) {
          links.add(uri.toString());
        } else if (links.isEmpty &&
            uri.origin == page.uri.origin &&
            uri.path == '/ipfs_downloads/md5:$hash') {
          try {
            final gateways = await _getPage(uri);
            for (final target in gateways.document.querySelectorAll(
              'main li a[href]',
            )) {
              final resolved = _webUri(gateways.uri, target.attributes['href']);
              if (resolved != null && resolved.path.startsWith('/ipfs/')) {
                links.add(resolved.toString());
              }
            }
            if (links.isEmpty) {
              throw _markup(
                gateways.uri,
                'Missing published IPFS gateway links',
              );
            }
          } catch (error, stackTrace) {
            failures.add(AnnaArchiveAttempt(uri, error, stackTrace));
          }
        } else if (links.isEmpty && _isLibgenLanding(uri, hash)) {
          try {
            final landing = await _getPage(uri);
            final targets = landing.document.querySelectorAll(
              '#download a[href], a[href*="get.php?"]',
            );
            for (final target in targets) {
              final resolved = _webUri(landing.uri, target.attributes['href']);
              if (resolved != null) links.add(resolved.toString());
            }
            if (targets.isEmpty) {
              throw _markup(landing.uri, 'Missing LibGen GET download link');
            }
          } catch (error, stackTrace) {
            failures.add(AnnaArchiveAttempt(uri, error, stackTrace));
          }
        }
      }
      if (links.isNotEmpty) return links.toList(growable: false);
      if (failures.isNotEmpty) throw AnnaArchiveException(failures);
      if (!hasMediatedDownload &&
          _visibleText(panel).contains('No downloads found.')) {
        return const [];
      }
      throw AnnaArchivePageException(
        uri: page.uri,
        kind: AnnaArchiveFailureKind.unavailable,
        message:
            'No direct download is available. The file’s remaining '
            'download options require a browser, source login, or membership.',
      );
    });
  }

  void close() => _dio.close(force: true);

  Future<T> _onMirrors<T>(Future<T> Function(Uri) request) async {
    final failures = <AnnaArchiveAttempt>[];
    for (var offset = 0; offset < _mirrors.length; offset++) {
      final index = (_activeMirror + offset) % _mirrors.length;
      final mirror = _mirrors[index];
      try {
        final result = await request(mirror);
        _activeMirror = index;
        return result;
      } on DioException catch (error, stackTrace) {
        if (error.type == DioExceptionType.cancel) rethrow;
        failures.add(
          AnnaArchiveAttempt(error.requestOptions.uri, error, stackTrace),
        );
      } on AnnaArchivePageException catch (error, stackTrace) {
        failures.add(AnnaArchiveAttempt(error.uri, error, stackTrace));
      } on AnnaArchiveException catch (error) {
        failures.addAll(error.attempts);
      }
    }
    throw AnnaArchiveException(failures);
  }

  Future<({Document document, Uri uri})> _getPage(Uri initial) async {
    var uri = initial;
    for (var redirects = 0; redirects <= 3; redirects++) {
      final cookies = _cookies[uri.origin];
      final response = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
          headers: {
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'en',
            if (_userAgent != null) 'User-Agent': _userAgent,
            if (cookies != null && cookies.isNotEmpty)
              'Cookie': cookies.entries
                  .map((entry) => '${entry.key}=${entry.value}')
                  .join('; '),
          },
        ),
      );
      for (final header in response.headers['set-cookie'] ?? const <String>[]) {
        final pair = header.split(';').first;
        final equals = pair.indexOf('=');
        if (equals > 0) {
          final jar = _cookies.putIfAbsent(uri.origin, () => {});
          final name = pair.substring(0, equals).trim();
          if (_deletedCookie.hasMatch(header)) {
            jar.remove(name);
          } else {
            jar[name] = pair.substring(equals + 1).trim();
          }
        }
      }
      final status = response.statusCode;
      final body = response.data ?? '';
      final document = html.parse(body);
      final title = document.querySelector('title')?.text.toLowerCase() ?? '';
      if (title.contains('ddos-guard') ||
          title.contains('just a moment') ||
          document.querySelector(
                'script[src*="ddos-guard"], script[src*="/cdn-cgi/challenge"], '
                '.cf-turnstile, #challenge-form',
              ) !=
              null ||
          _visibleText(
            document.body,
          ).toLowerCase().contains('checking your browser before accessing')) {
        throw AnnaArchivePageException(
          uri: uri,
          kind: AnnaArchiveFailureKind.challenge,
          statusCode: status,
          message:
              'Browser verification is required, or the saved browser '
              'session expired or does not match this connection. This is not '
              'an empty catalog. Complete the source’s legitimate browser '
              'check and import a session for this mirror using the same '
              'proxy/network and browser user agent.',
          responseExcerpt: _excerpt(body),
        );
      }
      if ({301, 302, 303, 307, 308}.contains(status)) {
        final next = _webUri(uri, response.headers.value('location'));
        if (next == null || next.origin != initial.origin || redirects == 3) {
          throw AnnaArchivePageException(
            uri: uri,
            kind: AnnaArchiveFailureKind.http,
            statusCode: status,
            message: 'Unexpected or excessive source redirect',
            responseExcerpt: _excerpt(body),
          );
        }
        uri = next;
        continue;
      }
      if (status != 200) {
        throw AnnaArchivePageException(
          uri: uri,
          kind: AnnaArchiveFailureKind.http,
          statusCode: status,
          message: 'The source returned an unsuccessful response',
          responseExcerpt: _excerpt(body),
        );
      }
      return (document: document, uri: uri);
    }
    throw StateError('Unreachable redirect state');
  }

  List<SearchResultItem> _parseSearch(Document document, Uri uri) {
    final containers = document
        .querySelectorAll('.js-aarecord-list-outer')
        .where(
          (element) =>
              _ancestorWhere(
                element,
                (candidate) =>
                    candidate.classes.contains('js-partial-matches-show'),
              ) ==
              null,
        )
        .toList(growable: false);
    if (containers.isEmpty ||
        document.querySelector('form[action="/search"] input[name="q"]') ==
            null) {
      throw _markup(uri, 'Unrecognized search response markup');
    }
    final text = _visibleText(document.body);
    if (text.contains('Error during search.') ||
        text.contains('The search took too long')) {
      throw AnnaArchivePageException(
        uri: uri,
        kind: AnnaArchiveFailureKind.unavailable,
        message: 'The source reported a search error or timeout',
        responseExcerpt: _excerpt(text),
      );
    }
    final books = <SearchResultItem>[];
    final seen = <String>{};
    var recognized = 0;
    for (final container in containers) {
      // Anna defers off-screen cards in comment nodes. Parse just those result
      // fragments, never arbitrary scripts/comments elsewhere in the page.
      final scopes = <Element>[container];
      void collectComments(Node node) {
        for (final child in node.nodes) {
          if (child is Comment && (child.data?.contains('/md5/') ?? false)) {
            scopes.add(Element.tag('div')..innerHtml = child.data!);
          } else {
            collectComments(child);
          }
        }
      }

      collectComments(container);
      for (final scope in scopes) {
        for (final anchor in scope.querySelectorAll('a.js-vim-focus[href]')) {
          final detail = _webUri(uri, anchor.attributes['href']);
          if (detail == null || detail.origin != uri.origin) continue;
          final parts = detail.pathSegments;
          if (parts.length != 2 ||
              parts.first != 'md5' ||
              !_md5.hasMatch(parts.last))
            continue;
          final id = parts.last.toLowerCase();
          if (!seen.add(id)) continue;
          Element? card = anchor;
          while (card != null &&
              !(card.classes.contains('flex') &&
                  card.classes.contains('pt-3'))) {
            card = card.parent;
          }
          if (card == null) throw _markup(uri, 'Missing result card for $id');
          final title = _visibleText(anchor);
          final metadata = card.querySelectorAll('div').where((element) {
            return element.classes.contains('font-semibold') &&
                element.classes.contains('text-sm') &&
                element.classes.contains('leading-[1.2]');
          }).firstOrNull;
          final segments = _visibleText(
            metadata,
          ).split('·').map((segment) => segment.trim()).toList(growable: false);
          final format = segments.where(_format.hasMatch).firstOrNull;
          if (title.isEmpty || format == null) {
            throw _markup(uri, 'Missing title or file metadata for $id');
          }
          recognized++;
          final extension = format.toLowerCase();
          if (extension != 'epub' && extension != 'pdf') continue;
          final authorIcon = card.querySelector('[class*="mdi--user-edit"]');
          final cover = card.querySelector(
            '[id^="list_cover_aarecord_id__"] img',
          );
          final coverUri =
              _webUri(uri, cover?.attributes['data-src']) ??
              _webUri(uri, cover?.attributes['src']);
          books.add(
            SearchResultItem(
              id: id,
              title: title,
              author: _visibleText(
                _ancestorWhere(
                  authorIcon,
                  (candidate) => candidate.localName == 'a',
                ),
              ),
              format: extension,
              size: segments.where(_size.hasMatch).firstOrNull ?? '',
              imgUrl: coverUri?.toString() ?? '',
              source: SearchResultSource.anna,
              originalObject: detail,
            ),
          );
        }
      }
    }
    if (recognized == 0 && !text.contains('No files found.')) {
      throw _markup(
        uri,
        'Search returned neither catalog records nor an '
        'explicit no-results response',
      );
    }
    return books;
  }

  static bool _isDirectDownload(Uri uri, Element anchor) =>
      anchor.attributes.containsKey('download') ||
      _downloadExtension.hasMatch(uri.path) ||
      uri.path.startsWith('/ipfs/') ||
      uri.path.endsWith('/get.php');

  static bool _isLibgenLanding(Uri uri, String md5) {
    if (uri.path.endsWith('/ads.php')) {
      return uri.queryParameters['md5']?.toLowerCase() == md5;
    }
    final segments = uri.pathSegments;
    return (segments.length == 2 ||
            (segments.length == 3 && segments.last.isEmpty)) &&
        const {'main', 'fiction'}.contains(segments.first) &&
        segments[1].toLowerCase() == md5;
  }

  static AnnaArchivePageException _markup(Uri uri, String message) =>
      AnnaArchivePageException(
        uri: uri,
        kind: AnnaArchiveFailureKind.markup,
        message: message,
      );

  static Element? _ancestorWhere(
    Element? element,
    bool Function(Element) predicate,
  ) {
    while (element != null) {
      if (predicate(element)) return element;
      element = element.parent;
    }
    return null;
  }

  static String _visibleText(Node? node) {
    if (node == null) return '';
    final result = StringBuffer();
    void append(Node current) {
      if (current is Text) {
        result.write(current.data);
      } else if (current is! Comment &&
          !(current is Element &&
              const {
                'script',
                'style',
                'noscript',
              }.contains(current.localName))) {
        for (final child in current.nodes) {
          append(child);
        }
      }
    }

    append(node);
    return result.toString().replaceAll(_whitespace, ' ').trim();
  }

  static String _excerpt(String body) =>
      body.length <= 512 ? body : body.substring(0, 512);

  static Uri? _webUri(Uri base, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final candidate = Uri.tryParse(value.trim());
    if (candidate == null) return null;
    final uri = base.resolveUri(candidate);
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  static List<Uri> _parseMirrors(List<String> mirrors) {
    final result = <Uri>{};
    for (final mirror in mirrors) {
      final uri = Uri.tryParse(mirror.trim());
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.path.isNotEmpty && uri.path != '/')) {
        throw ArgumentError.value(
          mirror,
          'mirrors',
          'Expected an HTTPS origin',
        );
      }
      result.add(Uri.parse(uri.origin));
    }
    if (result.isEmpty) throw ArgumentError.value(mirrors, 'mirrors', 'Empty');
    return result.toList(growable: false);
  }
}
