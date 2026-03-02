import 'dart:async';
import 'dart:io';
import 'package:epub_engine/epub_engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../models/book_dto.dart';
import '../../data/repositories/books_local_repository.dart';

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

    if (extension == 'epub') {
      try {
        final bytes = await File(newFilePath).readAsBytes();
        final parsed = await EpubParser.parse(bytes);
        author = parsed.author;

        if (parsed.coverImage != null) {
          final coversDir = Directory(p.join(appDocDir.path, 'covers'));
          if (!await coversDir.exists()) {
            await coversDir.create(recursive: true);
          }
          coverPath = p.join(coversDir.path, '$bookId.jpg');
          await File(coverPath).writeAsBytes(parsed.coverImage!);
        }
      } catch (_) {
        // Couldn't extract metadata, use defaults
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
    );

    await _repository.saveBook(newBook);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAllBooks());
  }

  Future<void> removeBook(String id) async {
    await _repository.deleteBook(id);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAllBooks());
  }
}
