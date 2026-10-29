import 'dart:async';
import 'dart:collection';
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
import 'package:dio/io.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../../core/network/proxy_http_overrides.dart';
import '../../../search/domain/providers/book_source_clients.dart';
import '../../../search/domain/models/search_result_item.dart';
import '../models/book_dto.dart';
import '../../data/repositories/books_local_repository.dart';
import '../../../search/domain/providers/download_provider.dart';

final booksControllerProvider =
    AsyncNotifierProvider<BooksController, List<BookDto>>(() {
      return BooksController();
    });

class BooksController extends AsyncNotifier<List<BookDto>> {
  static const _desktopUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36';

  late final BooksLocalRepository _repository = getIt<BooksLocalRepository>();

  @override
  FutureOr<List<BookDto>> build() async {
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

  Future<void> downloadAndImportBook(SearchResultItem book) async {
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
    ZLibraryApi? zLibApi;
    String? zLibReferer;

    if (book.source == SearchResultSource.anna) {
      downloadLinks = await ref
          .read(annaArchiveClientProvider)
          .getDownloadLinks(book.id);
    } else if (book.source == SearchResultSource.zlibrary) {
      final api = ref.read(zLibraryApiProvider);
      zLibApi = api;
      final zBook = book.originalObject as ZLibraryBook;
      final candidateLinks = LinkedHashSet<String>();

      if (zBook.downloadUrl != null && zBook.downloadUrl!.isNotEmpty) {
        candidateLinks.add(zBook.downloadUrl!);
      }

      try {
        final bookDetails = await api.fetchBookDetails(zBook);
        if (bookDetails.downloadUrl != null &&
            bookDetails.downloadUrl!.isNotEmpty) {
          candidateLinks.add(bookDetails.downloadUrl!);
        }
        if (bookDetails.url.isNotEmpty) {
          zLibReferer = bookDetails.url;
        }
      } catch (e) {
        print('ZLibraryApi: Failed to fetch book details for download - $e');
      }

      zLibReferer ??= zBook.url.isNotEmpty ? zBook.url : null;
      downloadLinks = candidateLinks.toList().reversed.toList();
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

    final extension = book.format.toLowerCase();
    final bookId = const Uuid().v4();
    final newFilePath = p.join(booksDir.path, '$bookId.$extension');

    // Create a CancelToken for this download
    final cancelToken = ref
        .read(downloadNotifierProvider.notifier)
        .startDownload(book.id);

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 2),
        headers: {
          'User-Agent': zLibApi == null
              ? _desktopUserAgent
              : ZLibraryApi.userAgent,
        },
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () =>
          createProxiedHttpClient(config: ref.read(socks5ConfigProvider)),
    );

    // Try links until one works
    bool success = false;
    ParsedEpub? downloadedEpub;
    PdfDocument? downloadedPdf;
    Object? lastDownloadError;
    for (final link in downloadLinks) {
      try {
        var target = Uri.parse(link);
        final visited = <Uri>{};
        for (var redirect = 0; redirect < 6; redirect++) {
          if (!{'http', 'https'}.contains(target.scheme) ||
              target.host.isEmpty ||
              target.userInfo.isNotEmpty ||
              !visited.add(target)) {
            throw StateError('Invalid or looping book download redirect');
          }
          final cookies = zLibApi == null
              ? const <String, String>{}
              : await zLibApi.resolveDownloadCookies(target.toString());
          final cookieHeader = cookies.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('; ');
          final response = await dio.download(
            target.toString(),
            newFilePath,
            options: Options(
              headers: cookieHeader.isEmpty
                  ? null
                  : {
                      'Cookie': cookieHeader,
                      if (zLibReferer != null && zLibReferer.isNotEmpty)
                        'Referer': zLibReferer,
                    },
              // Rebuild credentials for every destination instead of allowing
              // Dio to forward a source session to an unrelated CDN.
              followRedirects: false,
              receiveDataWhenStatusError: false,
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 400,
            ),
            cancelToken: cancelToken,
            onReceiveProgress: (count, total) {
              if (total > 0) {
                ref
                    .read(downloadNotifierProvider.notifier)
                    .setProgress(book.id, count / total);
              }
            },
          );
          if (response.statusCode! >= 300) {
            final location = response.headers.value('location');
            if (location == null)
              throw StateError('Book download redirect has no destination');
            target = target.resolve(location);
            continue;
          }
          final contentType =
              response.headers
                  .value(Headers.contentTypeHeader)
                  ?.toLowerCase() ??
              '';
          if (contentType.contains('text/html') ||
              contentType.contains('application/xhtml+xml')) {
            throw const FormatException(
              'The source returned a web page instead of a book.',
            );
          }
          if (extension == 'epub') {
            downloadedEpub = await EpubParser.parse(
              await File(newFilePath).readAsBytes(),
            );
          } else if (extension == 'pdf') {
            downloadedPdf = await PdfDocument.openFile(newFilePath);
          } else {
            throw UnsupportedError('Unsupported file format: $extension');
          }
          success = true;
          break;
        }
        if (!success) throw StateError('Too many book download redirects');
        break; // Successfully downloaded
      } on DioException catch (e) {
        lastDownloadError = e;
        if (e.type == DioExceptionType.cancel) {
          // User cancelled — clean up partial file if exists
          final partialFile = File(newFilePath);
          if (await partialFile.exists()) {
            await partialFile.delete();
          }
          dio.close(force: true);
          throw Exception('download_cancelled');
        }
        // ignore: avoid_print
        print('Download from link failed: $link - $e');
        continue;
      } catch (e) {
        lastDownloadError = e;
        // ignore: avoid_print
        print('Download from link failed: $link - $e');
        continue;
      }
    }
    dio.close(force: true);

    ref.read(downloadNotifierProvider.notifier).finish(book.id);

    if (!success) {
      final partialFile = File(newFilePath);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      throw Exception(
        'Failed to download a valid book from the available links: '
        '$lastDownloadError',
      );
    }

    // Extract cover and metadata dynamically like import
    String author = book.author;
    String? coverPath;
    int pageCount = 0;
    int fileSizeBytes = await File(newFilePath).length();

    final parsed = downloadedEpub;
    if (parsed != null) {
      if (author.isEmpty) {
        author = parsed.author;
      }
      final totalChars = parsed.chapters.fold<int>(
        0,
        (sum, c) =>
            sum + c.htmlContent.replaceAll(RegExp(r'<[^>]*>'), '').length,
      );
      pageCount = (totalChars / 1800).ceil().clamp(1, 999999);
      final coverImage = parsed.coverImage;
      if (coverImage != null) {
        try {
          final coversDir = Directory(p.join(appDocDir.path, 'covers'));
          await coversDir.create(recursive: true);
          final path = p.join(coversDir.path, '$bookId.jpg');
          await File(path).writeAsBytes(coverImage);
          coverPath = path;
        } catch (e) {
          print('Error saving EPUB cover: $e');
        }
      }
    }
    final doc = downloadedPdf;
    if (doc != null) {
      try {
        pageCount = doc.pages.length;
        if (doc.pages.isNotEmpty) {
          final page = doc.pages.first;
          final pdfImage = await page.render(
            fullWidth: 300,
            fullHeight: (300 * page.height / page.width).roundToDouble(),
          );
          if (pdfImage != null) {
            try {
              final pngBytes = await _encodePng(
                pdfImage.pixels,
                pdfImage.width,
                pdfImage.height,
              );
              if (pngBytes != null) {
                final coversDir = Directory(p.join(appDocDir.path, 'covers'));
                await coversDir.create(recursive: true);
                final path = p.join(coversDir.path, '$bookId.png');
                await File(path).writeAsBytes(pngBytes);
                coverPath = path;
              }
            } finally {
              pdfImage.dispose();
            }
          }
        }
      } catch (e) {
        print('Error extracting PDF cover: $e');
      } finally {
        await doc.dispose();
      }
    }

    if ((coverPath == null || coverPath.isEmpty) && book.imgUrl.isNotEmpty) {
      final coversDir = Directory(p.join(appDocDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }
      final fallbackExtension = extension == 'pdf' ? 'png' : 'jpg';
      final fallbackCoverPath = p.join(
        coversDir.path,
        '$bookId.$fallbackExtension',
      );
      final fallbackHeaders = <String, String>{
        if (book.source == SearchResultSource.anna)
          'User-Agent': _desktopUserAgent,
        if (book.source == SearchResultSource.zlibrary &&
            ref.read(zLibraryCredentialsProvider)?.cookies.isNotEmpty == true)
          'Cookie': ref
              .read(zLibraryCredentialsProvider)!
              .cookies
              .entries
              .map((e) => '${e.key}=${e.value}')
              .join('; '),
        if (book.source == SearchResultSource.zlibrary &&
            zLibReferer != null &&
            zLibReferer.isNotEmpty)
          'Referer': zLibReferer,
      };
      final normalizedCoverUrl = _normalizeCoverUrl(book.imgUrl, zLibReferer);
      final downloadedCoverPath = await _downloadCoverToPath(
        normalizedCoverUrl,
        fallbackCoverPath,
        headers: fallbackHeaders,
      );
      if (downloadedCoverPath != null) {
        coverPath = downloadedCoverPath;
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

  Future<String?> _downloadCoverToPath(
    String imageUrl,
    String targetPath, {
    Map<String, String>? headers,
  }) async {
    if (imageUrl.isEmpty) return null;

    try {
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: headers,
        ),
      ).download(imageUrl, targetPath);

      final file = File(targetPath);
      if (await file.exists() && await file.length() > 0) {
        return targetPath;
      }
    } catch (e) {
      print('Error downloading remote cover: $e');
    }

    return null;
  }

  String _normalizeCoverUrl(String imageUrl, String? referer) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('//')) {
      return 'https:$imageUrl';
    }

    final refererUri = referer != null && referer.isNotEmpty
        ? Uri.tryParse(referer)
        : null;
    if (refererUri != null) {
      return refererUri.resolve(imageUrl).toString();
    }

    return imageUrl;
  }

  /// Encode raw BGRA pixels from pdfrx without resampling.
  Future<Uint8List?> _encodePng(Uint8List pixels, int width, int height) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.bgra8888,
        (image) => completer.complete(image),
      );
      final image = await completer.future;
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error encoding PNG: $e');
      return null;
    }
  }
}
