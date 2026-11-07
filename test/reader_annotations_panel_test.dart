import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/core/theme/app_theme.dart';
import 'package:lira/core/widgets/app_components.dart';
import 'package:lira/features/bookmarks/data/repositories/bookmarks_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/bookmarks/domain/models/bookmark_dto.dart';
import 'package:lira/features/highlights/data/repositories/highlights_local_repository.dart';
import 'package:lira/features/highlights/domain/models/highlight_dto.dart';
import 'package:lira/features/reader/domain/annotation_tools.dart';
import 'package:lira/features/reader/presentation/reader_annotations_panel.dart';
import 'package:lira/l10n/app_localizations.dart';

class _HighlightsStore implements HighlightsLocalRepository {
  final values = <String, HighlightDto>{};
  bool failLoads = false;
  bool failDeletes = false;
  bool failNoteWrites = false;
  Completer<void>? noteWriteGate;

  @override
  Future<List<HighlightDto>> getHighlightsForBook(String bookId) async {
    if (failLoads) throw StateError('Highlights unavailable');
    return values.values.where((value) => value.bookId == bookId).toList();
  }

  @override
  Future<void> saveHighlight(HighlightDto highlight) async {
    values[highlight.id] = highlight;
  }

  @override
  Future<void> updateHighlightNote(String id, String? note) async {
    if (noteWriteGate != null) await noteWriteGate!.future;
    if (failNoteWrites) throw StateError('Note storage unavailable');
    final highlight = values[id];
    if (highlight != null) values[id] = highlight.copyWith(note: note);
  }

  @override
  Future<void> deleteHighlight(String id) async {
    if (failDeletes) throw StateError('Highlight storage unavailable');
    values.remove(id);
  }
}

class _BookmarksStore implements BookmarksLocalRepository {
  final values = <String, BookmarkDto>{};
  bool failLoads = false;
  bool failDeletes = false;
  Completer<void>? deleteGate;

  @override
  Future<List<BookmarkDto>> getBookmarksForBook(String bookId) async {
    if (failLoads) throw StateError('Bookmarks unavailable');
    return values.values.where((value) => value.bookId == bookId).toList();
  }

  @override
  Future<void> saveBookmark(BookmarkDto bookmark) async {
    values[bookmark.id] = bookmark;
  }

  @override
  Future<void> deleteBookmark(String id) async {
    if (deleteGate != null) await deleteGate!.future;
    if (failDeletes) throw StateError('Bookmark storage unavailable');
    values.remove(id);
  }
}

final _book = BookDto(
  id: 'book',
  title: 'Source title',
  author: 'Source author',
  format: 'epub',
  createdAt: DateTime(2026),
);

Finder get _noteField => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Widget _app({
  required ValueChanged<String> onNavigate,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
  BookDto? book,
}) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => showAppBottomSheet<void>(
              context: context,
              builder: (_) => ReaderAnnotationsPanel(
                book: book ?? _book,
                onNavigate: onNavigate,
              ),
            ),
            child: const Text('Open annotations'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(
  WidgetTester tester, {
  ValueChanged<String>? onNavigate,
}) async {
  await tester.pumpWidget(_app(onNavigate: onNavigate ?? (_) {}));
  await tester.tap(find.text('Open annotations'));
  await tester.pumpAndSettle();
}

void main() {
  late _HighlightsStore highlights;
  late _BookmarksStore bookmarks;

  setUp(() {
    highlights = _HighlightsStore();
    bookmarks = _BookmarksStore();
    highlights.values['highlight'] = HighlightDto(
      id: 'highlight',
      bookId: 'book',
      text: 'Saved passage',
      color: '#4CAF50',
      location: 'epub:{"chapter":3,"offset":912}',
      note: 'Original note',
      createdAt: DateTime(2026),
    );
    bookmarks.values['bookmark'] = BookmarkDto(
      id: 'bookmark',
      bookId: 'book',
      location: 'pdf:{"page":17,"offset":0.37}',
      percentage: 42.5,
      createdAt: DateTime(2026),
    );
    bookmarks.values['other-book'] = BookmarkDto(
      id: 'other-book',
      bookId: 'another-book',
      location: 'must-not-navigate',
      percentage: 99,
      createdAt: DateTime(2026),
    );
    getIt.registerSingleton<HighlightsLocalRepository>(highlights);
    getIt.registerSingleton<BookmarksLocalRepository>(bookmarks);
  });

  tearDown(() => getIt.reset());

  test('exports omit missing author metadata without changing source data', () {
    const labels = AnnotationExportLabels(
      title: 'Title',
      author: 'Author',
      format: 'Format',
      bookId: 'Book',
      sourceAdded: 'Added',
      exported: 'Exported',
      annotations: 'Annotations',
      note: 'Note',
      color: 'Color',
      created: 'Created',
      chapter: 'Chapter',
      page: 'Page',
    );
    for (final author in ['', '   ', 'Unknown Author', ' unknown author ']) {
      final source = _book.copyWith(author: author);
      for (final format in AnnotationExportFormat.values) {
        final exported = exportAnnotations(
          book: source,
          annotations: highlights.values.values,
          format: format,
          labels: labels,
          exportedAt: DateTime(2026),
        );
        expect(exported, isNot(contains('Author:')));
        expect(exported, contains('Saved passage'));
        expect(source.author, author);
      }
    }
    final known = exportAnnotations(
      book: _book,
      annotations: highlights.values.values,
      format: AnnotationExportFormat.text,
      labels: labels,
      exportedAt: DateTime(2026),
    );
    expect(known, contains('Author: Source author'));
  });

  testWidgets(
    'narrow enlarged quotes keep content above independent controls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final quote =
          'A saved passage must remain readable across several lines '
          'without the editing controls squeezing away the words.';
      highlights.values['highlight'] = highlights.values['highlight']!.copyWith(
        text: quote,
        color: '#FFEB3B',
      );
      final navigated = <String>[];
      await tester.pumpWidget(
        _app(
          onNavigate: navigated.add,
          textScaler: const TextScaler.linear(1.6),
        ),
      );
      await tester.tap(find.text('Open annotations'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(quote));
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(find.text(quote));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.width, greaterThanOrEqualTo(320));
      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(checkbox).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text(quote)).dy),
      );
      expect(tester.getSize(checkbox), const Size(48, 48));
      for (final icon in [
        Icons.copy_outlined,
        Icons.edit_note,
        Icons.delete_outline,
      ]) {
        final button = find.widgetWithIcon(IconButton, icon);
        expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      expect(navigated, isEmpty);
      await tester.ensureVisible(find.text(quote));
      await tester.pumpAndSettle();
      await tester.tap(find.text(quote));
      expect(navigated, [highlights.values['highlight']!.location]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard leaves annotation filters and matching actions reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await _open(tester);
      final search = find.byKey(const ValueKey('annotations-search'));
      await tester.enterText(search, 'Original');
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      final copy = find.widgetWithIcon(IconButton, Icons.copy_outlined);
      await tester.scrollUntilVisible(
        copy,
        100,
        scrollable: find.descendant(
          of: find.byType(ReaderAnnotationsPanel),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(copy).dy, lessThanOrEqualTo(240));
      expect(copy.hitTestable(), findsOneWidget);
      final noteFilter = find.widgetWithText(FilterChip, 'With note');
      await tester.ensureVisible(noteFilter);
      await tester.pumpAndSettle();
      expect(noteFilter.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(noteFilter).dy, lessThanOrEqualTo(240));
      await tester.tap(noteFilter);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(noteFilter).selected, isTrue);
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      expect(search.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(search).dy, lessThanOrEqualTo(240));
      expect(highlights.values, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('localized bookmark percentages retain the original target', (
    tester,
  ) async {
    final navigated = <String>[];
    await tester.pumpWidget(
      _app(onNavigate: navigated.add, locale: const Locale('ru')),
    );
    await tester.tap(find.text('Open annotations'));
    await tester.pumpAndSettle();
    final panel = find.byType(ReaderAnnotationsPanel);
    final l10n = AppLocalizations.of(tester.element(panel))!;
    await tester.tap(find.text(l10n.bookmarks));
    await tester.pumpAndSettle();
    final position = find.text(l10n.bookmarkPosition('42,5%'));
    expect(position, findsOneWidget);
    await tester.tap(position);
    expect(navigated, [bookmarks.values['bookmark']!.location]);
    expect(bookmarks.values['bookmark']!.percentage, 42.5);
  });

  testWidgets('tabs separate annotations and preserve opaque navigation', (
    tester,
  ) async {
    final navigated = <String>[];
    await _open(tester, onNavigate: navigated.add);
    expect(find.text('Saved passage'), findsOneWidget);
    expect(find.text('Original note'), findsOneWidget);
    expect(find.text('Position: 42.5%'), findsNothing);
    await tester.tap(find.text('Saved passage'));
    expect(navigated, [highlights.values['highlight']!.location]);

    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('Saved passage'), findsNothing);
    expect(find.text('Position: 42.5%'), findsOneWidget);
    expect(find.text('Position: 99%'), findsNothing);
    await tester.tap(find.text('Position: 42.5%'));
    expect(navigated.last, bookmarks.values['bookmark']!.location);

    await tester.tap(find.text('Highlights'));
    await tester.pumpAndSettle();
    expect(find.text('Original note'), findsOneWidget);
  });

  testWidgets('bookmark removal waits for storage and remains retryable', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    final removeBookmark = find.descendant(
      of: find.widgetWithText(ListTile, 'Position: 42.5%'),
      matching: find.byType(IconButton),
    );
    bookmarks.deleteGate = Completer<void>();
    bookmarks.failDeletes = true;
    await tester.tap(removeBookmark);
    await tester.pump();
    expect(find.text('Position: 42.5%'), findsOneWidget);
    expect(bookmarks.values.containsKey('bookmark'), isTrue);
    expect(tester.widget<IconButton>(removeBookmark).onPressed, isNull);

    bookmarks.deleteGate!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not remove bookmark:'), findsOneWidget);
    expect(find.text('Position: 42.5%'), findsOneWidget);
    bookmarks.failDeletes = false;
    bookmarks.deleteGate = null;
    await tester.tap(removeBookmark);
    await tester.pumpAndSettle();
    expect(find.text('Position: 42.5%'), findsNothing);
    expect(find.text('No bookmarks yet'), findsOneWidget);
    expect(bookmarks.values.containsKey('bookmark'), isFalse);
    expect(bookmarks.values.containsKey('other-book'), isTrue);
  });

  testWidgets('failed highlight deletion keeps its text and note', (
    tester,
  ) async {
    highlights.failDeletes = true;
    await _open(tester);
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not delete highlight:'), findsOneWidget);
    expect(find.text('Saved passage'), findsOneWidget);
    expect(find.text('Original note'), findsOneWidget);
    highlights.failDeletes = false;
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('No highlights yet'), findsOneWidget);
    expect(highlights.values, isEmpty);
  });

  testWidgets('failed note save preserves the editor and text for retry', (
    tester,
  ) async {
    await _open(tester);
    await tester.ensureVisible(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
    await tester.enterText(_noteField, 'Changed note');
    highlights.noteWriteGate = Completer<void>();
    highlights.failNoteWrites = true;
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    highlights.noteWriteGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Could not save note:'), findsOneWidget);
    expect(
      tester.widget<TextField>(_noteField).controller!.text,
      'Changed note',
    );
    expect(highlights.values['highlight']!.note, 'Original note');

    highlights.failNoteWrites = false;
    highlights.noteWriteGate = null;
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Changed note'), findsOneWidget);
    expect(highlights.values['highlight']!.note, 'Changed note');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel leaves the saved note unchanged through route dismissal',
    (tester) async {
      await _open(tester);
      await tester.ensureVisible(find.byIcon(Icons.edit_note));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_note));
      await tester.pumpAndSettle();
      await tester.enterText(_noteField, 'Discarded note');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(highlights.values['highlight']!.note, 'Original note');
      expect(find.text('Original note'), findsOneWidget);
    },
  );

  testWidgets('tabs keep empty and loading-error states separate', (
    tester,
  ) async {
    highlights.values.clear();
    bookmarks.values.clear();
    await _open(tester);
    expect(find.text('No highlights yet'), findsOneWidget);
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('No bookmarks yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    highlights.failLoads = true;
    bookmarks.failLoads = true;
    await _open(tester);
    expect(find.text('Could not load highlights'), findsOneWidget);
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load bookmarks'), findsOneWidget);
  });

  testWidgets('quote and note searches intersect note and color filters', (
    tester,
  ) async {
    highlights.values['other'] = HighlightDto(
      id: 'other',
      bookId: 'book',
      text: 'Other passage',
      color: '#42A5F5',
      location: 'opaque-location',
      createdAt: DateTime(2026),
    );
    await _open(tester);
    final search = find.byKey(const ValueKey('annotations-search'));
    await tester.enterText(search, 'ORIGINAL');
    await tester.pumpAndSettle();
    expect(find.text('Saved passage'), findsOneWidget);
    expect(find.text('Other passage'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'With note'));
    await tester.tap(find.widgetWithText(FilterChip, '#42A5F5'));
    await tester.pumpAndSettle();
    expect(find.text('No matching annotations'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Saved passage'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Other passage'),
      100,
      scrollable: find.descendant(
        of: find.byType(ReaderAnnotationsPanel),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Other passage'), findsOneWidget);
    expect(find.text('Other passage').hitTestable(), findsOneWidget);
  });

  testWidgets('copying saved quote includes source title and author', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    for (final author in ['Source author', '', 'Unknown Author']) {
      await tester.pumpWidget(
        _app(
          onNavigate: (_) {},
          book: _book.copyWith(author: author),
        ),
      );
      await tester.tap(find.text('Open annotations'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.copy_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pumpAndSettle();
      expect(
        copied,
        author == 'Source author'
            ? 'Saved passage\n\n— Source title — Source author'
            : 'Saved passage\n\n— Source title',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
