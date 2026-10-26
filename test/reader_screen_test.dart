import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/core/theme/app_tokens.dart';
import 'package:lira/features/bookmarks/data/repositories/bookmarks_local_repository.dart';
import 'package:lira/features/bookmarks/domain/models/bookmark_dto.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/highlights/data/repositories/highlights_local_repository.dart';
import 'package:lira/features/highlights/domain/models/highlight_dto.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';
import 'package:lira/features/reader/presentation/reader_screen.dart';
import 'package:lira/features/reader/presentation/reader_annotations_panel.dart';
import 'package:lira/features/settings/data/settings_provider.dart';
import 'package:lira/l10n/app_localizations.dart';

class _ProgressStore implements ReadingProgressLocalRepository {
  ReadingProgressDto? persisted;
  bool failWrites = false;
  Completer<void>? writeGate;
  @override
  Future<ReadingProgressDto?> getProgress(String bookId) async => persisted;
  @override
  Future<void> saveProgress(ReadingProgressDto progress) async {
    if (failWrites) throw StateError('Storage unavailable');
    if (writeGate != null) await writeGate!.future;
    persisted = progress;
  }
}

class _HighlightsStore implements HighlightsLocalRepository {
  final values = <String, HighlightDto>{};
  @override
  Future<List<HighlightDto>> getHighlightsForBook(String bookId) async =>
      values.values.where((value) => value.bookId == bookId).toList();
  @override
  Future<void> saveHighlight(HighlightDto highlight) async {
    values[highlight.id] = highlight;
  }

  @override
  Future<void> updateHighlightNote(String id, String? note) async {
    final highlight = values[id];
    if (highlight != null) values[id] = highlight.copyWith(note: note);
  }

  @override
  Future<void> deleteHighlight(String id) async {
    values.remove(id);
  }
}

class _BookmarksStore implements BookmarksLocalRepository {
  final values = <String, BookmarkDto>{};

  @override
  Future<List<BookmarkDto>> getBookmarksForBook(String bookId) async =>
      values.values.where((value) => value.bookId == bookId).toList();

  @override
  Future<void> saveBookmark(BookmarkDto bookmark) async {
    if (values.values.any(
      (value) =>
          value.bookId == bookmark.bookId &&
          value.location == bookmark.location,
    )) {
      return;
    }
    values[bookmark.id] = bookmark;
  }

  @override
  Future<void> deleteBookmark(String id) async {
    values.remove(id);
  }
}

Widget _app(BookDto book) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReaderScreen(book: book),
                          ),
                        ),
                        child: const Text('Open reader'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Open library'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, BookDto book) async {
  await tester.pumpWidget(_app(book));
  await tester.tap(find.text('Open library'));
  await tester.pumpAndSettle();
  await _openReader(tester);
}

Future<void> _openReader(WidgetTester tester) async {
  await tester.tap(find.text('Open reader'));
  await tester.pump();
  // File IO needs the real event loop; pumping fake frames alone starves it.
  for (var frame = 0; frame < 100; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Reader did not finish loading its local file');
}

void _expectSavedTextVisible(WidgetTester tester, EpubLocation location) {
  final reader = find.byType(EpubNativeView);
  final view = tester.widget<EpubNativeView>(reader);
  final viewport = tester.getRect(reader);
  final blocks = contentLeaves(
    XhtmlParser(
      html: view.epub.chapters[location.chapterIndex].htmlContent,
      images: view.epub.images,
      documentPath: view.epub.chapters[location.chapterIndex].fileName,
      stylesheets: view.epub.stylesheets,
      baseStyle: TextStyle(fontSize: view.settings.fontSize),
    ).parse(),
  ).whereType<TextBlock>();
  final block = blocks.firstWhere(
    (block) =>
        block.charStart <= location.charOffset &&
        location.charOffset < block.charEnd,
  );
  final visibleCarets = <Offset>[];
  for (final element
      in find
          .descendant(of: reader, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph ||
        paragraph.text.toPlainText() != block.span.toPlainText())
      continue;
    final caret = paragraph.getOffsetForCaret(
      TextPosition(offset: location.charOffset - block.charStart),
      Rect.zero,
    );
    final point = paragraph.localToGlobal(
      caret + Offset(1, view.settings.fontSize / 2),
    );
    if (tester
        .hitTestOnBinding(point)
        .path
        .any((entry) => identical(entry.target, paragraph)))
      visibleCarets.add(point);
  }
  expect(
    visibleCarets.any(
      (point) =>
          point.dy >= viewport.top &&
          point.dy <=
              viewport.top +
                  view.settings.fontSize * view.settings.lineHeight * 3,
    ),
    isTrue,
    reason: 'The saved text must reopen near the reading edge: $visibleCarets',
  );
}

List<(String, double)> _visibleParagraphs(WidgetTester tester) {
  final reader = find.byType(EpubNativeView);
  final viewport = tester.getRect(reader);
  final paragraphs = <(String, double)>[];
  for (final element
      in find
          .descendant(of: reader, matching: find.byType(RichText))
          .evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph) continue;
    final rect = render.localToGlobal(Offset.zero) & render.size;
    if (rect.bottom > viewport.top && rect.top < viewport.bottom) {
      paragraphs.add((render.text.toPlainText(), rect.top));
    }
  }
  paragraphs.sort((a, b) => a.$2.compareTo(b.$2));
  return paragraphs;
}

int _chromeTapCount = 0;

Offset _chromeTapPosition(WidgetTester tester) {
  // Distinct center-zone taps are not a native double-tap selection gesture.
  final dx = (_chromeTapCount++).isEven ? -40.0 : 40.0;
  return tester.getCenter(find.byType(EpubNativeView)) + Offset(dx, 0);
}

Future<void> _showControls(WidgetTester tester) async {
  await tester.tapAt(_chromeTapPosition(tester));
  await tester.pumpAndSettle();
}

Future<void> _openAnnotations(WidgetTester tester) async {
  final l10n = AppLocalizations.of(tester.element(find.byType(ReaderScreen)))!;
  await tester.tap(find.byTooltip(l10n.annotations));
  await tester.pumpAndSettle();
}

void main() {
  late Directory directory;
  late _ProgressStore progress;
  late _HighlightsStore highlights;
  late _BookmarksStore bookmarks;
  late BookDto readable;
  late BookDto corrupt;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
    directory = Directory.systemTemp.createTempSync('lira-reader-tests-');
    final archive = Archive();
    void add(String path, String text) {
      final bytes = utf8.encode(text);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('mimetype', 'application/epub+zip');
    add(
      'META-INF/container.xml',
      '<container><rootfiles><rootfile full-path="content.opf"/></rootfiles></container>',
    );
    add(
      'content.opf',
      '<package><metadata><title>Reader fixture</title><creator>Lira</creator></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>',
    );
    add(
      'chapter.xhtml',
      '<html><body>${List.generate(60, (i) => '<p>Paragraph $i. ${'Readable text for position restoration. ' * 8}</p>').join()}</body></html>',
    );
    final file = File('${directory.path}/readable.epub')
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    final invalid = File('${directory.path}/invalid.epub')
      ..writeAsStringSync('Not an EPUB');
    readable = BookDto(
      id: 'readable',
      title: 'Reader fixture',
      format: 'epub',
      fileUrl: file.path,
      createdAt: DateTime(2026),
    );
    corrupt = BookDto(
      id: 'invalid',
      title: 'Invalid fixture',
      format: 'epub',
      fileUrl: invalid.path,
      createdAt: DateTime(2026),
    );
  });

  tearDownAll(() => directory.deleteSync(recursive: true));
  setUp(() async {
    _chromeTapCount = 0;
    await sharedPrefs.clear();
    progress = _ProgressStore();
    getIt.registerSingleton<ReadingProgressLocalRepository>(progress);
    highlights = _HighlightsStore();
    bookmarks = _BookmarksStore();
    getIt.registerSingleton<HighlightsLocalRepository>(highlights);
    getIt.registerSingleton<BookmarksLocalRepository>(bookmarks);
  });
  tearDown(() => getIt.reset());

  for (final mode in ReadingMode.values) {
    testWidgets(
      '$mode note editor keeps the book fixed while the keyboard opens and closes',
      (tester) async {
        final highlight = HighlightDto(
          id: 'annotated-passage',
          bookId: readable.id,
          text: 'Paragraph 0.',
          location: EpubLocation.fromPosition(
            chapterIndex: 0,
            charOffset: 0,
            hasExactCharOffset: true,
            startOffset: 0,
            endOffset: 12,
          ).toJson(),
          createdAt: DateTime(2026),
        );
        highlights.values[highlight.id] = highlight;
        await _open(tester, readable);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ReaderScreen)),
        );
        final settings = container.read(readerSettingsProvider);
        await container
            .read(readerSettingsProvider.notifier)
            .updateSettings(
              settings.copyWith(readingMode: mode, enableDualPageSpread: false),
            );
        await tester.pumpAndSettle();
        if (mode == ReadingMode.vertical) {
          await tester.drag(find.byType(EpubNativeView), const Offset(0, -900));
          await tester.pumpAndSettle();
        } else {
          for (var page = 0; page < 4; page++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
            await tester.pumpAndSettle();
          }
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        final locationBefore = progress.persisted!.location;
        expect(
          EpubLocation.fromJson(locationBefore)!.charOffset,
          greaterThan(0),
        );
        final viewport = tester.getRect(find.byType(EpubNativeView));
        final paragraphs = _visibleParagraphs(tester);
        await _showControls(tester);
        await _openAnnotations(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(ReaderAnnotationsPanel),
            matching: find.byTooltip('Add note'),
          ),
        );
        await tester.pumpAndSettle();
        addTearDown(tester.view.resetViewInsets);
        for (final inset in [120.0, 300.0, 180.0]) {
          tester.view.viewInsets = FakeViewPadding(
            bottom: inset * tester.view.devicePixelRatio,
          );
          for (var frame = 0; frame < 4; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.getRect(find.byType(EpubNativeView)), viewport);
            expect(_visibleParagraphs(tester), paragraphs);
          }
        }
        await tester.enterText(find.byType(TextField), 'Contextual note $mode');
        await tester.tap(find.text('Save'));
        await tester.pump();
        tester.view.resetViewInsets();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(find.byType(EpubNativeView)), viewport);
          expect(_visibleParagraphs(tester), paragraphs);
        }
        await tester.pumpAndSettle();
        expect(highlights.values[highlight.id]!.note, 'Contextual note $mode');
        expect(progress.persisted!.location, locationBefore);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('both reader bars slide out before leaving the viewport', (
    tester,
  ) async {
    await _open(tester, readable);
    await _showControls(tester);
    final viewport = tester.getRect(find.byType(EpubNativeView));
    final top = find.byKey(const ValueKey('reader-top-bar'));
    final bottom = find.byKey(const ValueKey('reader-bottom-bar'));
    final shownTop = tester.getRect(top);
    final shownBottom = tester.getRect(bottom);
    final duration = AppMotion.duration(tester.element(top));
    await tester.tapAt(_chromeTapPosition(tester));
    await tester.pump();
    await tester.pump(duration * 0.25);
    final hidingTop = tester.getRect(top);
    final hidingBottom = tester.getRect(bottom);
    expect(hidingTop.top, lessThan(shownTop.top));
    expect(hidingTop.bottom, greaterThan(viewport.top));
    expect(hidingBottom.top, greaterThan(shownBottom.top));
    expect(hidingBottom.top, lessThan(viewport.bottom));
    await tester.pumpAndSettle();
    expect(tester.getRect(top).bottom, lessThanOrEqualTo(viewport.top));
    expect(tester.getRect(bottom).top, greaterThanOrEqualTo(viewport.bottom));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'bookmarks survive reopening and navigate separately from highlights',
    (tester) async {
      await _open(tester, readable);
      await tester.drag(find.byType(EpubNativeView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await _showControls(tester);
      await tester.tap(find.byTooltip('Add bookmark'));
      await tester.pumpAndSettle();
      final bookmark = bookmarks.values.values.single;
      final saved = EpubLocation.fromJson(bookmark.location)!;
      expect(saved.charOffset, greaterThan(0));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await _openReader(tester);
      await tester.drag(find.byType(EpubNativeView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await _showControls(tester);
      await _openAnnotations(tester);
      final panel = find.byType(ReaderAnnotationsPanel);
      expect(
        find.descendant(of: panel, matching: find.byType(ListTile)),
        findsNothing,
      );
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: panel, matching: find.byType(ListTile)),
      );
      await tester.pumpAndSettle();
      _expectSavedTextVisible(tester, saved);
      await _showControls(tester);
      await _openAnnotations(tester);
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: panel, matching: find.byTooltip('Remove bookmark')),
      );
      await tester.pumpAndSettle();
      expect(bookmarks.values, isEmpty);
      expect(
        find.descendant(of: panel, matching: find.byType(ListTile)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the current bookmark can be removed from the reading toolbar', (
    tester,
  ) async {
    await _open(tester, readable);
    await _showControls(tester);
    await tester.tap(find.byTooltip('Add bookmark'));
    await tester.pumpAndSettle();
    expect(
      EpubLocation.fromJson(
        bookmarks.values.values.single.location,
      )!.charOffset,
      0,
    );
    await tester.tap(find.byTooltip('Remove bookmark'));
    await tester.pumpAndSettle();
    expect(bookmarks.values, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an invalid EPUB mounts no reader and preserves saved progress', (
    tester,
  ) async {
    final existing = ReadingProgressDto(
      bookId: corrupt.id,
      percentage: 42,
      location: 'saved-before-error',
      updatedAt: DateTime(2026),
    );
    progress.persisted = existing;
    await _open(tester, corrupt);
    expect(find.byType(EpubNativeView), findsNothing);
    expect(progress.persisted, existing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open reader'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'closing and reopening restores the saved text near the reading edge',
    (tester) async {
      await _open(tester, readable);
      await tester.drag(find.byType(EpubNativeView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(EpubNativeView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(progress.persisted?.percentage, greaterThan(0));
      final location = EpubLocation.fromJson(progress.persisted!.location)!;
      expect(find.text('Open reader'), findsOneWidget);
      await _openReader(tester);
      _expectSavedTextVisible(tester, location);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'a save failure keeps the book readable and the position retryable',
    (tester) async {
      await _open(tester, readable);
      progress.failWrites = true;
      await tester.drag(find.byType(EpubNativeView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(EpubNativeView), findsOneWidget);
      progress.failWrites = false;
      await tester.tapAt(tester.getCenter(find.byType(EpubNativeView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(progress.persisted?.percentage, greaterThan(0));
      expect(find.text('Open reader'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a slow toolbar close cannot pop the previous route after system back',
    (tester) async {
      await _open(tester, readable);
      progress.writeGate = Completer<void>();
      await tester.drag(find.byType(EpubNativeView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(EpubNativeView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 100));
      progress.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open reader'), findsOneWidget);
      expect(find.text('Open library'), findsNothing);
      expect(progress.persisted?.percentage, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
