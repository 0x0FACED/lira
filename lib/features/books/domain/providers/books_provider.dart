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
import 'package:zlibrary_api/zlibrary_api.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../search/domain/models/search_result_item.dart';
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

        // Estimate page count based on total characters (~1800 chars/page)
        final totalChars = parsed.chapters.fold<int>(
          0,
          (sum, c) =>
              sum + c.htmlContent.replaceAll(RegExp(r'<[^>]*>'), '').length,
        );
        pageCount = (totalChars / 1800).ceil().clamp(1, 999999);

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

  Future<void> downloadAndImportBook(
    SearchResultItem book,
    WidgetRef ref,
  ) async {
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

    // Immediately show indeterminate progress indicator
    ref.read(downloadNotifierProvider.notifier).setProgress(book.id, -1);

    List<String> downloadLinks = [];

    if (book.source == SearchResultSource.anna) {
      final annaApi = anna.AnnaApi();
      downloadLinks = await annaApi.getDownloadLinks(book.id);
    } else if (book.source == SearchResultSource.zlibrary) {
      final zLibCreds = ref.read(zLibraryCredentialsProvider);
      final zBook = book.originalObject as ZLibraryBook;
      if (zBook.downloadUrl != null) {
        downloadLinks = [zBook.downloadUrl!];
      } else {
        // Fallback: fetch book page for download link
        final zLibApi = ZLibraryApi(cookies: zLibCreds?.cookies);
        final bookDetails = await zLibApi.fetchBookDetails(zBook);
        if (bookDetails.downloadUrl != null) {
          downloadLinks = [bookDetails.downloadUrl!];
        }
      }
    }

    if (downloadLinks.isEmpty) {
      ref.read(downloadNotifierProvider.notifier).finish(book.id);
      throw Exception('No download links found');
    }

    // Prepare filename and directories
    final appDocDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDocDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final extension = book.format;
    final bookId = const Uuid().v4();
    final newFilePath = p.join(booksDir.path, '$bookId.$extension');

    // Create a CancelToken for this download
    final cancelToken = ref
        .read(downloadNotifierProvider.notifier)
        .startDownload(book.id);

    // For Z-Library downloads, build initial cookies and resolve the browser check via Dio
    String? zLibCookieHeader;
    if (book.source == SearchResultSource.zlibrary) {
      final userCookies = ref.read(zLibraryCredentialsProvider)?.cookies;
      final cookieMap = <String, String>{};
      if (userCookies != null) cookieMap.addAll(userCookies);

      // Probe the download URL to solve the JS browser check challenge
      final probeDio = Dio();
      for (final link in downloadLinks) {
        try {
          final probeResponse = await probeDio.get(
            link,
            options: Options(
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
                if (cookieMap.isNotEmpty)
                  'Cookie': cookieMap.entries
                      .map((e) => '${e.key}=${e.value}')
                      .join('; '),
              },
              validateStatus: (status) => true, // Accept 503
              responseType: ResponseType.plain,
              followRedirects: false,
            ),
          );

          if (probeResponse.statusCode == 503 &&
              probeResponse.data.toString().contains('Checking your browser')) {
            print('ZLibraryApi: Download challenge encountered, solving...');
            final token = BrowserCheckSolver.solve(
              probeResponse.data.toString(),
            );
            if (token != null) {
              print('ZLibraryApi: Download challenge solved. c_token=$token');
              cookieMap['c_token'] = token;
            }
          }
          break; // Only need to probe one link
        } catch (e) {
          print('ZLibraryApi: Probe failed for $link - $e');
        }
      }

      zLibCookieHeader = cookieMap.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }

    // Try links until one works
    bool success = false;
    for (final link in downloadLinks) {
      try {
        final options = Options(
          headers: zLibCookieHeader != null
              ? {
                  'User-Agent':
                      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
                  'Cookie': zLibCookieHeader,
                }
              : null,
        );
        await Dio().download(
          link,
          newFilePath,
          options: options,
          cancelToken: cancelToken,
          onReceiveProgress: (count, total) {
            if (total != -1) {
              final progress = count / total;
              ref
                  .read(downloadNotifierProvider.notifier)
                  .setProgress(book.id, progress);
            }
          },
        );
        success = true;
        break; // Successfully downloaded
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          // User cancelled — clean up partial file if exists
          final partialFile = File(newFilePath);
          if (await partialFile.exists()) {
            await partialFile.delete();
          }
          throw Exception('download_cancelled');
        }
        // ignore: avoid_print
        print('Download from link failed: $link - $e');
        continue;
      } catch (e) {
        // ignore: avoid_print
        print('Download from link failed: $link - $e');
        continue;
      }
    }

    ref.read(downloadNotifierProvider.notifier).finish(book.id);

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
        // Estimate page count based on total characters (~1800 chars/page)
        final totalChars = parsed.chapters.fold<int>(
          0,
          (sum, c) =>
              sum + c.htmlContent.replaceAll(RegExp(r'<[^>]*>'), '').length,
        );
        pageCount = (totalChars / 1800).ceil().clamp(1, 999999);

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

  /// Encode raw BGRA pixels (from pdfrx) to PNG
  /// pdfrx returns BGRA order, but dart:ui expects RGBA
  Future<Uint8List?> _encodePng(Uint8List pixels, int width, int height) async {
    try {
      // Convert BGRA to RGBA by swapping R and B channels
      final rgbaPixels = Uint8List(pixels.length);
      for (int i = 0; i < pixels.length; i += 4) {
        final b = pixels[i];
        final g = pixels[i + 1];
        final r = pixels[i + 2];
        final a = pixels[i + 3];
        // Write as RGBA
        rgbaPixels[i] = r;
        rgbaPixels[i + 1] = g;
        rgbaPixels[i + 2] = b;
        rgbaPixels[i + 3] = a;
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgbaPixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (image) => completer.complete(image),
      );
      final image = await completer.future;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      // ignore: avoid_print
      print('Error encoding PNG: $e');
      return null;
    }
  }
}
