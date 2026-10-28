import 'dart:io';
import 'dart:isolate';

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/di/injection.dart';
import '../../books/data/repositories/books_local_repository.dart';
import '../../books/domain/models/book_dto.dart';
import '../../books/domain/providers/books_provider.dart';
import '../data/discover_feed_parser.dart';
import '../data/discover_repository.dart';
import 'discover_content_providers.dart';
import 'discover_item.dart';

final savedMaterialIdsProvider = FutureProvider<Set<String>>((ref) async {
  final books = await getIt<BooksLocalRepository>().getAllBooks();
  return books.map((book) => book.id).toSet();
});

final materialControllerProvider =
    StateNotifierProvider<MaterialController, Map<String, AsyncValue<BookDto>>>(
      (ref) {
        return MaterialController(
          repository: ref.watch(discoverRepositoryProvider),
          books: getIt<BooksLocalRepository>(),
          directory: getApplicationDocumentsDirectory,
          onSaved: () {
            ref.invalidate(savedMaterialIdsProvider);
            ref.invalidate(booksControllerProvider);
          },
        );
      },
    );

class MaterialController
    extends StateNotifier<Map<String, AsyncValue<BookDto>>> {
  MaterialController({
    required DiscoverRepository repository,
    required BooksLocalRepository books,
    required Future<Directory> Function() directory,
    required void Function() onSaved,
  }) : _repository = repository,
       _books = books,
       _directory = directory,
       _onSaved = onSaved,
       super(const {});

  final DiscoverRepository _repository;
  final BooksLocalRepository _books;
  final Future<Directory> Function() _directory;
  final void Function() _onSaved;
  final _inFlight = <String, Future<BookDto>>{};
  final _saveRequested = <String>{};

  Future<bool> isSaved(String id) => _books.isSaved(id);

  Future<BookDto> prepare(DiscoverItem item, {bool save = false}) {
    try {
      if (item.id != discoverMaterialId(item.url)) {
        throw const FormatException(
          'The material identifier does not match its original URL',
        );
      }
    } catch (error, stack) {
      if (mounted) state = {...state, item.id: AsyncError(error, stack)};
      return Future.error(error, stack);
    }
    if (save) _saveRequested.add(item.id);
    final pending = _inFlight[item.id];
    if (pending != null) return pending;
    if (mounted) state = {...state, item.id: const AsyncLoading()};
    return _inFlight[item.id] = _prepare(item);
  }

  Future<BookDto> _prepare(DiscoverItem item) async {
    try {
      var book = await _books.getBookById(item.id);
      if (book != null) {
        final path = book.fileUrl;
        if (path == null ||
            !await File(path).exists() ||
            await File(path).length() == 0) {
          throw FileSystemException(
            'The previously prepared material file is missing',
            path,
          );
        }
      } else {
        final directory = Directory(p.join((await _directory()).path, 'books'));
        await directory.create(recursive: true);
        final file = File(p.join(directory.path, '${item.id}.epub'));
        if (!await file.exists()) {
          final bytes = await _repository.buildEpub(item);
          final temporary = File('${file.path}.part');
          try {
            await temporary.writeAsBytes(bytes, flush: true);
            await temporary.rename(file.path);
          } finally {
            if (await temporary.exists()) await temporary.delete();
          }
        }
        // An orphan file can remain after an interrupted DB insert. Reuse its
        // immutable content and metadata instead of downloading a newer version.
        final bytes = await file.readAsBytes();
        final metadata = await Isolate.run(() async {
          final parsed = await EpubParser.parse(bytes);
          final characters = parsed.chapters.fold<int>(
            0,
            (sum, chapter) =>
                sum +
                chapter.htmlContent.replaceAll(RegExp(r'<[^>]*>'), '').length,
          );
          return (
            title: parsed.title,
            author: parsed.author,
            pages: (characters / 1800).ceil().clamp(1, 999999),
          );
        });
        book = BookDto(
          id: item.id,
          title: metadata.title,
          author: metadata.author,
          format: 'epub',
          fileUrl: file.path,
          createdAt: (await file.stat()).modified,
          fileSizeBytes: bytes.length,
          pageCount: metadata.pages,
        );
        await _books.saveBook(book, isSaved: false);
      }
      if (_saveRequested.contains(item.id)) {
        await _books.markSaved(item.id);
        if (mounted) _onSaved();
      }
      if (mounted) state = {...state, item.id: AsyncData(book)};
      return book;
    } catch (error, stack) {
      if (mounted) state = {...state, item.id: AsyncError(error, stack)};
      rethrow;
    } finally {
      // Cleanup precedes completion, so a late Save cannot join an already
      // completed read operation and accidentally miss promotion.
      _inFlight.remove(item.id);
      _saveRequested.remove(item.id);
    }
  }
}
