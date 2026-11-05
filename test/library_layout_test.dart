import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/core/widgets/app_components.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/domain/providers/library_layout_provider.dart';
import 'package:lira/features/books/presentation/library_screen.dart';
import 'package:lira/features/books/presentation/widgets/book_card.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          home: const LibraryScreen(),
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

  testWidgets('density changes preserve search and survive reopening', (
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
        testWidgets(
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
              final title = find.descendant(
                of: card,
                matching: find.text(book.title),
              );
              coverSizes.add(tester.getSize(cover));
              titleOffsets.add(
                tester.getTopLeft(title).dy - tester.getTopLeft(card).dy,
              );
              if (textScale == 1) {
                expect(
                  tester.getSize(cover).height,
                  greaterThan(tester.getSize(card).height / 2),
                );
              }
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

  testWidgets('page count is accessible and aligned to the card right edge', (
    tester,
  ) async {
    await mount(tester);
    final card = find.byKey(const ValueKey('0'));
    final format = find.descendant(of: card, matching: find.byType(AppBadge));
    final pages = find.descendant(of: card, matching: find.text('1234'));
    final cardRect = tester.getRect(card);
    expect(
      cardRect.right - tester.getRect(pages).right,
      closeTo(tester.getRect(format).left - cardRect.left, 0.01),
    );
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(pages).label, contains('1234'));
    semantics.dispose();
    final withoutPages = find.byKey(const ValueKey('2'));
    expect(
      find.descendant(of: withoutPages, matching: find.text('0')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('page count fits a dense row at large text scale', (
    tester,
  ) async {
    await sharedPrefs.setInt(LibraryColumnsNotifier.storageKey, 3);
    await mount(tester, size: const Size(320, 844), textScale: 2);
    final card = find.byKey(const ValueKey('3'));
    await tester.ensureVisible(card);
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

  testWidgets('long press still requires confirmation before deleting', (
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

  testWidgets(
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

  testWidgets('tablet retains the automatic grid', (tester) async {
    await sharedPrefs.setInt(LibraryColumnsNotifier.storageKey, 3);
    await mount(tester, size: const Size(800, 1200));
    expect(find.byType(PopupMenuButton<int>), findsNothing);
    expectColumns(tester, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
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
