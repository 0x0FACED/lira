import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:epub_engine/epub_engine.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:annas_archive_api/annas_archive_api.dart' as anna;

import '../../../../core/di/injection.dart';
import '../models/book_dto.dart';
import '../../data/repositories/books_local_repository.dart';
import '../../../search/domain/providers/download_provider.dart';

final booksControllerProvider =
    AsyncNotifierProvider<BooksController, List<BookDto>>(() {
      return BooksController();
    });

class BooksController extends AsyncNotifier<List<BookDto>> {
  late final BooksLocalRepository _repository;

  @override
  FutureOr<List<BookDto>> build() async {
    _repository = getIt<BooksLocalRepository>();
    return _repository.getAllBooks();
  }

  Future<void> importBook() async {
    const bookGroup = XTypeGroup(
      label: 'Books (EPUB, PDF)',
      extensions: ['epub', 'pdf'],
      mimeTypes: ['application/epub+zip', 'application/pdf'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [bookGroup]);

    if (file == null) return; // User cancelled

    final extension = p.extension(file.path).replaceAll('.', '').toLowerCase();
    if (extension != 'epub' && extension != 'pdf') {
      throw Exception('Unsupported file format: $extension');
    }

    final title = p.basenameWithoutExtension(file.path);

    // Copy file to local app directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDocDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final bookId = const Uuid().v4();
    final newFilePath = p.join(booksDir.path, '$bookId.$extension');
    await File(file.path).copy(newFilePath);

    // Extract cover and metadata
    String author = 'Unknown Author';
    String? coverPath;
    int pageCount = 0;
    int fileSizeBytes = await File(file.path).length();

    if (extension == 'epub') {
      try {
        final bytes = await File(newFilePath).readAsBytes();
        final parsed = await EpubParser.parse(bytes);
        author = parsed.author;

        // Count chapters as a proxy for pages if real page count isn't available
        pageCount = parsed.chapters.length;

        if (parsed.coverImage != null) {
          final coversDir = Directory(p.join(appDocDir.path, 'covers'));
          if (!await coversDir.exists()) {
            await coversDir.create(recursive: true);
          }
          coverPath = p.join(coversDir.path, '$bookId.jpg');
          await File(coverPath).writeAsBytes(parsed.coverImage!);
          // ignore: avoid_print
          print('Cover saved: $coverPath (${parsed.coverImage!.length} bytes)');
        } else {
          // ignore: avoid_print
          print('No cover image found in EPUB');
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error extracting EPUB metadata: $e');
      }
    } else if (extension == 'pdf') {
      try {
        final doc = await PdfDocument.openFile(newFilePath);
        pageCount = doc.pages.length;

        if (doc.pages.isNotEmpty) {
          final page = doc.pages[0];
          final pdfImage = await page.render(
            fullWidth: 300,
            fullHeight: (300 * page.height / page.width).roundToDouble(),
          );
          if (pdfImage != null) {
            final coversDir = Directory(p.join(appDocDir.path, 'covers'));
            if (!await coversDir.exists()) {
              await coversDir.create(recursive: true);
            }
            coverPath = p.join(coversDir.path, '$bookId.png');
            // Encode RGBA pixels to PNG
            final pngBytes = await _encodePng(
              pdfImage.pixels,
              pdfImage.width,
              pdfImage.height,
            );
            if (pngBytes != null) {
              await File(coverPath).writeAsBytes(pngBytes);
              // ignore: avoid_print
              print('PDF cover saved: $coverPath');
            }
          }
        }
        doc.dispose();
      } catch (e) {
        // ignore: avoid_print
        print('Error extracting PDF cover: $e');
      }
    }

    final newBook = BookDto(
      id: bookId,
      title: title,
      author: author,
      format: extension,
      fileUrl: newFilePath,
      coverUrl: coverPath ?? '',
      createdAt: DateTime.now(),
      pageCount: pageCount,
      fileSizeBytes: fileSizeBytes,
    );

    await _repository.saveBook(newBook);

    // Update state
    final currentBooks = state.value ?? [];
    state = AsyncData([...currentBooks, newBook]);
  }

  Future<void> downloadAndImportBook(anna.Book book, WidgetRef ref) async {
    final currentBooks = state.value ?? [];

    // Duplicate check by title and author as requested
    final isDuplicate = currentBooks.any(
      (b) =>
          b.title.toLowerCase() == book.title.toLowerCase() &&
          b.author.toLowerCase() == book.author.toLowerCase(),
    );

    if (isDuplicate) {
      throw Exception('duplicate_book');
    }

    // Get download links from the API
    final annaApi = anna.AnnaApi();
    final downloadLinks = await annaApi.getDownloadLinks(book.md5);

    if (downloadLinks.isEmpty) {
      throw Exception('No download links found');
    }

    // Prepare filename and directories
    final appDocDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDocDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    // Anna archive provides extension, default to epub if missing
    final extension = book.format.extension;
    final bookId = const Uuid().v4();
    final newFilePath = p.join(booksDir.path, '$bookId.$extension');

    // Try links until one works
    bool success = false;
    for (final link in downloadLinks) {
      try {
        await Dio().download(
          link,
          newFilePath,
          onReceiveProgress: (count, total) {
            if (total != -1) {
              final progress = count / total;
              ref
                  .read(downloadNotifierProvider.notifier)
                  .setProgress(book.md5, progress);
            }
          },
        );
        success = true;
        break; // Sucessfully downloaded
      } catch (e) {
        // ignore: avoid_print
        print('Download from link failed: $link - $e');
        continue;
      }
    }

    ref.read(downloadNotifierProvider.notifier).finish(book.md5);

    if (!success) {
      throw Exception('Failed to download from all available links');
    }

    // Extract cover and metadata dynamically like import
    String author = book.author;
    String? coverPath;
    int pageCount = 0;
    int fileSizeBytes = await File(newFilePath).length();

    if (extension == 'epub') {
      try {
        final bytes = await File(newFilePath).readAsBytes();
        final parsed = await EpubParser.parse(bytes);
        if (author.isEmpty) {
          author = parsed.author;
        }
        pageCount = parsed.chapters.length;

        if (parsed.coverImage != null) {
          final coversDir = Directory(p.join(appDocDir.path, 'covers'));
          if (!await coversDir.exists()) {
            await coversDir.create(recursive: true);
          }
          coverPath = p.join(coversDir.path, '$bookId.jpg');
          await File(coverPath).writeAsBytes(parsed.coverImage!);
        } else if (book.imgUrl.isNotEmpty) {
          // Using cover from API if EPUB has no cover
          final coversDir = Directory(p.join(appDocDir.path, 'covers'));
          if (!await coversDir.exists())
            await coversDir.create(recursive: true);
          coverPath = p.join(coversDir.path, '$bookId.jpg');
          await Dio().download(book.imgUrl, coverPath);
        }
      } catch (e) {
        print('Error extracting EPUB metadata: $e');
      }
    } else if (extension == 'pdf') {
      try {
        final doc = await PdfDocument.openFile(newFilePath);
        pageCount = doc.pages.length;

        if (doc.pages.isNotEmpty) {
          final page = doc.pages[0];
          final pdfImage = await page.render(
            fullWidth: 300,
            fullHeight: (300 * page.height / page.width).roundToDouble(),
          );
          if (pdfImage != null) {
            final coversDir = Directory(p.join(appDocDir.path, 'covers'));
            if (!await coversDir.exists()) {
              await coversDir.create(recursive: true);
            }
            coverPath = p.join(coversDir.path, '$bookId.png');
            final pngBytes = await _encodePng(
              pdfImage.pixels,
              pdfImage.width,
              pdfImage.height,
            );
            if (pngBytes != null) {
              await File(coverPath).writeAsBytes(pngBytes);
            }
          }
        }
        doc.dispose();
      } catch (e) {
        print('Error extracting PDF cover: $e');
      }
    }

    final newBook = BookDto(
      id: bookId,
      title: book.title,
      author: author,
      format: extension,
      fileUrl: newFilePath,
      coverUrl: coverPath ?? '',
      createdAt: DateTime.now(),
      pageCount: pageCount,
      fileSizeBytes: fileSizeBytes,
    );

    await _repository.saveBook(newBook);
    state = AsyncData([...currentBooks, newBook]);
  }

  Future<void> updateBook(BookDto updatedBook) async {
    await _repository.updateBook(updatedBook);

    // Update local state by replacing the old book
    final currentBooks = state.value ?? [];
    state = AsyncData(
      currentBooks
          .map((b) => b.id == updatedBook.id ? updatedBook : b)
          .toList(),
    );
  }

  Future<void> removeBook(String id) async {
    await _repository.deleteBook(id);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAllBooks());
  }

  /// Encode raw RGBA pixels to PNG using dart:ui
  Future<Uint8List?> _encodePng(Uint8List pixels, int width, int height) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (image) => completer.complete(image),
      );
      final image = await completer.future;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
