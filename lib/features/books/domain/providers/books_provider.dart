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
import '../../../progress/domain/providers/manual_read_status_provider.dart';
import '../../../search/domain/providers/book_source_clients.dart';
import '../../../search/domain/models/search_result_item.dart';
import '../models/book_dto.dart';
import '../../data/open_library_client.dart';
import '../../data/open_library_covers.dart';
import '../../data/repositories/books_local_repository.dart';
import '../../../search/domain/providers/download_provider.dart';
import '../open_library_genres.dart';
import 'book_organization_provider.dart';
import 'open_library_preferences.dart';
import 'open_library_provider.dart';

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

    var title = p.basenameWithoutExtension(file.path);

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
    String author = '';
    String? isbn;
    var usedFilename = true;
    String? coverPath;
    int pageCount = 0;
    int fileSizeBytes = await File(file.path).length();

    if (extension == 'epub') {
      try {
        final bytes = await File(newFilePath).readAsBytes();
        final parsed = await EpubParser.parse(bytes);
        author = _authorMetadata(parsed.author);
        final embeddedTitle = parsed.title.trim();
        if (embeddedTitle.isNotEmpty && embeddedTitle != 'Unknown Title') {
          title = embeddedTitle;
          usedFilename = false;
        }
        isbn = _singleIsbn(parsed.identifiers);

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
            final path = p.join(coversDir.path, '$bookId.png');
            // Encode RGBA pixels to PNG
            final pngBytes = await _encodePng(
              pdfImage.pixels,
              pdfImage.width,
              pdfImage.height,
            );
            if (pngBytes != null) {
              await File(path).writeAsBytes(pngBytes);
              coverPath = path;
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
    if (isbn != null) {
      unawaited(_autoEnrich(newBook, isbn, replaceFilename: usedFilename));
    }
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
    String author = _authorMetadata(book.author);
    String? coverPath;
    int pageCount = 0;
    int fileSizeBytes = await File(newFilePath).length();

    final parsed = downloadedEpub;
    if (parsed != null) {
      if (author.isEmpty) {
        author = _authorMetadata(parsed.author);
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
    state = AsyncData([...(state.value ?? []), newBook]);
    final isbn = parsed == null ? null : _singleIsbn(parsed.identifiers);
    if (isbn != null) unawaited(_autoEnrich(newBook, isbn));
  }

  String _authorMetadata(String value) {
    final author = value.trim();
    return author == 'Unknown Author' ? '' : author;
  }

  Future<({String? isbn, String? language})> openLibraryHints(
    BookDto book,
  ) async {
    final path = book.fileUrl;
    if (book.format == 'epub' && path != null && path.isNotEmpty) {
      try {
        final metadata = await EpubParser.readBibliographicMetadata(
          await File(path).readAsBytes(),
        );
        final language = metadata.language.trim();
        return (
          isbn: _singleIsbn(metadata.identifiers),
          language: language.isEmpty ? null : language,
        );
      } on Exception {
        // An unreadable local file does not prevent manual search.
      }
    }
    return (isbn: null, language: null);
  }

  String? _singleIsbn(Iterable<String> identifiers) {
    String? result;
    for (final identifier in identifiers) {
      final isbn = normalizeIsbn(identifier);
      if (isbn == null) continue;
      if (result != null && result != isbn) return null;
      result = isbn;
    }
    return result;
  }

  Future<void> _autoEnrich(
    BookDto expected,
    String isbn, {
    bool replaceFilename = false,
  }) async {
    try {
      if (!ref.read(openLibraryAutoProvider)) return;
      final client = ref.read(openLibraryClientProvider);
      final matches = await client.search(isbn: isbn);
      if (matches.length != 1) return;
      final candidate = matches.single;
      if (candidate.editionKey == null || !candidate.isbns.contains(isbn)) {
        return;
      }
      final cover = await findAutomaticOpenLibraryCover(
        client,
        candidate,
        expected.coverUrl,
      );
      await _applyOpenLibraryMetadata(
        expected,
        candidate,
        title: replaceFilename,
        author: _authorMetadata(expected.author).isEmpty,
        genres: true,
        cover: cover,
        automatic: true,
      );
    } on Exception {
      // Optional background enrichment never makes a local import fail.
    } on StateError {
      // The book changed or the controller was disposed while looking it up.
    }
  }

  Future<void> applyOpenLibraryMetadata(
    BookDto expected,
    OpenLibraryCandidate candidate, {
    required bool title,
    required bool author,
    required bool genres,
    OpenLibraryCover? cover,
  }) => _applyOpenLibraryMetadata(
    expected,
    candidate,
    title: title,
    author: author,
    genres: genres,
    cover: cover,
  );

  Future<void> _applyOpenLibraryMetadata(
    BookDto expected,
    OpenLibraryCandidate candidate, {
    required bool title,
    required bool author,
    required bool genres,
    OpenLibraryCover? cover,
    bool automatic = false,
  }) async {
    if (automatic && !ref.read(openLibraryAutoProvider)) return;
    final authorName = candidate.author;
    final additions = genres
        ? openLibraryGenres(
            candidate.subjects,
            russian: ref.read(localeProvider).languageCode == 'ru',
          )
        : const <String>[];
    File? newCover;
    BookDto? updated;
    try {
      if (cover != null) {
        newCover = await newOpenLibraryCoverFile(expected.id);
        await newCover.writeAsBytes(cover.bytes);
      }
      if (automatic && !ref.read(openLibraryAutoProvider)) return;
      updated = await _repository.applyCatalogMetadata(
        expected,
        title: title && candidate.title.isNotEmpty ? candidate.title : null,
        author: author && authorName.isNotEmpty ? authorName : null,
        coverUrl: newCover?.path,
      );
      if (updated == null) throw StateError('Book changed since lookup');
    } finally {
      if (updated == null && newCover != null) {
        await deleteOpenLibraryCover(expected.id, newCover.path);
      }
    }

    final currentBooks = state.value;
    if (currentBooks != null) {
      state = AsyncData([
        for (final book in currentBooks)
          if (book.id == updated.id) updated else book,
      ]);
    }
    if (newCover != null) {
      unawaited(deleteOpenLibraryCover(expected.id, expected.coverUrl));
    }
    if (additions.isNotEmpty) {
      final organizations = ref.read(bookOrganizationsProvider.notifier);
      final organization = ref.read(bookOrganizationProvider(expected.id));
      if (!automatic || organization.genres.isEmpty) {
        final merged = mergeOpenLibraryGenres(organization.genres, additions);
        if (merged.length != organization.genres.length) {
          await organizations.setLabels(
            expected.id,
            BookOrganization(genres: merged, tags: organization.tags),
          );
        }
      }
    }
  }

  Future<void> updateBook(BookDto updatedBook) async {
    await _repository.updateBook(updatedBook);

    // Update local state by replacing the old book
    final currentBooks = state.value ?? [];
    state = AsyncData([
      for (final book in currentBooks)
        if (book.id == updatedBook.id)
          book.copyWith(title: updatedBook.title, author: updatedBook.author)
        else
          book,
    ]);
  }

  Future<void> removeBook(String id) async {
    final organizations = ref.read(bookOrganizationsProvider.notifier);
    final manualReadStatus = ref.read(manuallyReadBookIdsProvider.notifier);
    final book = await _repository.getBookById(id);
    await _repository.deleteBook(id);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAllBooks());
    await organizations.removeLabels(id);
    await deleteOpenLibraryCover(id, book?.coverUrl);
    await manualReadStatus.setRead(id, false);
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
