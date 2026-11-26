import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/core/theme/app_tokens.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/domain/providers/book_organization_provider.dart';
import 'package:lira/features/books/domain/providers/library_layout_provider.dart';
import 'package:lira/features/books/presentation/book_detail_screen.dart';
import 'package:lira/features/books/presentation/book_export.dart';
import 'package:lira/features/books/presentation/library_screen.dart';
import 'package:lira/features/books/presentation/open_library_dialog.dart';
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
        matching: find.textContaining(RegExp('${RegExp.escape(text)}\$')),
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
      expect(find.textContaining(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testLibraryWidgets('details actions share the capped page width', (
    tester,
  ) async {
    final book = (await getIt<BooksLocalRepository>().getBookById('1'))!;
    for (final size in [const Size(500, 980), const Size(1440, 860)]) {
      await mount(
        tester,
        size: size,
        home: BookDetailScreen(book: book),
      );
      final context = tester.element(find.byType(BookDetailScreen));
      final gutter = AppLayout.pageGutter(context);
      final l10n = AppLocalizations.of(context)!;
      final read = tester.getRect(
        find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      final progress = tester.getRect(find.byType(LinearProgressIndicator));
      final lookup = tester.getRect(find.byTooltip(l10n.openLibraryFind));
      final edit = tester.getRect(find.byTooltip(l10n.editBook));
      final share = tester.getRect(
        find.byTooltip(
          bookFileClipboardAvailable
              ? l10n.bookExportMenu
              : bookExportActionLabel(context),
        ),
      );
      final delete = tester.getRect(
        find.widgetWithText(TextButton, l10n.deleteBook),
      );
      final pageWidth = size.width.clamp(0.0, AppLayout.contentMaxWidth);
      expect(read.width, pageWidth - 2 * gutter);
      expect(read.center.dx, size.width / 2);
      expect(progress.left, read.left);
      expect(progress.right, read.right);
      expect(lookup.center.dy, edit.center.dy);
      expect(lookup.right, lessThanOrEqualTo(edit.left));
      expect(edit.right, lessThanOrEqualTo(share.left));
      expect(share.right, lessThanOrEqualTo(read.right));
      expect(delete.left, read.left);
      expect(delete.width, lessThan(read.width));
      expect(delete.top, greaterThan(progress.bottom));
    }
  });

  testLibraryWidgets(
    'details heading stays readable and lookup opens at large text scale',
    (tester) async {
      final book = (await getIt<BooksLocalRepository>().getBookById('1'))!;
      for (final locale in [const Locale('en'), const Locale('ru')]) {
        await mount(
          tester,
          size: const Size(360, 660),
          textScale: 1.5,
          locale: locale,
          home: BookDetailScreen(book: book),
        );
        final context = tester.element(find.byType(BookDetailScreen));
        final l10n = AppLocalizations.of(context)!;
        final heading = tester.renderObject<RenderParagraph>(
          find.text(l10n.library),
        );
        expect(heading.didExceedMaxLines, isFalse);
        await tester.tap(find.byTooltip(l10n.openLibraryFind));
        await tester.pumpAndSettle();
        expect(find.byType(OpenLibraryDialog), findsOneWidget);
        expect(find.widgetWithText(TextField, book.title), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(OpenLibraryDialog), findsNothing);
      }
    },
  );

  testLibraryWidgets(
    'details deletion requires confirmation and keeps the source file',
    (tester) async {
      final repository = getIt<BooksLocalRepository>();
      final progressRepository = getIt<ReadingProgressLocalRepository>();
      final book = (await repository.getBookById(
        '1',
      ))!.copyWith(fileUrl: coverPath);
      await tester.runAsync(() => repository.saveBook(book));
      await progressRepository.saveProgress(
        ReadingProgressDto(
          bookId: book.id,
          percentage: 25,
          location: 'saved-location',
          updatedAt: DateTime(2026),
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: Text('Library after deletion')),
          ),
          GoRoute(
            path: '/book',
            builder: (_, _) => BookDetailScreen(book: book),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push<void>('/book');
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BookDetailScreen));
      final container = ProviderScope.containerOf(context);
      final l10n = AppLocalizations.of(context)!;
      await container
          .read(bookOrganizationsProvider.notifier)
          .setLabels(
            book.id,
            const BookOrganization(genres: ['Fiction'], tags: ['Favorite']),
          );
      await tester.pumpAndSettle();
      final delete = find.widgetWithText(TextButton, l10n.deleteBook);
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text(l10n.bookDeleteWarning(book.title)), findsOneWidget);
      expect(await repository.getBookById(book.id), isNotNull);
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      expect(await repository.getBookById(book.id), isNotNull);
      expect(await progressRepository.getProgress(book.id), isNotNull);
      expect(container.read(bookOrganizationProvider(book.id)).tags, [
        'Favorite',
      ]);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, l10n.delete));
      await tester.pumpAndSettle();
      expect(find.byType(BookDetailScreen), findsNothing);
      expect(find.text('Library after deletion'), findsOneWidget);
      expect(await repository.getBookById(book.id), isNull);
      expect(await progressRepository.getProgress(book.id), isNull);
      expect(container.read(bookOrganizationProvider(book.id)).tags, isEmpty);
      expect(File(coverPath).existsSync(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testLibraryWidgets(
    'inline editing saves metadata and an unconfirmed genre, and cancel restores it',
    (tester) async {
      final repository = getIt<BooksLocalRepository>();
      final book = (await repository.getBookById('1'))!;
      await mount(
        tester,
        size: const Size(360, 660),
        textScale: 1.5,
        home: BookDetailScreen(book: book),
      );
      final context = tester.element(find.byType(BookDetailScreen));
      final l10n = AppLocalizations.of(context)!;
      final container = ProviderScope.containerOf(context);
      const draftGenre = 'Научная фантастика';
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      Finder control(String group, String key) => find.descendant(
        of: find.byKey(ValueKey(group)),
        matching: find.byKey(ValueKey(key)),
      );
      Future<void> tapVisible(Finder target) async {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await container
          .read(bookOrganizationsProvider.notifier)
          .setLabels(
            book.id,
            const BookOrganization(genres: ['Проза'], tags: ['Избранное']),
          );
      await tester.pumpAndSettle();
      await tapVisible(find.byTooltip(l10n.editBook));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.textContaining('${l10n.added}:'), findsOneWidget);

      await tester.ensureVisible(field(l10n.editBookTitle));
      await tester.enterText(field(l10n.editBookTitle), 'Новое название');
      await tester.ensureVisible(field(l10n.editBookAuthor));
      await tester.enterText(field(l10n.editBookAuthor), 'Новый автор');

      final add = find.byTooltip(l10n.bookAddGenre);
      await tapVisible(add);
      final editor = control('book-genres', 'inline-label-editor');
      final chip = control('book-genres', 'inline-label-editor-chip');
      await tester.ensureVisible(editor);
      final emptyWidth = tester.getSize(chip).width;
      final input = tester
          .state<EditableTextState>(
            find.descendant(of: editor, matching: find.byType(EditableText)),
          )
          .renderEditable;
      final caret = input.localToGlobal(
        input.getLocalRectForCaret(const TextPosition(offset: 0)).center,
      );
      final confirm = control('book-genres', 'inline-label-confirm');
      final cancel = control('book-genres', 'inline-label-cancel');
      expect(caret.dx, closeTo(tester.getCenter(editor).dx, 3));
      expect(caret.dy, closeTo(tester.getCenter(confirm).dy, 3));
      await tester.enterText(editor, 'Космос');
      await tester.pumpAndSettle();
      final shortWidth = tester.getSize(chip).width;
      expect(shortWidth, greaterThan(emptyWidth));
      await tester.enterText(editor, List.filled(12, draftGenre).join(' '));
      await tester.pumpAndSettle();
      final cappedWidth = tester.getSize(chip).width;
      expect(cappedWidth, greaterThan(shortWidth));
      expect(confirm.hitTestable(), findsOneWidget);
      expect(cancel.hitTestable(), findsOneWidget);
      await tester.enterText(editor, 'Космос');
      await tester.pumpAndSettle();
      expect(tester.getSize(chip).width, shortWidth);
      await tester.enterText(editor, '  $draftGenre  ');
      await tester.pumpAndSettle();
      expect(container.read(bookOrganizationProvider(book.id)).genres, [
        'Проза',
      ]);
      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pumpAndSettle();
      final saved = (await repository.getBookById(book.id))!;
      expect((saved.title, saved.author), ('Новое название', 'Новый автор'));
      final organization = container.read(bookOrganizationProvider(book.id));
      expect(organization.genres, ['Проза', draftGenre]);
      expect(organization.tags, ['Избранное']);
      expect(find.byType(TextField), findsNothing);

      await tapVisible(find.byTooltip(l10n.editBook));
      await tapVisible(find.text(draftGenre));
      await tester.ensureVisible(editor);
      await tester.enterText(editor, 'Не сохранять');
      await tester.tap(find.byTooltip(l10n.cancel).first);
      await tester.pumpAndSettle();
      expect(find.text(draftGenre), findsOneWidget);
      expect(find.text('Не сохранять'), findsNothing);
      expect(container.read(bookOrganizationProvider(book.id)).genres, [
        'Проза',
        draftGenre,
      ]);
    },
  );

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
          final delete = find.widgetWithText(TextButton, l10n.deleteBook);
          await tester.ensureVisible(delete);
          await tester.tap(delete);
        } else {
          final card = find.byKey(const ValueKey('0'));
          await tester.longPressAt(
            tester.getTopLeft(card) + const Offset(2, 24),
          );
          await tester.pumpAndSettle();
          final delete = find.widgetWithText(ListTile, l10n.deleteBook);
          await tester.ensureVisible(delete);
          await tester.tap(delete);
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
      for (final textScale in [0.8, 1.0, 2.0, 2.5]) {
        testLibraryWidgets(
          '$columns columns fit width $width at text scale $textScale',
          (tester) async {
            await sharedPrefs.setInt(
              LibraryColumnsNotifier.storageKey,
              columns,
            );
            for (final id in ['0', '1']) {
              await getIt<ReadingProgressLocalRepository>().saveProgress(
                ReadingProgressDto(
                  bookId: id,
                  percentage: 42.79,
                  location: 'saved-$id',
                  updatedAt: DateTime(2026),
                ),
              );
            }
            await mount(
              tester,
              size: Size(width, 844),
              textScale: textScale,
              dark: true,
            );
            expectColumns(tester, columns);
            expect(tester.takeException(), isNull);

            final l10n = AppLocalizations.of(
              tester.element(find.byType(LibraryScreen)),
            )!;
            final cards = find.byType(BookCard).evaluate().take(3).toList();
            final coverSizes = <Size>[];
            final titleOffsets = <double>[];
            final metadataOffsets = <double>[];
            final progressOffsets = <double>[];
            for (final element in cards) {
              final card = find.byWidget(element.widget);
              final book = (element.widget as BookCard).book;
              final format = book.format.toUpperCase();
              final metadata = find
                  .descendant(of: card, matching: find.text(format))
                  .last;
              expect(metadata, findsOneWidget);
              final metadataRect = tester.getRect(metadata);
              final cardRect = tester.getRect(card);
              expect(metadataRect.left, greaterThanOrEqualTo(cardRect.left));
              expect(metadataRect.right, lessThanOrEqualTo(cardRect.right));
              expect(metadataRect.bottom, lessThanOrEqualTo(cardRect.bottom));
              expect(
                tester
                    .renderObject<RenderParagraph>(metadata)
                    .didExceedMaxLines,
                isFalse,
              );
              final metadataRow = find.descendant(
                of: card,
                matching: find.byKey(const ValueKey('book-card-metadata-row')),
              );
              final rowRect = tester.getRect(metadataRow);
              metadataOffsets.add(rowRect.top - cardRect.top);
              expect(metadataRect.left, closeTo(rowRect.left, 0.01));
              final progressLabel = find.descendant(
                of: card,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label == l10n.libraryReadingProgress,
                ),
              );
              if (book.pageCount > 0 || book.id == '0' || book.id == '1') {
                final labelRect = tester.getRect(progressLabel);
                expect(labelRect.top, closeTo(metadataRect.top, 0.01));
                expect(labelRect.right, closeTo(rowRect.right, 0.01));
                expect(labelRect.left, greaterThan(metadataRect.right));
                expect(
                  labelRect.bottom,
                  lessThanOrEqualTo(rowRect.bottom + 0.01),
                );
                final label = find.descendant(
                  of: progressLabel,
                  matching: find.byKey(
                    const ValueKey('book-card-progress-label'),
                  ),
                );
                expect(tester.widget<Text>(label).maxLines, 1);
                expect(
                  tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
                  isFalse,
                );
              }
              final progress = find.descendant(
                of: card,
                matching: find.byType(LinearProgressIndicator),
              );
              if (book.id == '0' || book.id == '1') {
                expect(progress, findsOneWidget);
                final progressRect = tester.getRect(progress);
                expect(rowRect.bottom, lessThan(progressRect.top));
                expect(progressRect.bottom, lessThanOrEqualTo(cardRect.bottom));
                progressOffsets.add(progressRect.bottom - cardRect.bottom);
              } else {
                expect(progress, findsNothing);
              }
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
            for (final offset in metadataOffsets) {
              expect(offset, closeTo(metadataOffsets.first, 0.01));
            }
            for (final offset in progressOffsets) {
              expect(offset, closeTo(progressOffsets.first, 0.01));
            }
          },
        );
      }
    }
  }

  for (final textScale in [1.0, 2.0]) {
    testLibraryWidgets(
      'list titles keep rows aligned and truncate at text scale $textScale',
      (tester) async {
        const titles = [
          'Кот',
          'Море\nи небо',
          'Книга с очень длинным названием, которое не помещается в две строки',
        ];
        await mount(
          tester,
          size: const Size(320, 844),
          textScale: textScale,
          home: Scaffold(
            body: Column(
              children: [
                for (final (index, title) in titles.indexed)
                  BookCard(
                    key: ValueKey(index),
                    book: BookDto(
                      id: '$index',
                      title: title,
                      author: 'Автор',
                      format: 'epub',
                      createdAt: DateTime(2026),
                    ),
                    compact: true,
                    readingPercentage: 50,
                    onTap: () {},
                    onLongPress: (_) {},
                  ),
              ],
            ),
          ),
        );

        final heights = <double>[];
        final authorOffsets = <double>[];
        for (final (index, title) in titles.indexed) {
          final row = find.byKey(ValueKey(index));
          final heading = find
              .descendant(of: row, matching: find.text(title))
              .last;
          final author = find
              .descendant(of: row, matching: find.text('Автор'))
              .last;
          final paragraph = tester.renderObject<RenderParagraph>(heading);
          heights.add(tester.getSize(row).height);
          authorOffsets.add(
            tester.getTopLeft(author).dy - tester.getTopLeft(row).dy,
          );
          expect(paragraph.didExceedMaxLines, index == titles.length - 1);
        }
        expect(heights, everyElement(closeTo(heights.first, 0.01)));
        expect(authorOffsets, everyElement(closeTo(authorOffsets.first, 0.01)));
      },
    );
  }

  testLibraryWidgets('file metadata fits the list at large text scale', (
    tester,
  ) async {
    await mount(tester, size: const Size(320, 844), textScale: 2);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryScreen)),
    )!;
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<int>, l10n.libraryListView),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('3'));
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final count = NumberFormat.decimalPattern(l10n.localeName).format(9999);
    final pages = find.descendant(
      of: card,
      matching: find.textContaining(count),
    );
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
    final context = tester.element(find.byType(LibraryScreen));
    final l10n = AppLocalizations.of(context)!;
    final remove = find.widgetWithText(ListTile, l10n.deleteBook);
    final card = find.byKey(const ValueKey('0'));
    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ListTile, bookExportActionLabel(context)),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);

    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.delete));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testLibraryWidgets('a manual mark changes shelves without moving the book', (
    tester,
  ) async {
    await getIt<ReadingProgressLocalRepository>().saveProgress(
      ReadingProgressDto(
        bookId: '0',
        location: 'saved-position',
        percentage: 25,
        updatedAt: DateTime(2026),
      ),
    );
    await mount(tester);
    final context = tester.element(find.byType(LibraryScreen));
    final l10n = AppLocalizations.of(context)!;
    final card = find.byKey(const ValueKey('0'));
    Future<void> showShelf(String label) async {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    Future<void> chooseMark(String label) async {
      await tester.longPress(card);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, label));
      await tester.pumpAndSettle();
    }

    await showShelf(l10n.libraryInProgress);
    await chooseMark(l10n.bookMarkRead);
    expect(card, findsNothing);
    await showShelf(l10n.libraryFinished);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.textContaining('25,0%')),
      findsOneWidget,
    );
    await chooseMark(l10n.bookUnmarkRead);
    expect(card, findsNothing);
    await showShelf(l10n.libraryInProgress);
    expect(card, findsOneWidget);
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
      final controls = find.byTooltip(l10n.librarySortAndFilters);
      await tester.tap(controls);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ChoiceChip, l10n.librarySortProgress),
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
      await tester.tap(controls);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, l10n.librarySortTitle));
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
    await tester.tap(find.byTooltip(l10n.librarySortAndFilters));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'К обсуждению'));
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
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LibraryScreen)),
      )!;
      final menuDelete = find.widgetWithText(ListTile, l10n.deleteBook);
      final card = find.byKey(const ValueKey('0'));
      final edge = tester.getTopLeft(card) + const Offset(2, 24);
      final mouse = await tester.startGesture(
        edge,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(menuDelete, findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.longPressAt(edge);
      await tester.pumpAndSettle();
      expect(menuDelete, findsOneWidget);
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
