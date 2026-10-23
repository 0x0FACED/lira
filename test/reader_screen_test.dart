import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/highlights/data/repositories/highlights_local_repository.dart';
import 'package:lira/features/highlights/domain/models/highlight_dto.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';
import 'package:lira/features/reader/presentation/reader_screen.dart';
import 'package:lira/features/settings/data/settings_provider.dart';

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

Widget _app(BookDto book) => ProviderScope(
  child: MaterialApp(
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
  final blocks = XhtmlParser(
    html: view.epub.chapters[location.chapterIndex].htmlContent,
    images: view.epub.images,
    baseStyle: TextStyle(fontSize: view.settings.fontSize),
  ).parse().whereType<TextBlock>();
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

void main() {
  late Directory directory;
  late _ProgressStore progress;
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
  setUp(() {
    progress = _ProgressStore();
    getIt.registerSingleton<ReadingProgressLocalRepository>(progress);
    getIt.registerSingleton<HighlightsLocalRepository>(_HighlightsStore());
  });
  tearDown(() => getIt.reset());

  testWidgets(
    'an invalid EPUB shows an error without replacing saved progress',
    (tester) async {
      final existing = ReadingProgressDto(
        bookId: corrupt.id,
        percentage: 42,
        location: 'saved-before-error',
        updatedAt: DateTime(2026),
      );
      progress.persisted = existing;
      await _open(tester, corrupt);
      expect(find.textContaining('Error:'), findsOneWidget);
      expect(find.byType(EpubNativeView), findsNothing);
      expect(progress.persisted, existing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Open reader'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      expect(find.text('Error loading progress'), findsNothing);
      expect(
        find.textContaining('Failed to save reading position:'),
        findsOneWidget,
      );
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
