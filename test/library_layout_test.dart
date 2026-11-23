import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/domain/providers/book_organization_provider.dart';
import 'package:lira/features/books/domain/providers/library_layout_provider.dart';
import 'package:lira/features/books/presentation/book_detail_screen.dart';
import 'package:lira/features/books/presentation/library_screen.dart';
import 'package:lira/features/books/presentation/widgets/book_card.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';
import 'package:lira/features/progress/domain/providers/reading_progress_provider.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void testLibraryWidgets(
  String description,
  WidgetTesterCallback body, {
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Drain Drift's zero-delay stream cleanup inside the test clock.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }
  }, variant: variant);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory coverDirectory;
  late String coverPath;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
    coverDirectory = await Directory.systemTemp.createTemp(
      'lira-library-cover-',
    );
    coverPath = '${coverDirectory.path}/cover.png';
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 12);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    await File(coverPath).writeAsBytes(bytes!.buffer.asUint8List());
  });

  tearDownAll(() async {
    await coverDirectory.delete(recursive: true);
  });

  setUp(() async {
    await sharedPrefs.clear();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = BooksLocalRepository(database);
    getIt.registerSingleton<BooksLocalRepository>(repository);
    getIt.registerSingleton<ReadingProgressLocalRepository>(
      ReadingProgressLocalRepository(database),
    );
    addTearDown(() async {
      await getIt.reset();
      await database.close();
    });
    for (var i = 0; i < 8; i++) {
      await repository.saveBook(
        BookDto(
          id: '$i',
          title: i == 1 ? 'Короткая книга' : 'Книга с длинным названием $i',
          author: i == 1 ? 'Автор' : 'Автор с очень длинной фамилией и именем',
          format: i.isEven ? 'epub' : 'pdf',
          coverUrl: i == 0
              ? coverPath
              : i == 2
              ? '${coverDirectory.path}/missing.png'
              : null,
          pageCount: i == 2
              ? 0
              : i == 3
              ? 9999
              : 1234,
          createdAt: DateTime(2026),
        ),
      );
    }
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool dark = false,
    Locale locale = const Locale('ru'),
    Widget home = const LibraryScreen(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectColumns(WidgetTester tester, int columns) {
    final cards = find.byType(BookCard);
    final firstRowY = tester.getTopLeft(cards.first).dy;
    final row = cards.evaluate().where((element) {
      final box = element.renderObject! as RenderBox;
      return (box.localToGlobal(Offset.zero).dy - firstRowY).abs() < 0.01;
    });
    expect(row.length, columns);
  }

  testLibraryWidgets(
    'saved progress belongs to its book and does not round up completion',
    (tester) async {
      final repository = getIt<ReadingProgressLocalRepository>();
      for (final (id, percentage) in [
        ('0', 42.79),
        ('1', 99.99),
        ('2', 100.0),
      ]) {
        await repository.saveProgress(
          ReadingProgressDto(
            bookId: id,
            percentage: percentage,
            location: 'saved-$id',
            updatedAt: DateTime(2026),
          ),
        );
      }
      await mount(tester);
      Finder progressFor(String id, String text) => find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.text(text),
      );
      expect(progressFor('0', '42,7%'), findsOneWidget);
      expect(progressFor('1', '99,9%'), findsOneWidget);
      expect(progressFor('2', '100,0%'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('3')),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
      );

      final context = tester.element(find.byType(LibraryScreen));
      final container = ProviderScope.containerOf(context);
      final controller = container.read(
        readingProgressControllerProvider('0').notifier,
      );
      await tester.runAsync(() async {
        await controller.saveProgress(location: 'finished', percentage: 100);
        await controller.flush();
      });
      await tester.pumpAndSettle();
      expect(progressFor('0', '100,0%'), findsOneWidget);
      expect(progressFor('1', '99,9%'), findsOneWidget);
      await mount(tester, locale: const Locale('en'));
      expect(progressFor('0', '100.0%'), findsOneWidget);
      expect(progressFor('1', '99.9%'), findsOneWidget);
    },
  );

  testLibraryWidgets('details use binary file sizes at unit boundaries', (
    tester,
  ) async {
    for (final (bytes, expected) in [
      (1024, '1.0 KiB'),
      (1024 * 1024, '1.0 MiB'),
      (100 * 1024 * 1024, '100.0 MiB'),
    ]) {
      await mount(
        tester,
        locale: const Locale('en'),
        home: BookDetailScreen(
          book: BookDto(
            id: 'size-$bytes',
            title: 'File size',
            author: '',
            format: 'epub',
            fileSizeBytes: bytes,
            createdAt: DateTime(2026),
          ),
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testLibraryWidgets(
    'editing absent and legacy authors preserves an empty value',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final repository = getIt<BooksLocalRepository>();
        for (final author in ['', 'Unknown Author', 'Original author']) {
          final book = BookDto(
            id: 'edit-author',
            title: 'Book without author',
            author: author,
            format: 'epub',
            createdAt: DateTime(2026),
          );
          await repository.saveBook(book);
          await mount(tester, home: BookDetailScreen(book: book));
          final context = tester.element(find.byType(BookDetailScreen));
          final l10n = AppLocalizations.of(context)!;
          final edit = find.bySemanticsLabel(l10n.editBook);
          expect(edit, findsOneWidget);
          await tester.tap(edit);
          await tester.pumpAndSettle();
          final authorField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == l10n.editBookAuthor,
          );
          if (author == 'Original author') {
            await tester.enterText(authorField, '');
          } else {
            expect(
              tester.widget<TextField>(authorField).controller!.text,
              isEmpty,
            );
          }
          await tester.tap(find.widgetWithText(FilledButton, l10n.save));
          await tester.pumpAndSettle();
          expect((await repository.getBookById(book.id))!.author, isEmpty);
          expect(find.text(l10n.bookAuthorUnknown), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final details in [false, true]) {
    testLibraryWidgets(
      'long ${details ? 'details' : 'library'} deletion can scroll and cancel',
      (tester) async {
        final repository = getIt<BooksLocalRepository>();
        final book = (await repository.getBookById('0'))!.copyWith(
          title: List.filled(80, 'Очень длинное название книги').join(' '),
        );
        await repository.updateBook(book);
        await mount(
          tester,
          size: const Size(360, 500),
          textScale: 2,
          home: details ? BookDetailScreen(book: book) : const LibraryScreen(),
        );
        final context = tester.element(
          find.byType(details ? BookDetailScreen : LibraryScreen),
        );
        final l10n = AppLocalizations.of(context)!;
        if (details) {
          await tester.tap(find.byType(PopupMenuButton<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.deleteBook));
        } else {
          final card = find.byKey(const ValueKey('0'));
          await tester.longPressAt(
            tester.getTopLeft(card) + const Offset(2, 24),
          );
        }
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        final scrollable = find.descendant(
          of: dialog,
          matching: find.byType(Scrollable),
        );
        final scroll = tester.state<ScrollableState>(scrollable);
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0));
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(await repository.getBookById(book.id), isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testLibraryWidgets('density changes preserve search and survive reopening', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'длинным');
    await tester.pumpAndSettle();
    for (final columns in [3, 2, 3]) {
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<int>, '$columns книги в ряд'),
      );
      await tester.pumpAndSettle();
      expectColumns(tester, columns);
      expect(find.text('длинным'), findsOneWidget);
      expect(find.byKey(const ValueKey('1')), findsNothing);
      expect(find.byKey(const ValueKey('2')), findsOneWidget);
    }
    await sharedPrefs.reload();
    await mount(tester);
    expectColumns(tester, 3);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final columns in [2, 3]) {
      for (final textScale in [0.8, 1.0, 2.0]) {
        testLibraryWidgets(
          '$columns columns fit width $width at text scale $textScale',
          (tester) async {
            await sharedPrefs.setInt(
              LibraryColumnsNotifier.storageKey,
              columns,
            );
            await mount(
              tester,
              size: Size(width, 844),
              textScale: textScale,
              dark: true,
            );
            expectColumns(tester, columns);
            expect(tester.takeException(), isNull);

            final cards = find.byType(BookCard).evaluate().take(3).toList();
            final coverSizes = <Size>[];
            final titleOffsets = <double>[];
            for (final element in cards) {
              final card = find.byWidget(element.widget);
              final book = (element.widget as BookCard).book;
              final cover = find.descendant(
                of: card,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics && widget.properties.image == true,
                ),
              );
              final title = find
                  .descendant(of: card, matching: find.text(book.title))
                  .last;
              coverSizes.add(tester.getSize(cover));
              titleOffsets.add(
                tester.getTopLeft(title).dy - tester.getTopLeft(card).dy,
              );
            }
            expect(coverSizes, everyElement(coverSizes.first));
            for (final offset in titleOffsets) {
              expect(offset, closeTo(titleOffsets.first, 0.01));
            }
          },
        );
      }
    }
  }

  testLibraryWidgets('page count fits a dense row at large text scale', (
    tester,
  ) async {
    await sharedPrefs.setInt(LibraryColumnsNotifier.storageKey, 3);
    await mount(tester, size: const Size(320, 844), textScale: 2);
    final card = find.byKey(const ValueKey('3'));
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final pages = find.descendant(of: card, matching: find.text('9999'));
    expect(pages, findsOneWidget);
    final countRect = tester.getRect(pages);
    final cardRect = tester.getRect(card);
    expect(countRect.left, greaterThanOrEqualTo(cardRect.left));
    expect(countRect.right, lessThanOrEqualTo(cardRect.right));
    expect(countRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testLibraryWidgets('long press still requires confirmation before deleting', (
    tester,
  ) async {
    await mount(tester);
    final card = find.byKey(const ValueKey('0'));
    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);

    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testLibraryWidgets(
    'sort and shelf use saved progress and persist the sort order',
    (tester) async {
      final progress = getIt<ReadingProgressLocalRepository>();
      for (final (id, percent) in [('4', 30.0), ('3', 100.0), ('2', 70.0)]) {
        await progress.saveProgress(
          ReadingProgressDto(
            bookId: id,
            location: 'test',
            percentage: percent,
            updatedAt: DateTime(2026),
          ),
        );
      }
      await mount(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LibraryScreen)),
      )!;
      await tester.tap(find.byType(PopupMenuButton<LibrarySort>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<LibrarySort>,
          l10n.librarySortProgress,
        ),
      );
      await tester.pumpAndSettle();
      String firstBook() =>
          tester.widget<BookCard>(find.byType(BookCard).first).book.id;
      expect(firstBook(), '3');
      await tester.tap(find.text(l10n.libraryInProgress));
      await tester.pumpAndSettle();
      expect(firstBook(), '2');
      expect(find.byKey(const ValueKey('4')), findsOneWidget);
      expect(find.byKey(const ValueKey('3')), findsNothing);
      expect(find.byKey(const ValueKey('0')), findsNothing);

      await mount(tester);
      expect(firstBook(), '3');
      await tester.tap(find.byType(PopupMenuButton<LibrarySort>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<LibrarySort>,
          l10n.librarySortTitle,
        ),
      );
      await tester.pumpAndSettle();
      expect(firstBook(), '0'); // «Книга…» sorts before «Короткая…».
    },
  );

  testLibraryWidgets('saved tags filter the list and compose with search', (
    tester,
  ) async {
    final labels = BookOrganizationsNotifier(sharedPrefs);
    addTearDown(labels.dispose);
    await labels.setLabels(
      '0',
      const BookOrganization(genres: ['Экономика'], tags: ['К обсуждению']),
    );
    await labels.setLabels('1', const BookOrganization(tags: ['к обсуждению']));
    await mount(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryScreen)),
    )!;
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<int>, l10n.libraryListView),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.filter_list_rounded),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('К обсуждению'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('0')), findsOneWidget);
    expect(find.byKey(const ValueKey('1')), findsOneWidget);
    expect(find.byKey(const ValueKey('2')), findsNothing);
    await tester.enterText(find.byType(TextField), 'КОРОТКАЯ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('0')), findsNothing);
    expect(find.byKey(const ValueKey('1')), findsOneWidget);
  });

  testLibraryWidgets(
    'card hit area includes the left edge for mouse and touch',
    (tester) async {
      await mount(tester);
      final card = find.byKey(const ValueKey('0'));
      final edge = tester.getTopLeft(card) + const Offset(2, 24);
      final mouse = await tester.startGesture(
        edge,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
      await tester.pumpAndSettle();
      await tester.longPressAt(edge);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testLibraryWidgets(
    'iPhone landscape keeps the selected three columns',
    (tester) async {
      await sharedPrefs.setInt(LibraryColumnsNotifier.storageKey, 3);
      await mount(
        tester,
        size: const Size(844, 390),
        locale: const Locale('en'),
      );
      expectColumns(tester, 3);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testLibraryWidgets('tablet retains the automatic grid', (tester) async {
    await sharedPrefs.setInt(LibraryColumnsNotifier.storageKey, 3);
    await mount(tester, size: const Size(800, 1200));
    expect(find.byType(PopupMenuButton<int>), findsNothing);
    expectColumns(tester, 4);
    expect(tester.takeException(), isNull);
  });

  testLibraryWidgets(
    'narrow desktop retains the automatic grid',
    (tester) async {
      await sharedPrefs.setInt(LibraryColumnsNotifier.storageKey, 3);
      await mount(tester);
      expect(find.byType(PopupMenuButton<int>), findsNothing);
      expectColumns(tester, 2);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
