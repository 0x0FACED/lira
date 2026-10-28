import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/domain/providers/books_provider.dart';

void main() {
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
