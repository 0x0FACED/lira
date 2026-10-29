import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'browser_check_solver.dart';
import 'models/zlibrary_book.dart';
import 'zlibrary_mirrors.dart';

part 'zlibrary_mirror_directory.dart';

class ZLibraryApi {
  final List<String> mirrors;
  final http.Client _client;
  final Map<String, String> _cookies = {};
  final Map<String, Map<String, String>> _originCookies = {};
  String? _activeMirror;
  bool _closed = false;

  ZLibraryApi({
    List<String>? mirrors,
    Map<String, String>? cookies,
    http.Client? client,
  })  : mirrors = List.unmodifiable(
          (mirrors ?? defaultZLibraryMirrors)
              .map(normalizeZLibraryMirror)
              .toSet(),
        ),
        _client = client ?? http.Client() {
    if (this.mirrors.isEmpty) {
      throw ArgumentError(
          'At least one approved Z-Library mirror is required.');
    }
    for (final cookie in (cookies ?? <String, String>{}).entries) {
      if (_isOriginCookie(cookie.key)) {
        (_originCookies[this.mirrors.first] ??= {})[cookie.key] = cookie.value;
      } else {
        _cookies[cookie.key] = cookie.value;
      }
    }
  }

  /// Account cookies for persistence. Browser verification cookies stay scoped
  /// to their issuing origin and are deliberately not persisted as credentials.
  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  String? get activeMirror => _activeMirror;

  /// Never gives account or browser cookies to an unapproved download origin.
  Map<String, String> cookiesForUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isApproved(uri)) return const {};
    return Map.unmodifiable({...?_originCookies[uri.origin], ..._cookies});
  }

  /// Closes the owned or injected client. Do not share it with another owner.
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }

  Future<void> login(String email, String password) async {
    await _withMirrors<bool>('Login', (mirror) async {
      final result = await _request(
        Uri.parse('$mirror/rpc.php'),
        method: 'POST',
        body: {
          'isModal': 'true',
          'email': email,
          'password': password,
          'site_mode': 'books',
          'action': 'login',
          'isSingleLogin': '1',
          'redirectUrl': '',
          'gg_json_mode': '1',
        },
      );
      _requireSuccess(result.response);
      final Object? payload;
      try {
        payload = jsonDecode(result.response.body);
      } on FormatException {
        throw const ZLibraryException(
            'Invalid login response; browser verification may be required.');
      }
      final data = payload is Map ? payload['response'] : null;
      if (data is! Map || data.isEmpty) {
        throw const ZLibraryException(
            'The login response did not contain a session.');
      }
      final validationError = data['validationError'];
      if (validationError != null &&
          validationError != false &&
          validationError != 0) {
        throw const ZLibraryAuthenticationException(
            'Login was rejected. Check your credentials in the official website.');
      }

      // The current site's AuthForm receives regularDomains + params and then
      // visits one domain to install the account cookies. Only user-approved
      // destinations may receive those authentication parameters.
      Uri? sessionUri;
      final priority = data['priorityRedirectUrl'];
      if (priority is String && priority.isNotEmpty) {
        sessionUri = result.uri.resolve(priority);
        if (!_isApproved(sessionUri)) {
          throw const ZLibraryException(
              'Login requires an unapproved mirror. Add it explicitly before logging in.');
        }
      } else if (data['params'] is String &&
          (data['params'] as String).isNotEmpty) {
        final domains = data['regularDomains'];
        final approvedDomains = <String>{};
        if (domains is List) {
          for (final domain in domains) {
            final name = domain is String
                ? domain
                : domain is Map
                    ? domain['name']
                    : null;
            if (name is! String) continue;
            try {
              approvedDomains.add(normalizeZLibraryMirror(name));
            } on FormatException {
              // A remote domain list cannot expand the configured trust list.
            }
          }
        }
        final available = _orderedMirrors().where(approvedDomains.contains);
        if (available.isEmpty) {
          throw const ZLibraryException(
              'Login did not offer an approved session mirror.');
        }
        sessionUri =
            Uri.parse(available.first).resolve(data['params'] as String);
        if (!_isApproved(sessionUri)) {
          throw const ZLibraryException(
              'Login session redirect to an unapproved mirror was blocked.');
        }
      }
      var sessionOrigin = result.uri.origin;
      if (sessionUri != null) {
        final session = await _request(sessionUri);
        _requireSuccess(session.response);
        sessionOrigin = session.uri.origin;
      }
      _promoteSessionCookies(sessionOrigin);
      if (!_hasAccountSession) {
        throw const ZLibraryException(
            'Login completed without account cookies. Browser authentication may be required.');
      }
      return (origin: sessionOrigin, value: true);
    });
  }

  Future<List<ZLibraryBook>> search({
    required String query,
    List<String> extensions = const [],
    int page = 1,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page', 'Must be positive.');
    return _withMirrors<List<ZLibraryBook>>('Search', (mirror) async {
      final parameters = <String, String>{'page': '$page'};
      for (var i = 0; i < extensions.length; i++) {
        parameters['extensions[$i]'] = extensions[i].toUpperCase();
      }
      final uri = Uri.parse(mirror).replace(
        pathSegments: ['s', query],
        queryParameters: parameters,
      );
      final result = await _request(uri);
      _requireSuccess(result.response);
      return (
        origin: result.uri.origin,
        value: _parseSearchResults(result.response.body, result.uri)
      );
    });
  }

  List<ZLibraryBook> _parseSearchResults(String body, Uri uri) {
    final document = html_parser.parse(body);
    final base = _pageBase(document, uri);
    final box = document.getElementById('searchResultBox');
    if (box == null) {
      throw const ZLibraryException(
          'Unrecognized search page; login or browser verification may be required.');
    }
    final cards = box
        .querySelectorAll('z-bookcard')
        .where((card) => !_isHidden(card))
        .toList();
    if (cards.isEmpty) {
      if (box.querySelector('.notFound') != null) return [];
      throw const ZLibraryException(
          'The search page had no recognizable results or no-results message.');
    }
    return cards.map((card) {
      final id = card.attributes['id'] ?? '';
      final title = card.querySelector('[slot="title"]')?.text.trim() ?? '';
      final href = card.attributes['href'] ?? '';
      if (id.isEmpty || title.isEmpty || href.isEmpty) {
        throw const ZLibraryException(
            'The search page contained an incomplete book card.');
      }
      final image = card.querySelector('img');
      final cover =
          image?.attributes['data-src'] ?? image?.attributes['src'] ?? '';
      final download = card.attributes['download'] ?? '';
      return ZLibraryBook(
        id: id,
        isbn: card.attributes['isbn'] ?? '',
        title: title,
        author: (card.querySelector('[slot="author"]')?.text ?? '')
            .split(';')
            .map((author) => author.trim())
            .where((author) => author.isNotEmpty)
            .join(', '),
        coverUrl: cover.isEmpty ? '' : _resolveLink(base, cover),
        publisher: card.attributes['publisher'] ?? '',
        year: card.attributes['year'] ?? '',
        language: card.attributes['language'] ?? '',
        extension: card.attributes['extension'] ?? '',
        size: card.attributes['filesize'] ?? '',
        rating: card.attributes['rating'] ?? '',
        url: _resolveLink(base, href),
        downloadUrl: download.isEmpty ? null : _resolveLink(base, download),
      );
    }).toList();
  }

  /// Rebinds an old result's book path to the currently approved mirrors.
  Future<ZLibraryBook> fetchBookDetails(ZLibraryBook book) async {
    final original = Uri.tryParse(book.url);
    if (original == null || !original.path.startsWith('/book/')) {
      throw const ZLibraryException('The book has no valid details path.');
    }
    return _withMirrors<ZLibraryBook>('Book details', (mirror) async {
      final uri = Uri.parse(mirror).replace(
          path: original.path,
          query: original.hasQuery ? original.query : null);
      final result = await _request(uri);
      _requireSuccess(result.response);
      final document = html_parser.parse(result.response.body);
      if (document.querySelector('.details-book, .bookDetailsBox') == null) {
        throw const ZLibraryException(
            'Unrecognized book page; login or browser verification may be required.');
      }
      final links = document
          .querySelectorAll('a.addDownloadedBook[href]')
          .where((link) =>
              !_isHidden(link) &&
              !link.classes.contains('reader-link') &&
              (link.attributes['href']?.trim().isNotEmpty ?? false) &&
              !link.text.toLowerCase().contains('unavailable'));
      if (links.isEmpty) {
        throw const ZLibraryException(
            'No download link is available. Sign in or open the book in your browser.');
      }
      final href = links.first.attributes['href']!;
      return (
        origin: result.uri.origin,
        value: book.copyWith(
            url: result.uri.toString(),
            downloadUrl: _resolveLink(_pageBase(document, result.uri), href)),
      );
    });
  }

  /// Checks the approved download endpoint without buffering the actual file.
  /// Redirects to external CDNs are not followed with account cookies.
  Future<Map<String, String>> resolveDownloadCookies(String downloadUrl) async {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || !_isApproved(uri)) return const {};
    final result =
        await _request(uri, headersOnly: true, stopAtExternalRedirect: true);
    if (!_isRedirect(result.response.statusCode))
      _requireSuccess(result.response);
    return cookiesForUrl(downloadUrl);
  }

  Iterable<String> _orderedMirrors() sync* {
    if (_activeMirror != null) yield _activeMirror!;
    yield* mirrors.where((mirror) => mirror != _activeMirror);
  }

  Future<T> _withMirrors<T>(
    String operation,
    Future<({String origin, T value})> Function(String mirror) action,
  ) async {
    if (_closed) throw StateError('ZLibraryApi is closed.');
    final failures = <String>[];
    for (final mirror in _orderedMirrors()) {
      try {
        final result = await action(mirror);
        _activeMirror = result.origin;
        return result.value;
      } on ZLibraryAuthenticationException {
        rethrow;
      } on Exception catch (error) {
        final reason = error is ZLibraryException
            ? error.message
            : 'Network request failed (${error.runtimeType}).';
        failures.add('$mirror: $reason');
      }
    }
    throw ZLibraryException(
        '$operation failed on the approved mirrors. ${failures.join(' ')}');
  }

  /// Binary downloads must use the same identity as browser-verified requests.
  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
  static const _requestTimeout = Duration(seconds: 25);
  static final _hiddenStyle =
      RegExp(r'display\s*:\s*none', caseSensitive: false);

  Future<({Uri uri, http.Response response})> _request(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? body,
    bool headersOnly = false,
    bool stopAtExternalRedirect = false,
    bool anonymousOnly = false,
  }) async {
    if (_closed) throw StateError('ZLibraryApi is closed.');
    final visited = <String>{};
    var solvedBrowserCheck = false;
    for (var step = 0; step < 10; step++) {
      if (!_isApproved(uri)) {
        throw const ZLibraryException(
            'A request to an unapproved mirror was blocked.');
      }
      final requestCookies = anonymousOnly
          ? _originCookies[uri.origin] ?? const <String, String>{}
          : {...?_originCookies[uri.origin], ..._cookies};
      final cookieHeader = requestCookies.entries
          .where((cookie) => !anonymousOnly || _isOriginCookie(cookie.key))
          .map((cookie) => '${cookie.key}=${cookie.value}')
          .join('; ');
      // Self-redirects are legitimate once when they install a cookie. A loop
      // with identical method, URI and cookies is not retried indefinitely.
      if (!visited.add('$method $uri $cookieHeader')) {
        throw const ZLibraryException('The mirror returned a redirect loop.');
      }
      final request = http.Request(method, uri)..followRedirects = false;
      request.headers['User-Agent'] = userAgent;
      if (cookieHeader.isNotEmpty) request.headers['Cookie'] = cookieHeader;
      if (body != null && method != 'GET') request.bodyFields = body;
      final streamed = await _client.send(request).timeout(_requestTimeout);
      _updateCookies(uri, streamed.headers['set-cookie'],
          anonymousOnly: anonymousOnly);
      final location = streamed.headers['location'];
      if (_isRedirect(streamed.statusCode)) {
        await streamed.stream.listen(null).cancel();
        if (location == null || location.isEmpty) {
          throw const ZLibraryException(
              'The mirror returned a redirect without a destination.');
        }
        final next = uri.resolve(location);
        if (!_isApproved(next)) {
          if (stopAtExternalRedirect) {
            return (
              uri: uri,
              response: http.Response('', streamed.statusCode,
                  headers: streamed.headers)
            );
          }
          throw const ZLibraryException(
              'Redirect to an unapproved mirror was blocked.');
        }
        if (streamed.statusCode == 303 ||
            ((streamed.statusCode == 301 || streamed.statusCode == 302) &&
                method == 'POST')) {
          method = 'GET';
          body = null;
        }
        uri = next;
        continue;
      }
      if (headersOnly &&
          streamed.statusCode >= 200 &&
          streamed.statusCode < 300 &&
          !(streamed.headers['content-type'] ?? '')
              .toLowerCase()
              .contains('text/html')) {
        await streamed.stream.listen(null).cancel();
        return (
          uri: uri,
          response:
              http.Response('', streamed.statusCode, headers: streamed.headers)
        );
      }
      final response =
          await http.Response.fromStream(streamed).timeout(_requestTimeout);
      if (response.statusCode == 503 &&
          response.body.contains('Checking your browser') &&
          !solvedBrowserCheck) {
        final stopwatch = Stopwatch()..start();
        final token = await BrowserCheckSolver.solveAsync(response.body);
        stopwatch.stop();
        if (token != null) {
          final originCookies = _originCookies[uri.origin] ??= {};
          originCookies['c_token'] = token;
          // The current server also requires the browser's measured work time.
          originCookies['c_time'] =
              (stopwatch.elapsedMicroseconds / 1000000).toString();
          solvedBrowserCheck = true;
          continue;
        }
      }
      return (uri: uri, response: response);
    }
    throw const ZLibraryException('The mirror exceeded the redirect limit.');
  }

  bool _isApproved(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      mirrors.contains(uri.origin);

  static bool _isRedirect(int status) =>
      const [301, 302, 303, 307, 308].contains(status);

  static void _requireSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ZLibraryException(
          'HTTP ${response.statusCode}; the mirror may require browser verification.');
    }
  }

  void _updateCookies(Uri uri, String? header, {bool anonymousOnly = false}) {
    if (header == null) return;
    final jar = _originCookies[uri.origin] ??= {};
    // package:http joins Set-Cookie fields with commas; Expires contains a
    // comma too, while a new cookie starts with a token followed by '='.
    for (final raw in header.split(RegExp(r',(?=\s*[^\s;,=]+\s*=)'))) {
      final parts = raw.split(';');
      final separator = parts.first.indexOf('=');
      if (separator <= 0) continue;
      final name = parts.first.substring(0, separator).trim();
      if (anonymousOnly && !_isOriginCookie(name)) continue;
      final value = parts.first.substring(separator + 1).trim();
      var expired = value.isEmpty;
      for (final attribute in parts.skip(1)) {
        final normalized = attribute.trim().toLowerCase();
        if (normalized == 'max-age=0' ||
            normalized.startsWith('max-age=-') ||
            normalized.startsWith('expires=thu, 01 jan 1970')) expired = true;
      }
      if (expired) {
        jar.remove(name);
        _cookies.remove(name);
      } else {
        jar[name] = value;
        if (!_isOriginCookie(name) &&
            (name.startsWith('remix_') || _cookies.containsKey(name))) {
          _cookies[name] = value;
        }
      }
    }
  }

  static bool _isOriginCookie(String name) => const {
        'c_token',
        'c_time',
        'bsrv',
        '__diamwall',
        'dwid',
        '_dwa',
        '__cf_bm',
        'cf_clearance',
      }.contains(name);

  void _promoteSessionCookies(String origin) {
    for (final cookie
        in (_originCookies[origin] ?? <String, String>{}).entries) {
      if (!_isOriginCookie(cookie.key)) _cookies[cookie.key] = cookie.value;
    }
  }

  bool get _hasAccountSession =>
      (_cookies['remix_userid']?.isNotEmpty ?? false) &&
      (_cookies['remix_userkey']?.isNotEmpty ?? false);

  static bool _isHidden(Element element) {
    Element? current = element;
    while (current != null) {
      if (current.localName == 'template' ||
          current.attributes.containsKey('hidden') ||
          current.attributes['aria-hidden'] == 'true' ||
          _hiddenStyle.hasMatch(current.attributes['style'] ?? '')) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  static Uri _pageBase(Document document, Uri uri) => uri
      .resolve(document.querySelector('base[href]')?.attributes['href'] ?? '');

  static String _resolveLink(Uri base, String href) {
    final result = base.resolve(href.trim());
    if ((result.scheme != 'https' && result.scheme != 'http') ||
        result.host.isEmpty ||
        result.userInfo.isNotEmpty) {
      throw const ZLibraryException(
          'The page contained an invalid book or download link.');
    }
    return result.toString();
  }
}
