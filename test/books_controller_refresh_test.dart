import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/domain/providers/books_provider.dart';

class _SelectedBook extends FileSelectorPlatform {
  _SelectedBook(this.path);

  final String path;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('importing an EPUB without a creator stores an empty author', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lira-missing-author-',
    );
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = BooksLocalRepository(database);
    getIt.registerSingleton<BooksLocalRepository>(repository);
    final container = ProviderContainer();
    final selector = FileSelectorPlatform.instance;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() async {
      FileSelectorPlatform.instance = selector;
      messenger.setMockMethodCallHandler(pathChannel, null);
      container.dispose();
      await getIt.reset();
      await database.close();
      await directory.delete(recursive: true);
    });
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return directory.path;
      }
      throw StateError('Unexpected path-provider call: ${call.method}');
    });
    final archive = Archive();
    void addText(String path, String text) {
      final bytes = utf8.encode(text);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addText('mimetype', 'application/epub+zip');
    addText('META-INF/container.xml', '''
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
<rootfiles><rootfile full-path="EPUB/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
    addText('EPUB/content.opf', '''
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="id">missing-author</dc:identifier><dc:title>Anonymous book</dc:title>
<dc:language>en</dc:language></metadata>
<manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
<spine><itemref idref="chapter"/></spine></package>''');
    addText(
      'EPUB/chapter.xhtml',
      '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>Anonymous writing.</p></body></html>',
    );
    final file = await File(
      '${directory.path}/anonymous.epub',
    ).writeAsBytes(ZipEncoder().encode(archive)!);
    FileSelectorPlatform.instance = _SelectedBook(file.path);
    await container.read(booksControllerProvider.future);
    await container.read(booksControllerProvider.notifier).importBook();
    final imported = container
        .read(booksControllerProvider)
        .requireValue
        .single;
    expect(imported.author, isEmpty);
    expect(imported.pageCount, greaterThan(0));
    expect((await repository.getBookById(imported.id))!.author, isEmpty);
    expect(await File(imported.fileUrl!).exists(), isTrue);
  });

  test(
    'a mounted Library refreshes after repeated article saves without losing existing books',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = BooksLocalRepository(database);
      getIt.registerSingleton<BooksLocalRepository>(repository);
      final existing = BookDto(
        id: 'existing',
        title: 'Existing book',
        format: 'epub',
        createdAt: DateTime(2026, 10, 28),
      );
      await repository.saveBook(existing);
      final container = ProviderContainer();
      final subscription = container.listen(
        booksControllerProvider,
        (_, __) {},
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await getIt.reset();
        await database.close();
      });
      expect(
        (await container.read(
          booksControllerProvider.future,
        )).map((book) => book.id),
        ['existing'],
      );

      for (final id in ['article-one', 'article-two']) {
        final article = BookDto(
          id: id,
          title: id,
          format: 'epub',
          createdAt: existing.createdAt,
        );
        await repository.saveBook(article, isSaved: false);
        await repository.markSaved(id);
        container.invalidate(booksControllerProvider);
        final visible = await container.read(booksControllerProvider.future);
        expect(visible.map((book) => book.id), containsAll(['existing', id]));
      }
      expect(
        (await container.read(
          booksControllerProvider.future,
        )).map((book) => book.id).toSet(),
        {'existing', 'article-one', 'article-two'},
      );
    },
  );
}
