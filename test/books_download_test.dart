import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/providers/books_provider.dart';
import 'package:lira/features/search/domain/models/search_result_item.dart';
import 'package:lira/features/search/domain/providers/book_source_clients.dart';
import 'package:lira/features/search/domain/providers/download_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

import '../packages/pdf_engine/test/support/pdf_fixture.dart';

Future<Uint8List> _coverPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffa63b20), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(600, 900);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Uint8List _epub(Uint8List cover) {
  final archive = Archive();
  void text(String path, String value) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  text('mimetype', 'application/epub+zip');
  text('META-INF/container.xml', '''
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
<rootfiles><rootfile full-path="EPUB/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  text('EPUB/content.opf', '''
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="id">download-regression</dc:identifier><dc:title>Local cover</dc:title>
<dc:creator>Author</dc:creator><dc:language>en</dc:language>
</metadata><manifest>
<item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
<item id="cover" href="cover.png" media-type="image/png" properties="cover-image"/>
</manifest><spine><itemref idref="chapter"/></spine></package>''');
  text(
    'EPUB/chapter.xhtml',
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>Chapter</h1><p>The downloaded document is readable.</p></body></html>',
  );
  archive.addFile(ArchiveFile('EPUB/cover.png', cover.length, cover));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final modulePath = Platform.environment['PDFIUM_PATH'];
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const htmlPage = '<!doctype html><html><title>LITERA Reader</title></html>';
  late Directory directory;
  late HttpServer server;
  late AppDatabase database;
  late BooksLocalRepository repository;
  late ProviderContainer container;
  late ZLibraryApi api;
  late Map<String, ({List<int> bytes, String type})> responses;
  late String detailsPath;

  String url(String path) =>
      'http://${server.address.address}:${server.port}$path';

  SearchResultItem book(String format, {String path = '/file'}) =>
      SearchResultItem.fromZLibraryBook(
        ZLibraryBook(
          id: 'download-$format',
          isbn: '',
          title: 'Downloaded $format',
          author: 'Author',
          coverUrl: url('/thumbnail'),
          publisher: '',
          year: '',
          language: 'en',
          extension: format,
          size: '',
          rating: '',
          url: 'https://catalog.test/book/example/title',
          downloadUrl: url(path),
        ),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('lira-download-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return directory.path;
          }
          throw StateError('Unexpected path-provider call: ${call.method}');
        });
    responses = {};
    detailsPath = '/file';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = responses[request.uri.path];
      if (response == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentType = ContentType.parse(response.type);
        request.response.add(response.bytes);
      }
      await request.response.close();
    });
    api = ZLibraryApi(
      mirrors: ['https://catalog.test'],
      client: MockClient(
        (_) async => http.Response(
          '<div class="details-book"><a class="addDownloadedBook" href="${url(detailsPath)}">Download</a></div>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BooksLocalRepository(database);
    getIt.registerSingleton<BooksLocalRepository>(repository);
    container = ProviderContainer(
      overrides: [zLibraryApiProvider.overrideWithValue(api)],
    );
    await container.read(booksControllerProvider.future);
    if (modulePath != null) Pdfrx.pdfiumModulePath = modulePath;
  });

  tearDown(() async {
    container.dispose();
    api.close();
    await server.close(force: true);
    await getIt.reset();
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await directory.delete(recursive: true);
  });

  Future<void> expectNoImportedFile() async {
    expect(await repository.getAllBooks(), isEmpty);
    expect(container.read(booksControllerProvider).requireValue, isEmpty);
    expect(await Directory('${directory.path}/books').list().toList(), isEmpty);
    expect(container.read(downloadNotifierProvider), isEmpty);
  }

  test(
    'HTTP 200 HTML is rejected without a library entry or leftover book',
    () async {
      responses['/file'] = (bytes: utf8.encode(htmlPage), type: 'text/html');
      await expectLater(
        container
            .read(booksControllerProvider.notifier)
            .downloadAndImportBook(book('epub')),
        throwsA(isA<Exception>()),
      );
      await expectNoImportedFile();
    },
  );

  test(
    'a truncated ZIP advertised as EPUB is rejected before import',
    () async {
      responses['/file'] = (
        bytes: [0x50, 0x4b, 0x03, 0x04, 0, 0],
        type: 'application/epub+zip',
      );
      await expectLater(
        container
            .read(booksControllerProvider.notifier)
            .downloadAndImportBook(book('epub')),
        throwsA(isA<Exception>()),
      );
      await expectNoImportedFile();
    },
  );

  test(
    'an HTML candidate falls back to a readable EPUB with its full-resolution embedded cover',
    () async {
      detailsPath = '/reader';
      responses['/reader'] = (bytes: utf8.encode(htmlPage), type: 'text/html');
      responses['/file'] = (
        bytes: _epub(await _coverPng()),
        type: 'application/octet-stream',
      );
      responses['/thumbnail'] = (
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==',
        ),
        type: 'image/png',
      );
      await container
          .read(booksControllerProvider.notifier)
          .downloadAndImportBook(book('epub'));
      final saved = (await repository.getAllBooks()).single;
      final codec = await ui.instantiateImageCodec(
        await File(saved.coverUrl!).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, 600);
        expect(frame.image.height, 900);
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test('a malformed PDF is rejected before import', () async {
    responses['/file'] = (
      bytes: utf8.encode('%PDF-1.6\nnot a PDF document'),
      type: 'application/pdf',
    );
    await expectLater(
      container
          .read(booksControllerProvider.notifier)
          .downloadAndImportBook(book('pdf')),
      throwsA(isA<Exception>()),
    );
    await expectNoImportedFile();
  }, skip: modulePath == null);

  test(
    'a valid PDF preserves its page count and cover aspect ratio',
    () async {
      responses['/file'] = (
        bytes: readerPdfFixtureBytes(),
        type: 'application/pdf',
      );
      await container
          .read(booksControllerProvider.notifier)
          .downloadAndImportBook(book('pdf'));
      final saved = (await repository.getAllBooks()).single;
      expect(saved.pageCount, 3);
      final codec = await ui.instantiateImageCodec(
        await File(saved.coverUrl!).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width / frame.image.height, closeTo(3 / 4, 0.001));
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    },
    skip: modulePath == null,
  );
}
