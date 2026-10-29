import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:lira/core/database/app_database.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/discover/data/discover_feed_parser.dart';
import 'package:lira/features/discover/data/discover_repository.dart';
import 'package:lira/features/discover/domain/discover_item.dart';
import 'package:lira/features/discover/domain/discover_source.dart';
import 'package:lira/features/discover/domain/material_controller.dart';
import 'package:xml/xml.dart';

final _cloudflare = discoverSourceCatalog.firstWhere(
  (source) => source.id == 'cloudflare',
);
final _rfc = discoverSourceCatalog.firstWhere(
  (source) => source.kind == DiscoverSourceKind.rfc,
);
final _articleUrl = Uri.parse('https://blog.cloudflare.com/technical-article');
final _item = DiscoverItem(
  id: discoverMaterialId(_articleUrl),
  sourceId: 'cloudflare',
  title: 'Technical article',
  url: _articleUrl,
  author: 'Engineering team',
  summary: 'This summary is not the article.',
  publishedAt: DateTime.utc(2026, 10, 23),
);
const _paragraph =
    'HTTP headers describe a representation and the semantics of a request. '
    'The complete document explains how byte ranges, caches, validators, and conditional '
    'requests interact without replacing the original representation with a short summary.';
const _article =
    '''<!doctype html><html lang="en"><body>
<nav>Site navigation must not be imported</nav><div class="post-content">
<p>$_paragraph</p><h2 id="ranges">Range requests</h2>
<pre><code>GET /object HTTP/1.1\n  Range: bytes=0-1023\n</code></pre>
<table><tr><th>Header</th><th>Meaning</th></tr><tr><td>Range</td><td>Selected bytes</td></tr></table>
<a href="#ranges">Local section</a>
<a href="/technical-article#ranges">Absolute section</a>
<a href="javascript:alert(1)#ranges" onclick="alert(1)">Unsafe link</a>
<img src="/images/diagram.png" srcset="https://tracking.example/a.png 2x" onerror="alert(1)"/>
<img data-src="/images/diagram.png" src="data:image/gif;base64,AAAA"/>
<img src="/images/wrapper.svg"/>
<script src="https://tracking.example/run.js">alert(1)</script>
<style>p {background: url(https://tracking.example/a)}</style>
<iframe src="https://video.example/diagram" title="Interactive diagram"></iframe>
<form>Subscribe to the newsletter</form>
</div></body></html>''';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==',
);

ResponseBody _textResponse(String body, {int status = 200}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
      },
    );

Dio _transport(FutureOr<ResponseBody> Function(RequestOptions) respond) {
  return Dio()..httpClientAdapter = _Adapter(respond);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody _publisher(RequestOptions request) {
  if (request.uri.path == '/technical-article') return _textResponse(_article);
  if (request.uri.path == '/images/wrapper.svg') {
    return _textResponse(
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" onload="alert(1)">
<script>alert(1)</script><image href="nested.png" width="10" height="10"/>
<foreignObject><svg><image href="https://tracking.example/a.png"/></svg></foreignObject>
<path d="M0 0 L10 10" stroke="black" fill="URL(//tracking.example/pattern)"/></svg>''',
    );
  }
  if ({
    '/images/diagram.png',
    '/images/nested.png',
  }.contains(request.uri.path)) {
    return ResponseBody.fromBytes(_png, 200);
  }
  throw StateError('Unexpected resource request: ${request.uri}');
}

String _rss({String title = 'Origin range requests'}) =>
    '''<?xml version="1.0"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/"><channel><title>Cloudflare</title>
<item><title>$title</title><link>https://blog.cloudflare.com/origin-range-requests/?utm_source=rss</link>
<description><![CDATA[<p>Serving large objects through a cache.</p>]]></description>
<dc:creator>Cloudflare Engineering</dc:creator><pubDate>Fri, 23 Oct 2026 18:22:59 +0000</pubDate>
<enclosure url="https://blog.cloudflare.com/image.png" type="image/png"/></item>
<item><title>Duplicate</title><link>https://blog.cloudflare.com/origin-range-requests#fragment</link></item>
</channel></rss>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'discover-regression-',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'concurrent feed demands share one refresh and immediately reuse the result',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      final repository = DiscoverRepository(
        directory: directory,
        dio: _transport((request) async {
          requests++;
          entered.complete();
          await release.future;
          return _textResponse(_rss());
        }),
      );
      addTearDown(repository.close);
      final first = repository.feed(_cloudflare);
      await entered.future;
      final second = repository.feed(_cloudflare, refresh: true);
      release.complete();
      expect((await second).items.single.id, (await first).items.single.id);
      await repository.feed(_cloudflare);
      expect(requests, 1);
    },
  );

  test(
    'RSS deduplicates canonical URLs and cache survives an offline restart',
    () async {
      var requests = 0;
      final initialTime = DateTime.utc(2026, 10, 28);
      final online = DiscoverRepository(
        directory: directory,
        now: () => initialTime,
        dio: _transport((request) {
          requests++;
          return _textResponse(_rss());
        }),
      );
      final first = await online.feed(_cloudflare);
      expect(first.items, hasLength(1));
      final item = first.items.single;
      expect(
        item.id,
        discoverMaterialId(
          Uri.parse('https://blog.cloudflare.com/origin-range-requests/'),
        ),
      );
      expect(item.url.hasFragment, isFalse);
      expect(item.url.hasQuery, isFalse);
      expect(item.author, 'Cloudflare Engineering');
      expect(item.imageUrl?.path, '/image.png');
      expect(item.publishedAt, DateTime.utc(2026, 10, 23, 18, 22, 59));
      expect(
        (await online.search(_cloudflare, 'objects cache')).single.id,
        item.id,
      );
      expect(
        await online.search(_cloudflare, 'unpublished historic article'),
        isEmpty,
      );
      expect(requests, 1);
      online.close();

      var offlineRequests = 0;
      final offline = DiscoverRepository(
        directory: directory,
        now: () => initialTime.add(const Duration(hours: 1)),
        dio: _transport((request) {
          offlineRequests++;
          throw const SocketException('Offline');
        }),
      );
      addTearDown(offline.close);
      final stale = await offline.feed(_cloudflare);
      expect(stale.isStale, isTrue);
      expect(stale.updatedAt, first.updatedAt);
      expect(stale.items.single.id, item.id);
      await offline.feed(_cloudflare);
      expect(
        offlineRequests,
        1,
        reason:
            'Provider invalidation must not immediately retry a failed refresh',
      );
    },
  );

  test(
    'invalid source content fails without cache and never overwrites valid cache',
    () async {
      var body = _rss();
      final repository = DiscoverRepository(
        directory: directory,
        dio: _transport((request) => _textResponse(body)),
      );
      addTearDown(repository.close);
      final cached = await repository.feed(_cloudflare);
      body = '<html><body>Service unavailable</body></html>';
      final stale = await repository.feed(_cloudflare, refresh: true);
      expect(stale.isStale, isTrue);
      expect(stale.items.single.id, cached.items.single.id);
      final empty = await directory.createTemp('empty-');
      final noCache = DiscoverRepository(
        directory: empty,
        dio: _transport((request) => _textResponse(body)),
      );
      addTearDown(noCache.close);
      await expectLater(noCache.feed(_cloudflare), throwsFormatException);
      await expectLater(
        repository.feed(
          discoverSourceCatalog.firstWhere((source) => source.isBookSource),
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('approved publisher feeds retain real dates, authors and covers', () {
    // Reduced entries from the six publishers' public RSS/Atom feeds.
    final entries = [
      (
        id: 'batrachospermum',
        xml: '''<rss xmlns:dc="http://purl.org/dc/elements/1.1/"><channel><item>
<title>Безногий морской огурец на колесиках</title>
<link>https://batrachospermum.ru/2026/08/acanthotrochus-verruciosseous/</link>
<dc:creator><![CDATA[Батрахоспермум]]></dc:creator>
<pubDate>Mon, 17 Aug 2026 20:35:42 +0000</pubDate>
<description><![CDATA[Сантиметровая гантелька с колесиками обнаружена в тихоокеанской донной пучине.]]></description>
</item></channel></rss>''',
        author: 'Батрахоспермум',
        date: DateTime.utc(2026, 8, 17, 20, 35, 42),
        image: null,
      ),
      (
        id: 'elementy',
        xml: '''<rss><channel><item>
<title>Древнейший осьминог оказался наутилусом</title>
<link>https://elementy.ru/novosti_nauki/434442/Drevneyshiy_osminog_okazalsya_nautilusom</link>
<description>&lt;p&gt;В 2000 году на территории знаменитого местонахождения Мазон-Крик в США нашли хорошо сохранившийся отпечаток.&lt;/p&gt;</description>
<image><url>https://elementy.ru/images/news/synchrotron_data_reveal_nautiloid_characters_in_pohlsepia_mazonensis_6_100.jpg</url></image>
<pubDate>26 Oct 2026 07:44:00 +0300</pubDate>
</item></channel></rss>''',
        author: '',
        date: DateTime.utc(2026, 10, 26, 4, 44),
        image:
            'https://elementy.ru/images/news/synchrotron_data_reveal_nautiloid_characters_in_pohlsepia_mazonensis_6_100.jpg',
      ),
      (
        id: 'our-world-in-data',
        xml: '''<feed xmlns="http://www.w3.org/2005/Atom"><entry>
<title><![CDATA[How much development aid is spent on climate change?]]></title>
<link rel="alternate" href="https://ourworldindata.org/how-much-development-aid-is-spent-on-climate-change"/>
<published>2026-10-26T00:00:00.000Z</published>
<author><name>Hannah Ritchie</name></author><author><name>Pablo Arriagada</name></author>
<summary><![CDATA[Around one-fifth of development aid is spent on climate-related projects.<br><br><a href="https://ourworldindata.org/how-much-development-aid-is-spent-on-climate-change"><img src="https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/59464533-c5ca-4a7e-7686-358fc7608500/w=1024"/></a>]]></summary>
</entry></feed>''',
        author: 'Hannah Ritchie, Pablo Arriagada',
        date: DateTime.utc(2026, 10, 26),
        image:
            'https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/59464533-c5ca-4a7e-7686-358fc7608500/w=1024',
      ),
      (
        id: 'jstor-daily',
        xml:
            '''<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel><item>
<title>London’s Railway for the Dead</title><link>https://daily.jstor.org/londons-railway-for-the-dead/</link>
<dc:creator><![CDATA[Amelia Soth]]></dc:creator><pubDate>Thu, 29 Oct 2026 13:43:00 +0000</pubDate>
<description><![CDATA[<p>As London's graveyards overflowed, a private company proposed a remarkable new way to bury the dead.</p>]]></description>
<content:encoded><![CDATA[<figure class="wp-caption"><img src="https://daily.jstor.org/wp-content/uploads/2026/10/london_necropolis_1_1050.jpg"/><figcaption>Enon Chapel</figcaption></figure>]]></content:encoded>
</item></channel></rss>''',
        author: 'Amelia Soth',
        date: DateTime.utc(2026, 10, 29, 13, 43),
        image:
            'https://daily.jstor.org/wp-content/uploads/2026/10/london_necropolis_1_1050.jpg',
      ),
      (
        id: 'aeon',
        xml: '''<rss xmlns:dc="http://purl.org/dc/elements/1.1/"><channel><item>
<title><![CDATA[The physics of getting fired]]></title><link>https://aeon.co/essays/how-to-use-physics-to-make-sense-of-the-messiness-of-life</link>
<dc:creator><![CDATA[Zahaan Bharmal]]></dc:creator><pubDate>Thu, 29 Oct 2026 10:00:00 GMT</pubDate>
<description><![CDATA[<p><img src="https://images.aeonmedia.co/images/afb6d18f-037c-451b-a48b-e7420fcaa8b4/essay-v1-test-v1-jiran-family-4srj_3nontc-unsplash.jpg?width=1200&quality=75&format=auto"/></p><p>Physics offered me a sense of order and purpose.</p>]]></description>
</item></channel></rss>''',
        author: 'Zahaan Bharmal',
        date: DateTime.utc(2026, 10, 29, 10),
        image:
            'https://images.aeonmedia.co/images/afb6d18f-037c-451b-a48b-e7420fcaa8b4/essay-v1-test-v1-jiran-family-4srj_3nontc-unsplash.jpg?width=1200&quality=75&format=auto',
      ),
      (
        id: 'mongabay',
        xml: '''<rss xmlns:dc="http://purl.org/dc/elements/1.1/"><channel><item>
<title>Between revered and hunted: The journey of human-otter coexistence in the Amazon</title>
<link>https://news.mongabay.com/2026/10/between-revered-and-hunted-the-journey-of-human-otter-coexistence-in-the-amazon/</link>
<pubDate>29 Oct 2026 16:21:07 +0000</pubDate><dc:creator><![CDATA[Sarah Brown]]></dc:creator><author><![CDATA[Latoya Abulu]]></author>
<enclosure url="https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29131318/pteronura-brasiliensis-2-768x512.jpg" type="image/jpeg"/>
<description><![CDATA[On a warm, humid morning, along the Içana River in Brazil’s upper Rio Negro Basin.]]></description>
</item></channel></rss>''',
        author: 'Sarah Brown',
        date: DateTime.utc(2026, 10, 29, 16, 21, 7),
        image:
            'https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29131318/pteronura-brasiliensis-2-768x512.jpg',
      ),
    ];
    for (final entry in entries) {
      final source = discoverSourceCatalog.firstWhere(
        (source) => source.id == entry.id,
      );
      final item = parseDiscoverMetadata(entry.xml, source).single;
      expect(item.sourceId, entry.id);
      expect(item.author, entry.author, reason: entry.id);
      expect(item.publishedAt, entry.date, reason: entry.id);
      expect(item.imageUrl?.toString(), entry.image, reason: entry.id);
      expect(item.summary, isNot(contains('<p>')), reason: entry.id);
    }
  });

  test('Atom author names exclude profile metadata and unsafe covers', () {
    final item = parseDiscoverMetadata(
      '''<feed xmlns="http://www.w3.org/2005/Atom"><entry>
<title>Development aid</title><link href="https://ourworldindata.org/aid"/>
<author><name>Hannah Ritchie</name><uri>https://ourworldindata.org/team/hannah-ritchie</uri></author>
<author><name>Pablo Arriagada</name><email>editor@example.org</email></author>
<summary><![CDATA[<img src="https://secret@images.example.org/tracker.png"/>]]></summary>
</entry></feed>''',
      discoverSourceCatalog.firstWhere(
        (source) => source.id == 'our-world-in-data',
      ),
    ).single;
    expect(item.author, 'Hannah Ritchie, Pablo Arriagada');
    expect(item.imageUrl, isNull);
  });

  test(
    'RFC searches the official index by number, abstract and author',
    () async {
      final repository = DiscoverRepository(
        directory: directory,
        dio: _transport((request) {
          expect(
            request.uri.toString(),
            'https://www.rfc-editor.org/rfc-index.xml',
          );
          return _textResponse(
            '''<rfc-index xmlns="https://www.rfc-editor.org/rfc-index">
<rfc-entry><doc-id>RFC9110</doc-id><title>HTTP Semantics</title>
<author><name>Roy T. Fielding</name></author><date><month>June</month><year>2022</year></date>
<abstract><p>The Hypertext Transfer Protocol is a stateless application-level protocol.</p></abstract>
<current-status>INTERNET STANDARD</current-status></rfc-entry>
<rfc-entry><doc-id>RFC8446</doc-id><title>The Transport Layer Security (TLS) Protocol Version 1.3</title>
<author><name>Eric Rescorla</name></author><date><month>August</month><year>2018</year></date>
<abstract><p>This document specifies a secure channel between two communicating peers.</p></abstract>
<current-status>PROPOSED STANDARD</current-status></rfc-entry>
</rfc-index>''',
          );
        }),
      );
      addTearDown(repository.close);
      expect(
        (await repository.search(_rfc, 'RFC 9110')).single.title,
        'RFC 9110: HTTP Semantics',
      );
      expect(
        (await repository.search(_rfc, '8446')).single.author,
        'Eric Rescorla',
      );
      expect(
        (await repository.search(_rfc, 'secure channel')).single.documentNumber,
        8446,
      );
      expect(
        (await repository.search(_rfc, 'fielding')).single.documentNumber,
        9110,
      );
      expect(await repository.search(_rfc, 'RFC 999999'), isEmpty);
    },
  );

  test(
    'article body takes precedence over the publisher header and taxonomy',
    () async {
      final repository = DiscoverRepository(
        directory: directory,
        dio: _transport(
          (_) => _textResponse('''
        <html><body><div class="post-content">
          <h1>Publisher heading</h1><p>Navigation and taxonomy outside the article</p>
          <div class="article-content"><p>$_paragraph</p><h2 id="details">Technical details</h2></div>
          <footer>Publisher footer</footer>
        </div></body></html>
      '''),
        ),
      );
      addTearDown(repository.close);
      final parsed = await EpubParser.parse(await repository.buildEpub(_item));
      final content = html.parse(parsed.chapters.single.htmlContent);
      expect(content.body!.text, contains(_paragraph));
      expect(content.querySelector('h2')!.id, 'details');
      expect(content.body!.text, isNot(contains('Publisher heading')));
      expect(content.body!.text, isNot(contains('Navigation and taxonomy')));
      expect(content.body!.text, isNot(contains('Publisher footer')));
    },
  );

  test(
    'full article EPUB retains technical content and localizes nested images safely',
    () async {
      final requested = <String>[];
      final repository = DiscoverRepository(
        directory: directory,
        dio: _transport((request) {
          requested.add(request.uri.toString());
          return _publisher(request);
        }),
      );
      addTearDown(repository.close);
      final bytes = await repository.buildEpub(_item);
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.first.name, 'mimetype');
      String text(String name) =>
          utf8.decode(archive.findFile(name)!.content as List<int>);
      expect(text('mimetype'), 'application/epub+zip');
      final opf = XmlDocument.parse(text('EPUB/package.opf'));
      expect(
        opf.descendants
            .whereType<XmlElement>()
            .firstWhere((node) => node.name.local == 'source')
            .innerText,
        _item.url.toString(),
      );
      expect(text('EPUB/package.opf'), contains('2026-10-23'));
      final chapter = html.parse(text('EPUB/content.xhtml'));
      expect(
        chapter.querySelector('pre code')!.text,
        'GET /object HTTP/1.1\n  Range: bytes=0-1023\n',
      );
      expect(chapter.querySelectorAll('table tr'), hasLength(2));
      expect(chapter.querySelectorAll('a[href="#ranges"]'), hasLength(2));
      expect(chapter.querySelector('a[href="${_item.url}"]'), isNotNull);
      expect(
        chapter.querySelector(
          'script, iframe, form, [onclick], [onerror], [srcset]',
        ),
        isNull,
      );
      expect(
        chapter
            .querySelectorAll('img')
            .every((image) => image.attributes['src']!.startsWith('images/')),
        isTrue,
      );
      expect(
        chapter.body!.text,
        isNot(contains('This summary is not the article')),
      );
      expect(chapter.body!.text, isNot(contains('Site navigation')));
      expect(
        requested.where((url) => url.endsWith('/images/diagram.png')),
        hasLength(1),
      );
      expect(requested.any((url) => url.contains('tracking.example')), isFalse);
      final svg = archive.files.singleWhere(
        (file) => file.name.endsWith('image-1'),
      );
      final svgText = utf8.decode(svg.content as List<int>);
      expect(svgText, isNot(contains('onload')));
      expect(svgText, isNot(contains('<script')));
      expect(svgText, isNot(contains('tracking.example')));
      expect(svgText, isNot(contains('foreignObject')));
      expect(svgText, contains('href="image-1-resource-0"'));
      expect(archive.findFile('EPUB/images/image-1-resource-0'), isNotNull);
      final native = await EpubParser.parse(bytes);
      expect(native.title, _item.title);
      expect(native.chapters, hasLength(1));
      expect(native.images, hasLength(3));
    },
  );

  test(
    'missing article content and corrupt image payloads fail instead of saving summaries',
    () async {
      final missing = DiscoverRepository(
        directory: directory,
        dio: _transport(
          (request) =>
              _textResponse('<html><body><h1>Access denied</h1></body></html>'),
        ),
      );
      addTearDown(missing.close);
      await expectLater(missing.buildEpub(_item), throwsFormatException);
      final broken = DiscoverRepository(
        directory: directory,
        dio: _transport(
          (request) => request.uri.path == '/technical-article'
              ? _textResponse(_article)
              : _textResponse('<html>Not an image</html>'),
        ),
      );
      addTearDown(broken.close);
      await expectLater(broken.buildEpub(_item), throwsFormatException);
    },
  );

  test(
    'a truncated raster signature is rejected before EPUB packaging',
    () async {
      final repository = DiscoverRepository(
        directory: directory,
        dio: _transport((request) {
          if (request.uri.path.endsWith('.png')) {
            return ResponseBody.fromBytes([
              0x89,
              0x50,
              0x4e,
              0x47,
              0x0d,
              0x0a,
              0x1a,
              0x0a,
            ], 200);
          }
          return _publisher(request);
        }),
      );
      addTearDown(repository.close);
      await expectLater(repository.buildEpub(_item), throwsFormatException);
    },
  );

  test(
    'an older RFC without HTML is packaged as exact preformatted official text',
    () async {
      const text =
          'Network Working Group\nRequest for Comments: 1\nRFC 1\n\n'
          'The HOST Software\n\n$_paragraph\n\n  0   1   2   3\n  +---+---+---+\n';
      final url = Uri.https('www.rfc-editor.org', '/rfc/rfc1.html');
      final item = DiscoverItem(
        id: discoverMaterialId(url),
        sourceId: 'rfc',
        title: 'RFC 1: Host Software',
        url: url,
        documentNumber: 1,
      );
      final repository = DiscoverRepository(
        directory: directory,
        dio: _transport(
          (request) => request.uri.path.endsWith('.html')
              ? _textResponse('Not found', status: 404)
              : _textResponse(text),
        ),
      );
      addTearDown(repository.close);
      final native = await EpubParser.parse(await repository.buildEpub(item));
      expect(
        html
            .parse(native.chapters.single.htmlContent)
            .querySelector('pre')!
            .text,
        text,
      );
    },
  );

  group('material persistence', () {
    late AppDatabase database;
    late BooksLocalRepository books;
    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      books = BooksLocalRepository(database);
    });
    tearDown(() async => database.close());

    test(
      'reading remains hidden, Save promotes immutable file without another fetch',
      () async {
        var requests = 0;
        final repository = DiscoverRepository(
          directory: directory,
          dio: _transport((request) {
            requests++;
            return _publisher(request);
          }),
        );
        addTearDown(repository.close);
        final controller = MaterialController(
          repository: repository,
          books: books,
          directory: () async => directory,
          onSaved: () {},
        );
        addTearDown(controller.dispose);
        final preview = await controller.prepare(_item);
        expect(await books.getAllBooks(), isEmpty);
        expect((await books.getBookById(_item.id))?.fileUrl, preview.fileUrl);
        final original = await File(preview.fileUrl!).readAsBytes();
        final count = requests;
        final changedMetadata = DiscoverItem(
          id: _item.id,
          sourceId: _item.sourceId,
          title: 'A changed publisher title',
          url: _item.url,
        );
        final saved = await controller.prepare(changedMetadata, save: true);
        expect(saved.id, preview.id);
        expect(saved.fileUrl, preview.fileUrl);
        expect(saved.title, _item.title);
        expect((await books.getAllBooks()).map((book) => book.id), [
          preview.id,
        ]);
        expect(await File(saved.fileUrl!).readAsBytes(), original);
        await controller.prepare(_item);
        expect(await books.isSaved(_item.id), isTrue);
        expect(requests, count);
        await File(saved.fileUrl!).delete();
        await expectLater(
          controller.prepare(_item),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          requests,
          count,
          reason: 'Missing immutable material must not be silently replaced',
        );
      },
    );

    test(
      'a Save joining an in-flight read promotes exactly the prepared document',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        var articleRequests = 0;
        final repository = DiscoverRepository(
          directory: directory,
          dio: _transport((request) async {
            if (request.uri.path == '/technical-article') {
              articleRequests++;
              entered.complete();
              await release.future;
            }
            return _publisher(request);
          }),
        );
        addTearDown(repository.close);
        final controller = MaterialController(
          repository: repository,
          books: books,
          directory: () async => directory,
          onSaved: () {},
        );
        addTearDown(controller.dispose);
        final reading = controller.prepare(_item);
        await entered.future;
        final saving = controller.prepare(_item, save: true);
        release.complete();
        final result = await saving;
        await reading;
        expect(articleRequests, 1);
        final savedBooks = await books.getAllBooks();
        expect(savedBooks.map((book) => book.id), [result.id]);
        expect(savedBooks.single.fileUrl, result.fileUrl);
      },
    );
  });
}
