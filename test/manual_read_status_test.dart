import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/domain/providers/book_organization_provider.dart';
import 'package:lira/features/books/domain/providers/books_provider.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';
import 'package:lira/features/progress/domain/providers/manual_read_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('book removal clears a mark only after successful deletion', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final marks = ManualReadStatusNotifier(prefs);
    final organizations = BookOrganizationsNotifier(prefs);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final books = BooksLocalRepository(database);
    getIt.registerSingleton<BooksLocalRepository>(books);
    addTearDown(getIt.reset);
    final container = ProviderContainer(
      overrides: [
        manuallyReadBookIdsProvider.overrideWith((ref) => marks),
        bookOrganizationsProvider.overrideWith((ref) => organizations),
      ],
    );
    addTearDown(container.dispose);
    for (final id in ['deleted', 'kept']) {
      await books.saveBook(
        BookDto(
          id: id,
          title: id,
          author: 'Reader',
          format: 'epub',
          createdAt: DateTime.utc(2026, 11, 26),
        ),
      );
      await marks.setRead(id, true);
    }
    await database.customStatement(
      "CREATE TRIGGER reject_removal BEFORE DELETE ON books "
      "WHEN OLD.id = 'kept' BEGIN SELECT RAISE(ABORT, 'Cannot delete'); END;",
    );
    await container.read(booksControllerProvider.future);
    final controller = container.read(booksControllerProvider.notifier);

    await controller.removeBook('deleted');
    expect(await books.getBookById('deleted'), isNull);
    expect(marks.state, {'kept'});

    await expectLater(controller.removeBook('kept'), throwsException);
    expect(await books.getBookById('kept'), isNotNull);
    expect(marks.state, {'kept'});
    expect(
      container.read(booksControllerProvider).requireValue.single.id,
      'kept',
    );
    await prefs.reload();
    final reopened = ManualReadStatusNotifier(prefs);
    addTearDown(reopened.dispose);
    expect(reopened.state, {'kept'});
  });

  test('manual status is reactive, immutable and survives reopening', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = ManualReadStatusNotifier(prefs);
    final container = ProviderContainer(
      overrides: [manuallyReadBookIdsProvider.overrideWith((ref) => notifier)],
    );
    addTearDown(container.dispose);
    final changes = <bool>[];
    container.listen(
      isBookManuallyReadProvider('book/one:эпос'),
      (_, next) => changes.add(next),
      fireImmediately: true,
    );

    await notifier.setRead('book/one:эпос', true);
    expect(container.read(isBookManuallyReadProvider('book/one:эпос')), isTrue);
    expect(() => notifier.state.clear(), throwsUnsupportedError);

    await prefs.reload();
    final reopened = ManualReadStatusNotifier(prefs);
    addTearDown(reopened.dispose);
    expect(reopened.state, {'book/one:эпос'});

    await notifier.setRead('book/one:эпос', false);
    expect(
      container.read(isBookManuallyReadProvider('book/one:эпос')),
      isFalse,
    );
    expect(changes, [false, true, false]);
    await prefs.reload();
    final unmarked = ManualReadStatusNotifier(prefs);
    addTearDown(unmarked.dispose);
    expect(unmarked.state, isEmpty);
    expect(prefs.containsKey(ManualReadStatusNotifier.storageKey), isFalse);
  });

  test('overlapping marks and removals preserve the latest statuses', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = ManualReadStatusNotifier(prefs);
    addTearDown(notifier.dispose);

    final writes = [
      notifier.setRead('one', true),
      notifier.setRead('two', true),
      notifier.setRead('one', false),
      notifier.setRead('two', false),
      notifier.setRead('two', true),
    ];
    expect(notifier.state, isEmpty);
    await Future.wait(writes);

    expect(notifier.state, {'two'});
    await prefs.reload();
    final reopened = ManualReadStatusNotifier(prefs);
    addTearDown(reopened.dispose);
    expect(reopened.state, {'two'});
  });

  test('invalid stored status can be replaced with a valid mark', () async {
    SharedPreferences.setMockInitialValues({
      ManualReadStatusNotifier.storageKey: 'not a list of book IDs',
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = ManualReadStatusNotifier(prefs);
    addTearDown(notifier.dispose);
    expect(notifier.state, isEmpty);

    await notifier.setRead('book', true);
    await prefs.reload();
    final reopened = ManualReadStatusNotifier(prefs);
    addTearDown(reopened.dispose);
    expect(reopened.state, {'book'});
  });

  test(
    'marking and unmarking never create or rewrite progress, including after restart',
    () async {
      void expectProgress(
        ReadingProgressDto? actual,
        ReadingProgressDto expected,
      ) {
        expect(actual, isNotNull);
        expect(actual!.bookId, expected.bookId);
        expect(actual.percentage, expected.percentage);
        expect(actual.location, expected.location);
        expect(actual.updatedAt.isAtSameMomentAs(expected.updatedAt), isTrue);
      }

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final marks = ManualReadStatusNotifier(prefs);
      addTearDown(marks.dispose);
      final directory = await Directory.systemTemp.createTemp(
        'lira-manual-read-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() => database.close());
      final books = BooksLocalRepository(database);
      final createdAt = DateTime.utc(2026, 11, 26);
      for (final id in ['started', 'unopened', 'completed']) {
        await books.saveBook(
          BookDto(
            id: id,
            title: id,
            author: 'Reader',
            format: 'epub',
            createdAt: createdAt,
          ),
        );
      }
      final progress = ReadingProgressLocalRepository(database);
      final original = ReadingProgressDto(
        bookId: 'started',
        percentage: 37.25,
        location: 'epubcfi(/6/24!/4/8:99)',
        updatedAt: createdAt,
      );
      final completed = original.copyWith(
        bookId: 'completed',
        percentage: 100,
        location: 'epubcfi(/6/40!/4/2:12)',
      );
      await progress.saveProgress(original);
      await progress.saveProgress(completed);
      final revisionsBefore = await database
          .select(database.syncRevisions)
          .get();

      for (final id in ['started', 'unopened', 'completed']) {
        await marks.setRead(id, true);
      }
      expectProgress(await progress.getProgress('started'), original);
      expect(await progress.getProgress('unopened'), isNull);
      expectProgress(await progress.getProgress('completed'), completed);
      expect(
        await database.select(database.syncRevisions).get(),
        revisionsBefore,
      );

      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      await prefs.reload();
      final reopenedMarks = ManualReadStatusNotifier(prefs);
      addTearDown(reopenedMarks.dispose);
      final reopenedProgress = ReadingProgressLocalRepository(database);
      expect(reopenedMarks.state, {'started', 'unopened', 'completed'});
      expectProgress(await reopenedProgress.getProgress('started'), original);
      expect(await reopenedProgress.getProgress('unopened'), isNull);

      final nextPosition = original.copyWith(
        percentage: 42.5,
        location: 'epubcfi(/6/26!/4/2:7)',
        updatedAt: createdAt.add(const Duration(minutes: 10)),
      );
      await reopenedProgress.saveProgress(nextPosition);
      expectProgress(
        await reopenedProgress.getProgress('started'),
        nextPosition,
      );
      expect(reopenedMarks.state.contains('started'), isTrue);
      final revisionsAfterReading = await database
          .select(database.syncRevisions)
          .get();

      for (final id in ['started', 'unopened', 'completed']) {
        await reopenedMarks.setRead(id, false);
      }
      expectProgress(
        await reopenedProgress.getProgress('started'),
        nextPosition,
      );
      expect(await reopenedProgress.getProgress('unopened'), isNull);
      expectProgress(
        await reopenedProgress.getProgress('completed'),
        completed,
      );
      expect(
        await database.select(database.syncRevisions).get(),
        revisionsAfterReading,
      );

      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      await prefs.reload();
      final unmarked = ManualReadStatusNotifier(prefs);
      addTearDown(unmarked.dispose);
      expect(unmarked.state, isEmpty);
      final finalProgress = ReadingProgressLocalRepository(database);
      expectProgress(await finalProgress.getProgress('started'), nextPosition);
      expect(await finalProgress.getProgress('unopened'), isNull);
      expectProgress(await finalProgress.getProgress('completed'), completed);
    },
  );
}
