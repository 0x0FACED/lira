import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/search/data/anna_archive_client.dart';
import 'package:lira/features/search/domain/models/search_result_item.dart';

const _first = '0123456789abcdef0123456789abcdef';
const _second = 'fedcba9876543210fedcba9876543210';
const _third = '11111111111111111111111111111111';

// Reduced from Anna's aarecord_list.html list renderer, including its actual
// semantic hooks, metadata order, and deferred comment representation. No old
// pagination/count markup is present: that was the false-empty regression.
String _card({
  String id = _first,
  String title = 'The Hobbit &amp; other stories',
  String format = 'EPUB',
  String cover = '//covers.example/hobbit.jpg',
  String author = 'J. R. R. Tolkien',
  String size = '0.5MB',
  String year = '2024',
}) =>
    '''
<div class="flex opacity-40 pt-3 pb-3 border-b last:border-b-0 border-gray-100">
  <a href="/md5/$id"><div id="list_cover_aarecord_id__md5:$id">
    <img src="data:image/gif;base64,R0lGODlh" data-src="$cover">
  </div></a>
  <div class="max-w-full overflow-hidden flex flex-col justify-around">
    <div>
      <a class="font-semibold js-vim-focus text-lg" href="/md5/$id">$title</a>
      <a href="/search?q=author"><span class="icon-[mdi--user-edit]"></span> $author</a>
      <a href="/search?q=publisher"><span class="icon-[mdi--company]"></span>Publisher, 2024</a>
    </div>
    <div><div class="leading-[1.2] text-sm font-semibold mt-2">
      English [en] · $format · $size${year.isEmpty ? '' : ' · $year'} · 📕 Book (fiction) · 🚀/lgli
      · <a href="#">Save<script>const ignored = 'PDF · 9MB';</script></a>
    </div></div>
  </div>
</div>''';

String _search(String records, {String message = '', String extra = ''}) =>
    '''
<!doctype html><html><head><title>Search - Anna’s Archive</title></head><body>
<form action="/search"><input name="q" value="The Hobbit"></form>
<main>$message<div class="js-aarecord-list-outer">$records</div>$extra</main>
</body></html>''';

const _challenge = '''<!doctype html><html><head><title>DDoS-Guard</title>
<script src="/.well-known/ddos-guard/js-challenge/index.js"></script>
<script src="https://check.ddos-guard.net/check.js"></script></head>
<body>Checking your browser before accessing</body></html>''';

ResponseBody _response(
  String body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    ...headers,
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) => closed = true;
}

AnnaArchiveClient _client(
  FutureOr<ResponseBody> Function(RequestOptions) respond, {
  List<String> mirrors = const ['https://first.example'],
}) {
  final client = AnnaArchiveClient(
    dio: Dio()..httpClientAdapter = _Adapter(respond),
    mirrors: mirrors,
  );
  addTearDown(client.close);
  return client;
}

Matcher _failure(AnnaArchiveFailureKind kind) => isA<AnnaArchiveException>()
    .having((error) => error.attempts, 'attempts', hasLength(1))
    .having(
      (error) => error.attempts.single.error,
      'original page error',
      isA<AnnaArchivePageException>().having(
        (error) => error.kind,
        'kind',
        kind,
      ),
    );

void main() {
  test(
    'one live search response parses records without obsolete total count',
    () async {
      final requests = <RequestOptions>[];
      final client = _client((request) {
        requests.add(request);
        return _response(
          _search(
            _card() +
                '<!--${_card(id: _second, title: 'Paper &lt;One&gt;', format: 'PDF', cover: '/covers/paper.png', author: '', size: '12.5 MB')}-->' +
                _card(id: _third, format: 'DJVU'),
          ),
        );
      });
      final results = await client.search('  The Hobbit & Tolkien  ');
      expect(requests, hasLength(1));
      expect(requests.single.uri.path, '/search');
      expect(requests.single.uri.queryParameters['q'], 'The Hobbit & Tolkien');
      expect(requests.single.uri.queryParametersAll['ext'], ['epub', 'pdf']);
      expect(results.map((book) => book.id), [_first, _second]);
      final epub = results.first;
      expect(epub.title, 'The Hobbit & other stories');
      expect(epub.author, 'J. R. R. Tolkien');
      expect(epub.format, 'epub');
      expect(epub.size, '0.5MB');
      expect(epub.imgUrl, 'https://covers.example/hobbit.jpg');
      expect(epub.source, SearchResultSource.anna);
      expect(
        epub.originalObject,
        Uri.parse('https://first.example/md5/$_first'),
      );
      final pdf = results.last;
      expect(pdf.title, 'Paper <One>');
      expect(pdf.author, isEmpty);
      expect(pdf.format, 'pdf');
      expect(pdf.size, '12.5 MB');
      expect(pdf.imgUrl, 'https://first.example/covers/paper.png');
    },
  );

  test(
    'deduplicates deferred cards and excludes site-marked partial matches',
    () async {
      final client = _client(
        (_) => _response(
          _search(
            _card() + '<!--${_card()}-->',
            extra:
                '<div class="js-partial-matches-show hidden">'
                '<div class="js-aarecord-list-outer">${_card(id: _second)}</div></div>',
          ),
        ),
      );
      expect((await client.search('Tolkien')).map((book) => book.id), [_first]);
    },
  );

  test(
    'returns empty only for explicit no-results, not an unrecognized shell',
    () async {
      var body = _search(
        '',
        message:
            '<span class="font-bold">No files found.</span> '
            'Try fewer or different search terms and filters.',
      );
      var calls = 0;
      final client = _client((_) {
        calls++;
        return _response(body);
      }, mirrors: ['https://first.example', 'https://second.example']);
      expect(await client.search('unmatchable'), isEmpty);
      expect(
        calls,
        1,
        reason: 'A valid empty catalog must not fan out to mirrors',
      );
      body = _search('');
      await expectLater(
        client.search('Tolkien'),
        throwsA(
          isA<AnnaArchiveException>().having(
            (error) => error.attempts,
            'attempts',
            hasLength(2),
          ),
        ),
      );
    },
  );

  test(
    'malformed metadata, service errors and challenge pages are not empty',
    () async {
      for (final sample in [
        (
          body: '<html>Welcome to nginx!</html>',
          kind: AnnaArchiveFailureKind.markup,
        ),
        (body: _search(_card(format: '')), kind: AnnaArchiveFailureKind.markup),
        (
          body: _search('', message: 'Error during search.'),
          kind: AnnaArchiveFailureKind.unavailable,
        ),
        (
          body: _search(
            '',
            message:
                'The search took too long, which means you might see inaccurate results.',
          ),
          kind: AnnaArchiveFailureKind.unavailable,
        ),
        (body: _challenge, kind: AnnaArchiveFailureKind.challenge),
      ]) {
        final client = _client((_) => _response(sample.body));
        await expectLater(
          client.search('Tolkien'),
          throwsA(_failure(sample.kind)),
        );
      }
    },
  );

  test(
    'fails over serially, retains successful mirror, and preserves cookies on redirects',
    () async {
      final requests = <Uri>[];
      final client = _client(
        (request) {
          requests.add(request.uri);
          if (request.uri.host == 'first.example') {
            return _response(_challenge, status: 403);
          }
          if (!request.uri.queryParameters.containsKey('check')) {
            return _response(
              '',
              status: 302,
              headers: {
                'location': ['${request.uri}&check=1'],
                'set-cookie': [
                  '__ddg1_=legitimate-server-cookie; Path=/; HttpOnly',
                ],
              },
            );
          }
          expect(request.headers['Cookie'], '__ddg1_=legitimate-server-cookie');
          return _response(_search(_card()));
        },
        mirrors: [
          'https://first.example',
          'https://second.example',
          'https://third.example',
        ],
      );
      expect((await client.search('Tolkien')).single.id, _first);
      expect(requests.map((uri) => uri.host), [
        'first.example',
        'second.example',
        'second.example',
      ]);
      requests.clear();
      await client.search('Tolkien');
      expect(requests.map((uri) => uri.host), [
        'second.example',
        'second.example',
      ]);
    },
  );

  test(
    'retains original transport errors and final challenged URI/status/body',
    () async {
      final offline = DioException(
        requestOptions: RequestOptions(path: 'https://first.example/search'),
        type: DioExceptionType.connectionError,
        error: const SocketException('SOCKS connection refused'),
      );
      final client = _client((request) {
        if (request.uri.host == 'first.example') throw offline;
        return _response(_challenge, status: 403);
      }, mirrors: ['https://first.example', 'https://second.example']);
      try {
        await client.search('Tolkien');
        fail('A blocked source must not be an empty success');
      } on AnnaArchiveException catch (error) {
        expect(error.attempts, hasLength(2));
        expect(error.attempts.first.error, same(offline));
        final challenge = error.attempts.last.error as AnnaArchivePageException;
        expect(challenge.kind, AnnaArchiveFailureKind.challenge);
        expect(challenge.statusCode, 403);
        expect(challenge.uri.host, 'second.example');
        expect(challenge.responseExcerpt, contains('DDoS-Guard'));
        expect(error.toString(), contains('SOCKS connection refused'));
      }
    },
  );

  test(
    'redirects are bounded and never carry source cookies to another origin',
    () async {
      var calls = 0;
      final client = _client((_) {
        calls++;
        return _response(
          '',
          status: 302,
          headers: {
            'location': ['https://unapproved.example/search'],
            'set-cookie': ['aa_account_id2=private; Path=/'],
          },
        );
      });
      await expectLater(
        client.search('Tolkien'),
        throwsA(_failure(AnnaArchiveFailureKind.http)),
      );
      expect(calls, 1);
      var loops = 0;
      final looping = _client((request) {
        loops++;
        return _response(
          '',
          status: 302,
          headers: {
            'location': [request.uri.toString()],
          },
        );
      });
      await expectLater(
        looping.search('Tolkien'),
        throwsA(_failure(AnnaArchiveFailureKind.http)),
      );
      expect(loops, 4);
    },
  );

  test(
    'md5 resolution follows published LibGen landing links to real file URLs',
    () async {
      final requests = <Uri>[];
      final client = _client((request) {
        requests.add(request.uri);
        if (request.uri.path == '/md5/$_first') {
          return _response('''<html><body><div id="md5-panel-downloads">
          <a class="js-download-link" href="/fast_download/$_first/0/0">Members</a>
          <a class="js-download-link" href="/slow_download/$_first/0/0">Browser verification</a>
          <a class="js-download-link" href="https://libgen.example/ads.php?md5=$_first">LibGen</a>
          <a class="js-download-link" href="//files.example/novel.epub">Direct</a>
          <a class="js-download-link" href="https://libgen.example/ads.php?md5=$_first">Duplicate</a>
        </div><a href="/donate">Donate</a></body></html>''');
        }
        expect(request.uri.host, 'libgen.example');
        expect(request.uri.queryParameters['md5'], _first);
        expect(request.headers['Cookie'], isNull);
        return _response('''<html><body>
        <table><tr><td><a href="get.php?md5=$_first&amp;key=temporary">GET</a></td></tr></table>
        <a href="/donate">Support</a></body></html>''');
      });
      expect(await client.getDownloadLinks(_first.toUpperCase()), [
        'https://libgen.example/get.php?md5=$_first&key=temporary',
        'https://files.example/novel.epub',
      ]);
      expect(requests, hasLength(2));
    },
  );

  test(
    'published IPFS gateway page yields file URLs, not its HTML landing page',
    () async {
      final requests = <Uri>[];
      final client = _client((request) {
        requests.add(request.uri);
        if (request.uri.path.startsWith('/md5/')) {
          return _response(
            '<div id="md5-panel-downloads">'
            '<a class="js-download-link" href="/ipfs_downloads/md5:$_first">IPFS</a>'
            '<a class="js-download-link" href="https://libgen.example/ads.php?md5=$_first">LibGen</a>'
            '</div>',
          );
        }
        expect(request.uri.path, '/ipfs_downloads/md5:$_first');
        return _response('''<main>
        <h2>IPFS downloads</h2><ul>
          <li><a href="https://gateway.example/ipfs/QmPublished?filename=book.pdf">IPFS Gateway #1</a></li>
          <li><a href="//second-gateway.example/ipfs/QmPublished?filename=book.pdf">IPFS Gateway #2</a></li>
          <li><a href="https://gateway.example/ipfs/QmPublished?filename=book.pdf">Duplicate</a></li>
          <li><a href="javascript:alert(1)">Unsafe</a></li>
        </ul><a href="/md5/$_first">All download links</a>
        <a href="https://unrelated.example/donate">Donate</a>
      </main>''');
      });
      expect(await client.getDownloadLinks(_first), [
        'https://gateway.example/ipfs/QmPublished?filename=book.pdf',
        'https://second-gateway.example/ipfs/QmPublished?filename=book.pdf',
      ]);
      expect(
        requests,
        hasLength(2),
        reason:
            'Resolving published URLs must not fan out to file gateways or unused sources',
      );
    },
  );

  test(
    'md5 resolution handles library.lol relative GET and rejects changed landing markup',
    () async {
      var broken = false;
      final client = _client((request) {
        if (request.uri.path.startsWith('/md5/')) {
          return _response(
            '<div id="md5-panel-downloads">'
            '<a class="js-download-link" href="https://library.example/main/$_first">LibGen</a></div>',
          );
        }
        return _response(
          broken
              ? '<h1>Welcome to nginx!</h1>'
              : '<div id="download"><h2><a href="../files/book.pdf">GET</a></h2></div>',
        );
      });
      expect(await client.getDownloadLinks(_first), [
        'https://library.example/files/book.pdf',
      ]);
      broken = true;
      await expectLater(
        client.getDownloadLinks(_first),
        throwsA(_failure(AnnaArchiveFailureKind.markup)),
      );
    },
  );

  test(
    'md5 download failures stay errors and browser/member pages are never file URLs',
    () async {
      for (final sample in [
        (body: _challenge, kind: AnnaArchiveFailureKind.challenge),
        (
          body: '<html>Unknown file page</html>',
          kind: AnnaArchiveFailureKind.markup,
        ),
        (
          body:
              '<div id="md5-panel-downloads"><a class="js-download-link" href="/slow_download/$_first/0/0">Slow</a></div>',
          kind: AnnaArchiveFailureKind.unavailable,
        ),
      ]) {
        final client = _client((_) => _response(sample.body));
        await expectLater(
          client.getDownloadLinks(_first),
          throwsA(_failure(sample.kind)),
        );
      }
      final empty = _client(
        (_) => _response(
          '<div id="md5-panel-downloads">No downloads found.</div>',
        ),
      );
      expect(await empty.getDownloadLinks(_first), isEmpty);
    },
  );

  test(
    'legitimate browser session is pinned to its approved origin on failover',
    () async {
      final hosts = <String>[];
      final adapter = _Adapter((request) {
        hosts.add(request.uri.host);
        expect(request.headers['User-Agent'], 'Exact browser UA');
        if (request.uri.host == 'session.example') {
          expect(request.headers['Cookie'], '__ddg2_=user-supplied-clearance');
          return _response(_challenge, status: 403);
        }
        expect(request.headers['Cookie'], isNull);
        return _response(_search(_card(year: '', cover: 'javascript:invalid')));
      });
      final client = AnnaArchiveClient(
        dio: Dio()..httpClientAdapter = adapter,
        mirrors: ['https://fallback.example', 'https://session.example'],
        sessionOrigin: 'https://session.example',
        cookies: {'__ddg2_': 'user-supplied-clearance'},
        userAgent: 'Exact browser UA',
      );
      addTearDown(client.close);
      final result = (await client.search('Tolkien')).single;
      expect(hosts, ['session.example', 'fallback.example']);
      expect(
        result.size,
        '0.5MB',
        reason: 'Year is absent in real live records',
      );
      expect(
        result.imgUrl,
        isEmpty,
        reason: 'Unsafe and data covers are not usable URLs',
      );
    },
  );

  test(
    'invalid md5 and empty query do not issue requests, close owns injected transport',
    () async {
      final adapter = _Adapter((_) => throw StateError('No request expected'));
      final client = AnnaArchiveClient(
        dio: Dio()..httpClientAdapter = adapter,
        mirrors: ['https://first.example'],
      );
      expect(await client.search('  '), isEmpty);
      await expectLater(
        client.getDownloadLinks('../account'),
        throwsArgumentError,
      );
      client.close();
      expect(adapter.closed, isTrue);
    },
  );
}
