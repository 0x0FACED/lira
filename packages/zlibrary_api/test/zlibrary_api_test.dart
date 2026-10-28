import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

// Reduced from the real 2026-10-28 HTTP search response on z-library.biz.
// The hidden card really appears in the site's otherwise valid search results.
const _searchPage = '''
<div id="searchResultBox">
 <div class="book-item resItemBoxBooks">
  <z-bookcard id="2954024" isbn="9781491962442"
    href="/book/MkleVD14rJ/learning-http2-a-practical-guide-for-beginners.html"
    download="/dl/z3m7nyx5WE" publisher="O’Reilly Media" language="English"
    year="2017" extension="epub" filesize="1.78 MB" rating="0.0">
   <img data-src="/covers/http2.jpg">
   <div slot="title">Learning HTTP/2: A Practical Guide for Beginners</div>
   <div slot="author">Stephen Ludin; Javier Garza</div>
  </z-bookcard>
 </div>
 <div class="book-item resItemBoxBooks" hidden aria-hidden="true">
  <z-bookcard id="76828233" href="/book/7lZ5vwO3zg/http.html" download="/dl/z4QO60wbvW">
   <div slot="title">HTTP</div><div slot="author">HTTP</div>
  </z-bookcard>
 </div>
</div>
''';
const _emptyPage =
    '<div id="searchResultBox"><div class="notFound color3">On your request nothing has been found.</div></div>';
const _bookPath =
    '/book/MkleVD14rJ/learning-http2-a-practical-guide-for-beginners.html';
const _detailsPage = '''
<div class="details-book cardBooks" data-book_id="2954024">
 <h1 class="book-title">Learning HTTP/2: A Practical Guide for Beginners</h1>
 <template><a class="addDownloadedBook" href="/dl/trap" hidden></a></template>
 <a class="btn btn-default dlButton addDownloadedBook" href="/dl/z3m7nyx5WE">epub, 1.78 MB</a>
</div>
''';
const _htmlHeaders = {'content-type': 'text/html; charset=utf-8'};

void main() {
  group('search', () {
    test(
        'preserves redirect cookies, parses visible live cards and resolves links',
        () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.followRedirects, isFalse);
        expect(request.url.pathSegments, ['s', 'C++ / HTTP']);
        expect(request.url.queryParameters['extensions[0]'], 'EPUB');
        expect(request.url.queryParameters['page'], '2');
        if (requests == 1) {
          return http.Response('', 307, headers: {
            'location': request.url.toString(),
            'set-cookie':
                '__diamwall=approved==; Expires=Wed, 28 Oct 2026 20:11:03 GMT; Path=/, bsrv=node=2; Path=/',
          });
        }
        expect(request.headers['cookie'], contains('__diamwall=approved=='));
        expect(request.headers['cookie'], contains('bsrv=node=2'));
        return http.Response(_searchPage, 200, headers: _htmlHeaders);
      });
      final api =
          ZLibraryApi(mirrors: ['https://catalog.test'], client: client);
      addTearDown(api.close);
      final results =
          await api.search(query: 'C++ / HTTP', extensions: ['epub'], page: 2);
      expect(requests, 2);
      expect(results.map((book) => book.id), ['2954024']);
      final book = results.single;
      expect(book.title, 'Learning HTTP/2: A Practical Guide for Beginners');
      expect(book.author, 'Stephen Ludin, Javier Garza');
      expect(book.extension, 'epub');
      expect(book.url, 'https://catalog.test$_bookPath');
      expect(book.downloadUrl, 'https://catalog.test/dl/z3m7nyx5WE');
      expect(book.coverUrl, 'https://catalog.test/covers/http2.jpg');
      expect(api.activeMirror, 'https://catalog.test');
      expect(api.cookies, isEmpty);
    });

    test(
        'fails over after DiamWall instead of returning accidental empty success',
        () async {
      final hosts = <String>[];
      final api = ZLibraryApi(
          mirrors: ['https://blocked.test', 'https://working.test'],
          client: MockClient((request) async {
            hosts.add(request.url.host);
            return request.url.host == 'blocked.test'
                ? http.Response('<title>Access Denied | DiamWall</title>', 517)
                : http.Response(_searchPage, 200, headers: _htmlHeaders);
          }));
      addTearDown(api.close);
      expect((await api.search(query: 'HTTP')).single.id, '2954024');
      await api.search(query: 'HTTP');
      expect(hosts, ['blocked.test', 'working.test', 'working.test']);
      expect(api.activeMirror, 'https://working.test');
    });

    test('bounds unchanged self redirects then uses the next approved mirror',
        () async {
      final hosts = <String>[];
      final api = ZLibraryApi(
          mirrors: ['https://loop.test', 'https://working.test'],
          client: MockClient((request) async {
            hosts.add(request.url.host);
            return request.url.host == 'loop.test'
                ? http.Response('', 307,
                    headers: {'location': request.url.toString()})
                : http.Response(_searchPage, 200, headers: _htmlHeaders);
          }));
      addTearDown(api.close);
      expect((await api.search(query: 'HTTP')).single.id, '2954024');
      expect(hosts, ['loop.test', 'working.test']);
    });

    test('only an explicit no-results response returns an empty list',
        () async {
      var page = '<div id="searchResultBox"></div>';
      final api = ZLibraryApi(
          mirrors: ['https://catalog.test'],
          client: MockClient(
              (_) async => http.Response(page, 200, headers: _htmlHeaders)));
      addTearDown(api.close);
      await expectLater(
          api.search(query: 'HTTP'), throwsA(isA<ZLibraryException>()));
      page = '<title>Checking your browser</title>';
      await expectLater(
          api.search(query: 'HTTP'), throwsA(isA<ZLibraryException>()));
      page = _emptyPage;
      expect(await api.search(query: 'HTTP'), isEmpty);
    });

    test('rejects an incomplete visible book card instead of dropping it',
        () async {
      final api = ZLibraryApi(
          mirrors: ['https://catalog.test'],
          client: MockClient((_) async => http.Response(
              '<div id="searchResultBox"><z-bookcard id="1" href="/book/1"></z-bookcard></div>',
              200)));
      addTearDown(api.close);
      await expectLater(
          api.search(query: 'HTTP'), throwsA(isA<ZLibraryException>()));
    });

    test('keeps absolute and protocol-relative URLs intact', () async {
      final page = _searchPage
          .replaceFirst('download="/dl/z3m7nyx5WE"',
              'download="https://files.test/book.epub?key=abc"')
          .replaceFirst('data-src="/covers/http2.jpg"',
              'data-src="//covers.test/http2.jpg"');
      final api = ZLibraryApi(
          mirrors: ['https://catalog.test'],
          client: MockClient(
              (_) async => http.Response(page, 200, headers: _htmlHeaders)));
      addTearDown(api.close);
      final book = (await api.search(query: 'HTTP')).single;
      expect(book.downloadUrl, 'https://files.test/book.epub?key=abc');
      expect(book.coverUrl, 'https://covers.test/http2.jpg');
      expect(api.cookiesForUrl(book.downloadUrl!), isEmpty);
    });

    test('replays the observed browser proof with both required cookies',
        () async {
      const seed = 'BC0BB99F1906312BC1C6CB9FCDD8907AA75ECD88';
      var count = 0;
      final api = ZLibraryApi(
          mirrors: ['https://catalog.test'],
          client: MockClient((request) async {
            count++;
            if (count == 1) {
              return http.Response(
                  "<title>Checking your browser ...</title><script>const a=['$seed','c_token=','array'];</script>",
                  503,
                  headers: {'set-cookie': 'bsrv=backend-2; Path=/'});
            }
            final header = request.headers['cookie']!;
            final token =
                RegExp(r'c_token=([^;]+)').firstMatch(header)!.group(1)!;
            final duration =
                RegExp(r'c_time=([^;]+)').firstMatch(header)!.group(1)!;
            expect(token.startsWith(seed), isTrue);
            final digest = sha1.convert(utf8.encode(token)).bytes;
            final index = int.parse(seed[0], radix: 16);
            expect(digest.sublist(index, index + 2), [0xb0, 0x0b]);
            expect(double.parse(duration), greaterThanOrEqualTo(0));
            expect(header, contains('bsrv=backend-2'));
            return http.Response(_searchPage, 200, headers: _htmlHeaders);
          }));
      addTearDown(api.close);
      expect((await api.search(query: 'HTTP')).single.id, '2954024');
      expect(count, 2);
      expect(api.cookies, isEmpty);
    });

    test(
        'does not send sessions to an unapproved redirect or leak host cookies during failover',
        () async {
      final hosts = <String>[];
      final api = ZLibraryApi(
        mirrors: ['https://blocked.test', 'https://working.test'],
        cookies: {'remix_userid': '42', 'remix_userkey': 'secret'},
        client: MockClient((request) async {
          hosts.add(request.url.host);
          if (request.url.host == 'blocked.test') {
            return http.Response('', 307, headers: {
              'location': 'https://unapproved.test/steal',
              'set-cookie': 'bsrv=blocked-backend; Path=/'
            });
          }
          expect(request.headers['cookie'], contains('remix_userkey=secret'));
          expect(request.headers['cookie'], isNot(contains('bsrv=')));
          return http.Response(_searchPage, 200, headers: _htmlHeaders);
        }),
      );
      addTearDown(api.close);
      await api.search(query: 'HTTP');
      expect(hosts, ['blocked.test', 'working.test']);
      expect(api.cookiesForUrl('https://unapproved.test/dl/a'), isEmpty);
    });
  });

  group('details and downloads', () {
    test(
        'rebases old details to configured mirrors and ignores the hidden link',
        () async {
      final urls = <Uri>[];
      final api = ZLibraryApi(
          mirrors: ['https://current.test'],
          client: MockClient((request) async {
            urls.add(request.url);
            return http.Response(
                request.url.path.startsWith('/s/') ? _searchPage : _detailsPage,
                200,
                headers: _htmlHeaders);
          }));
      addTearDown(api.close);
      final book = (await api.search(query: 'HTTP'))
          .single
          .copyWith(url: 'https://removed.test$_bookPath');
      final details = await api.fetchBookDetails(book);
      expect(urls.last.toString(), 'https://current.test$_bookPath');
      expect(details.url, urls.last.toString());
      expect(details.downloadUrl, 'https://current.test/dl/z3m7nyx5WE');
    });

    test('details failover preserves an absolute download link', () async {
      final requested = <String>[];
      final api = ZLibraryApi(
          mirrors: ['https://first.test', 'https://second.test'],
          client: MockClient((request) async {
            requested.add(request.url.host);
            if (request.url.path.startsWith('/s/'))
              return http.Response(_searchPage, 200, headers: _htmlHeaders);
            if (request.url.host == 'first.test')
              return http.Response('Unavailable', 503);
            return http.Response(
                _detailsPage.replaceFirst('href="/dl/z3m7nyx5WE"',
                    'href="https://files.test/http.epub"'),
                200);
          }));
      addTearDown(api.close);
      final book = (await api.search(query: 'HTTP')).single;
      expect((await api.fetchBookDetails(book)).downloadUrl,
          'https://files.test/http.epub');
      expect(requested, ['first.test', 'first.test', 'second.test']);
      expect(api.activeMirror, 'https://second.test');
    });

    test('resolves a path-relative download against the page base element',
        () async {
      final page = '<base href="/">' +
          _detailsPage.replaceFirst(
              'href="/dl/z3m7nyx5WE"', 'href="dl/relative-file"');
      final api = ZLibraryApi(
          mirrors: ['https://current.test'],
          client: MockClient((request) async => http.Response(
              request.url.path.startsWith('/s/') ? _searchPage : page, 200,
              headers: _htmlHeaders)));
      addTearDown(api.close);
      final book = (await api.search(query: 'HTTP')).single;
      expect((await api.fetchBookDetails(book)).downloadUrl,
          'https://current.test/dl/relative-file');
    });

    test('details reject a login page instead of preserving a stale download',
        () async {
      var details = false;
      final api = ZLibraryApi(
          mirrors: ['https://catalog.test'],
          client: MockClient((_) async => http.Response(
              details ? '<form id="loginForm"></form>' : _searchPage, 200,
              headers: _htmlHeaders)));
      addTearDown(api.close);
      final book = (await api.search(query: 'HTTP')).single;
      details = true;
      await expectLater(
          api.fetchBookDetails(book), throwsA(isA<ZLibraryException>()));
    });

    test(
        'external download resolution never requests or returns account cookies',
        () async {
      var requests = 0;
      final api = ZLibraryApi(
          mirrors: ['https://catalog.test'],
          cookies: {'remix_userkey': 'secret'},
          client: MockClient((_) async {
            requests++;
            return http.Response('', 200);
          }));
      addTearDown(api.close);
      expect(await api.resolveDownloadCookies('https://files.test/book.epub'),
          isEmpty);
      expect(requests, 0);
    });

    test('download preparation stops at an external CDN redirect', () async {
      final urls = <Uri>[];
      final api = ZLibraryApi(
          mirrors: ['https://catalog.test'],
          cookies: {'remix_userkey': 'secret'},
          client: MockClient((request) async {
            urls.add(request.url);
            return http.Response('', 302, headers: {
              'location': 'https://files.test/book.epub',
              'set-cookie': 'bsrv=download-backend; Path=/'
            });
          }));
      addTearDown(api.close);
      final cookies =
          await api.resolveDownloadCookies('https://catalog.test/dl/book');
      expect(urls.map((url) => url.host), ['catalog.test']);
      expect(cookies, containsPair('remix_userkey', 'secret'));
      expect(cookies, containsPair('bsrv', 'download-backend'));
    });

    test(
        'download preparation cancels the binary stream rather than downloading the file',
        () async {
      var cancelled = false;
      var consumed = false;
      final controller = StreamController<List<int>>(onCancel: () {
        cancelled = true;
      });
      final client = _StreamClient((_) async => http.StreamedResponse(
            controller.stream.map((chunk) {
              consumed = true;
              return chunk;
            }),
            200,
            headers: {'content-type': 'application/epub+zip'},
          ));
      final api =
          ZLibraryApi(mirrors: ['https://catalog.test'], client: client);
      addTearDown(api.close);
      await api.resolveDownloadCookies('https://catalog.test/dl/book');
      expect(cancelled, isTrue);
      expect(consumed, isFalse);
      await controller.close();
    });
  });

  group('login', () {
    test(
        'uses configured origin and installs the session on an approved advertised domain',
        () async {
      final requests = <http.Request>[];
      final api = ZLibraryApi(
          mirrors: ['https://configured.test'],
          client: MockClient((request) async {
            requests.add(request);
            if (request.method == 'POST') {
              expect(request.url.toString(), 'https://configured.test/rpc.php');
              expect(request.bodyFields['email'], 'reader@example.test');
              expect(request.bodyFields['password'], 'private-password');
              return http.Response(
                  jsonEncode({
                    'response': {
                      'validationError': false,
                      'regularDomains': [
                        {'name': 'configured.test', 'rank': 1},
                        {'name': 'unapproved.test'}
                      ],
                      'params': '/auth?token=private-session',
                    }
                  }),
                  200);
            }
            expect(request.url.toString(),
                'https://configured.test/auth?token=private-session');
            return http.Response('', 200, headers: {
              'set-cookie':
                  'remix_userid=123; Path=/, remix_userkey=secret==; Path=/'
            });
          }));
      addTearDown(api.close);
      await api.login('reader@example.test', 'private-password');
      expect(requests.length, 2);
      expect(api.cookies, {'remix_userid': '123', 'remix_userkey': 'secret=='});
      expect(api.activeMirror, 'https://configured.test');
    });

    test('rejects invalid credentials without retrying on every mirror',
        () async {
      final hosts = <String>[];
      final api = ZLibraryApi(
          mirrors: ['https://first.test', 'https://second.test'],
          client: MockClient((request) async {
            hosts.add(request.url.host);
            return http.Response(
                jsonEncode({
                  'response': {
                    'validationError': true,
                    'message': 'Wrong password'
                  }
                }),
                200);
          }));
      addTearDown(api.close);
      await expectLater(api.login('reader@example.test', 'private-password'),
          throwsA(isA<ZLibraryAuthenticationException>()));
      expect(hosts, ['first.test']);
    });

    test(
        'never forwards a POST password or session URL to an unapproved redirect',
        () async {
      var count = 0;
      final api = ZLibraryApi(
          mirrors: ['https://configured.test'],
          client: MockClient((request) async {
            count++;
            expect(request.url.host, 'configured.test');
            return http.Response('', 307,
                headers: {'location': 'https://unapproved.test/rpc.php'});
          }));
      addTearDown(api.close);
      await expectLater(api.login('reader@example.test', 'private-password'),
          throwsA(isA<ZLibraryException>()));
      expect(count, 1);
    });

    test('JSON session transfer cannot expand the configured trust list',
        () async {
      var count = 0;
      final api = ZLibraryApi(
          mirrors: ['https://configured.test'],
          client: MockClient((_) async {
            count++;
            return http.Response(
                jsonEncode({
                  'response': {
                    'priorityRedirectUrl':
                        'https://unapproved.test/auth?token=private'
                  }
                }),
                200);
          }));
      addTearDown(api.close);
      await expectLater(api.login('reader@example.test', 'private-password'),
          throwsA(isA<ZLibraryException>()));
      expect(count, 1);
      expect(api.cookies, isEmpty);
    });

    test('does not call a malformed HTTP200 JSON response successful login',
        () async {
      final api = ZLibraryApi(
          mirrors: ['https://configured.test'],
          client:
              MockClient((_) async => http.Response('{"response":{}}', 200)));
      addTearDown(api.close);
      await expectLater(api.login('reader@example.test', 'private-password'),
          throwsA(isA<ZLibraryException>()));
    });

    test(
        'does not mistake preference or browser cookies for an account session',
        () async {
      final api = ZLibraryApi(
          mirrors: ['https://configured.test'],
          client: MockClient((_) async => http.Response(
                  '{"response":{"validationError":false}}', 200, headers: {
                'set-cookie': 'remix_lang=en; Path=/, bsrv=node; Path=/'
              })));
      addTearDown(api.close);
      await expectLater(api.login('reader@example.test', 'private-password'),
          throwsA(isA<ZLibraryException>()));
    });
  });

  test('close releases the injected client and prevents later network use',
      () async {
    final client = _StreamClient((_) async =>
        http.StreamedResponse(Stream.value(utf8.encode(_emptyPage)), 200));
    final api = ZLibraryApi(mirrors: ['https://catalog.test'], client: client);
    api.close();
    api.close();
    expect(client.closeCount, 1);
    await expectLater(api.search(query: 'HTTP'), throwsStateError);
  });
}

class _StreamClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  int closeCount = 0;

  _StreamClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {
    closeCount++;
  }
}
