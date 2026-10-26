import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _chapterLabels = ['FIRST', 'SECOND', 'THIRD'];

ParsedEpub _book({List<String> labels = _chapterLabels}) => ParsedEpub(
  title: 'Paper turn regressions',
  author: 'Lira',
  chapters: [
    for (final label in labels)
      EpubChapter(
        title: label,
        fileName: '${label.toLowerCase()}.xhtml',
        htmlContent: '<html><body><p>$label</p></body></html>',
      ),
  ],
  toc: const [],
  images: const {},
);

class _ReaderFixture {
  _ReaderFixture({
    required this.book,
    required this.size,
    required this.reducedMotion,
    required bool dualPage,
    required int initialChapter,
  }) : initialLocation = EpubLocation.fromPosition(
         chapterIndex: initialChapter,
         hasExactCharOffset: true,
       ),
       settings = ReaderSettings(
         readingMode: ReadingMode.horizontal,
         enableDualPageSpread: dualPage,
       );

  final ParsedEpub book;
  final bool reducedMotion;
  final EpubLocation initialLocation;
  final readerKey = GlobalKey<EpubNativeViewState>();
  final locations = <EpubLocation>[];
  final percentages = <double>[];
  final selectedTexts = <String>[];
  late StateSetter _rebuild;
  EpubLocation? latest;
  ReaderSettings settings;
  Size size;

  Widget build() => StatefulBuilder(
    builder: (context, setState) {
      _rebuild = setState;
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: reducedMotion),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: EpubNativeView(
                key: readerKey,
                epub: book,
                initialLocation: initialLocation,
                settings: settings,
                theme: ThemeData.light(),
                onLocationChanged: (location, percentage) {
                  latest = location;
                  locations.add(location);
                  percentages.add(percentage);
                },
                onTextSelected: (text, _) => selectedTexts.add(text),
              ),
            ),
          ),
        ),
      );
    },
  );

  void clearReports() {
    locations.clear();
    percentages.clear();
  }

  void reflow({ReaderSettings? settings, Size? size}) {
    _rebuild(() {
      if (settings != null) this.settings = settings;
      if (size != null) this.size = size;
    });
  }
}

Future<_ReaderFixture> _pumpReader(
  WidgetTester tester, {
  ParsedEpub? book,
  Size size = const Size(600, 400),
  bool reducedMotion = false,
  bool dualPage = false,
  int initialChapter = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final fixture = _ReaderFixture(
    book: book ?? _book(),
    size: size,
    reducedMotion: reducedMotion,
    dualPage: dualPage,
    initialChapter: initialChapter,
  );
  await tester.pumpWidget(fixture.build());
  await tester.pumpAndSettle();
  // Nested native selection registrars may still have post-frame work after
  // the initial location restoration, without scheduling a new frame.
  await tester.pump(const Duration(milliseconds: 16));
  expect(fixture.latest?.chapterIndex, initialChapter);
  fixture.clearReports();
  return fixture;
}

String _renderedText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((widget) => widget.text.toPlainText())
    .where((text) => text.isNotEmpty)
    .join('\n');

void _expectChapters(WidgetTester tester, List<String> labels) {
  expect(_renderedText(tester), labels.join('\n'));
}

Duration _eventTime(WidgetTester tester) =>
    Duration(microseconds: tester.binding.clock.now().microsecondsSinceEpoch);

Future<TestGesture> _beginDrag(
  WidgetTester tester,
  _ReaderFixture fixture,
  double distance,
) async {
  final direction = distance.sign;
  final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
  await gesture.down(
    Offset(
      fixture.size.width * (direction < 0 ? 0.85 : 0.15),
      fixture.size.height * 0.65,
    ),
    timeStamp: _eventTime(tester),
  );
  // Cross the gesture slop separately so the remaining travel is intentional.
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(
    Offset(direction * 24, 0),
    timeStamp: _eventTime(tester),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(
    Offset(distance - direction * 24, 0),
    timeStamp: _eventTime(tester),
  );
  await tester.pump();
  return gesture;
}

Future<void> _releaseSlowly(WidgetTester tester, TestGesture gesture) async {
  // A stationary pause must not let test velocity sampling turn this into a
  // fling. Both the fake clock and pointer timestamps advance together.
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up(timeStamp: _eventTime(tester));
}

void main() {
  testWidgets('long press still selects text instead of turning a page', (
    tester,
  ) async {
    final fixture = await _pumpReader(tester);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text('FIRST'), matching: find.byType(RichText)),
    );
    final glyph = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .first;
    final gesture = await tester.startGesture(
      paragraph.localToGlobal(glyph.toRect().center),
      kind: PointerDeviceKind.touch,
    );
    // Render the tap-down/focus frame before the long-press deadline, as the
    // running app does while the finger is held still.
    await tester.pump(kPressTimeout);
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fixture.selectedTexts, contains('FIRST'));
    expect(fixture.latest!.chapterIndex, 0);
    expect(fixture.locations, isEmpty);
  });

  testWidgets('a short slow drag cancels without publishing a destination', (
    tester,
  ) async {
    final fixture = await _pumpReader(tester);
    _expectChapters(tester, ['FIRST']);
    final source = fixture.latest!.toJson();
    final gesture = await _beginDrag(tester, fixture, -100);
    expect(fixture.locations, isEmpty);

    await _releaseSlowly(tester, gesture);
    expect(fixture.locations, isEmpty);
    await tester.pumpAndSettle();

    _expectChapters(tester, ['FIRST']);
    expect(fixture.latest!.toJson(), source);
    expect(fixture.locations, isEmpty);
    expect(fixture.percentages, isEmpty);
  });

  testWidgets(
    'left and right drags publish a turn only after release and settle',
    (tester) async {
      final fixture = await _pumpReader(tester);
      final next = await _beginDrag(tester, fixture, -330);
      await tester.pump(const Duration(milliseconds: 400));
      expect(fixture.locations, isEmpty);
      expect(fixture.latest!.chapterIndex, 0);

      await _releaseSlowly(tester, next);
      expect(fixture.locations, isEmpty);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(fixture.locations, isEmpty);
      await tester.pumpAndSettle();

      _expectChapters(tester, ['SECOND']);
      expect(fixture.locations.map((location) => location.chapterIndex), [1]);
      expect(fixture.latest!.charOffset, 0);
      final secondPercentage = fixture.percentages.single;
      expect(secondPercentage, greaterThan(0));

      fixture.clearReports();
      final previous = await _beginDrag(tester, fixture, 330);
      await tester.pump(const Duration(milliseconds: 400));
      expect(fixture.locations, isEmpty);
      expect(fixture.latest!.chapterIndex, 1);
      await _releaseSlowly(tester, previous);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(fixture.locations, isEmpty);
      await tester.pumpAndSettle();

      _expectChapters(tester, ['FIRST']);
      expect(fixture.locations.map((location) => location.chapterIndex), [0]);
      expect(fixture.percentages.single, lessThan(secondPercentage));
    },
  );

  testWidgets('pointer cancellation rolls back even a mostly turned page', (
    tester,
  ) async {
    final fixture = await _pumpReader(tester);
    final gesture = await _beginDrag(tester, fixture, -420);
    expect(fixture.locations, isEmpty);
    await gesture.cancel(timeStamp: _eventTime(tester));
    await tester.pumpAndSettle();

    _expectChapters(tester, ['FIRST']);
    expect(fixture.latest!.chapterIndex, 0);
    expect(fixture.locations, isEmpty);
    expect(fixture.percentages, isEmpty);

    final retry = await _beginDrag(tester, fixture, -330);
    await _releaseSlowly(tester, retry);
    await tester.pumpAndSettle();
    _expectChapters(tester, ['SECOND']);
    expect(fixture.locations.map((location) => location.chapterIndex), [1]);
  });

  testWidgets('first and last page boundaries do not publish extra progress', (
    tester,
  ) async {
    final fixture = await _pumpReader(tester);
    final beforeFirst = await _beginDrag(tester, fixture, 330);
    await _releaseSlowly(tester, beforeFirst);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.tapAt(const Offset(30, 260));
    await tester.pumpAndSettle();

    _expectChapters(tester, ['FIRST']);
    expect(fixture.locations, isEmpty);
    expect(fixture.percentages, isEmpty);

    fixture.readerKey.currentState!.scrollToChapter('third.xhtml');
    await tester.pumpAndSettle();
    _expectChapters(tester, ['THIRD']);
    fixture.clearReports();
    final afterLast = await _beginDrag(tester, fixture, -330);
    await _releaseSlowly(tester, afterLast);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.tapAt(const Offset(570, 260));
    await tester.pumpAndSettle();

    _expectChapters(tester, ['THIRD']);
    expect(fixture.latest!.chapterIndex, 2);
    expect(fixture.locations, isEmpty);
    expect(fixture.percentages, isEmpty);
  });

  testWidgets(
    'reduced motion keyboard and edge taps navigate without animation delay',
    (tester) async {
      final fixture = await _pumpReader(tester, reducedMotion: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      _expectChapters(tester, ['SECOND']);
      expect(fixture.locations.map((location) => location.chapterIndex), [1]);

      fixture.clearReports();
      await tester.tapAt(const Offset(570, 260));
      await tester.pump();
      _expectChapters(tester, ['THIRD']);
      expect(fixture.locations.map((location) => location.chapterIndex), [2]);

      fixture.clearReports();
      await tester.tapAt(const Offset(30, 260));
      await tester.pump();
      _expectChapters(tester, ['SECOND']);
      expect(fixture.locations.map((location) => location.chapterIndex), [1]);

      fixture.clearReports();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      _expectChapters(tester, ['FIRST']);
      expect(fixture.locations.map((location) => location.chapterIndex), [0]);
    },
  );

  testWidgets('TOC navigation interrupts a held drag without a stale commit', (
    tester,
  ) async {
    final fixture = await _pumpReader(tester, initialChapter: 1);
    final gesture = await _beginDrag(tester, fixture, -330);
    expect(fixture.locations, isEmpty);

    fixture.readerKey.currentState!.scrollToChapter('first.xhtml');
    await tester.pumpAndSettle();
    _expectChapters(tester, ['FIRST']);
    expect(fixture.latest!.chapterIndex, 0);

    await _releaseSlowly(tester, gesture);
    await tester.pumpAndSettle();
    _expectChapters(tester, ['FIRST']);
    expect(fixture.locations.map((location) => location.chapterIndex), [0]);
  });

  for (final change in ['font reflow', 'viewport resize']) {
    testWidgets('$change interrupts a held drag without a stale commit', (
      tester,
    ) async {
      final fixture = await _pumpReader(tester, initialChapter: 1);
      final gesture = await _beginDrag(tester, fixture, -330);
      expect(fixture.locations, isEmpty);

      if (change == 'font reflow') {
        fixture.reflow(settings: fixture.settings.copyWith(fontSize: 26));
      } else {
        fixture.reflow(size: const Size(520, 360));
      }
      await tester.pumpAndSettle();
      _expectChapters(tester, ['SECOND']);
      expect(fixture.latest!.chapterIndex, 1);
      expect(fixture.latest!.charOffset, 0);

      await _releaseSlowly(tester, gesture);
      await tester.pumpAndSettle();
      _expectChapters(tester, ['SECOND']);
      expect(
        fixture.locations.map((location) => location.chapterIndex),
        everyElement(1),
      );
      expect(fixture.latest!.chapterIndex, 1);

      fixture.clearReports();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      _expectChapters(tester, ['THIRD']);
      expect(fixture.locations.map((location) => location.chapterIndex), [2]);
    });
  }

  testWidgets('two-page turns commit whole chapter pairs in both directions', (
    tester,
  ) async {
    final fixture = await _pumpReader(
      tester,
      book: _book(labels: const ['FIRST', 'SECOND', 'THIRD', 'FOURTH']),
      size: const Size(1200, 600),
      dualPage: true,
    );
    _expectChapters(tester, ['FIRST', 'SECOND']);
    final next = await _beginDrag(tester, fixture, -660);
    expect(fixture.locations, isEmpty);
    await _releaseSlowly(tester, next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(fixture.locations, isEmpty);
    await tester.pumpAndSettle();

    _expectChapters(tester, ['THIRD', 'FOURTH']);
    expect(fixture.locations.map((location) => location.chapterIndex), [2]);
    expect(fixture.latest!.charOffset, 0);

    fixture.clearReports();
    final previous = await _beginDrag(tester, fixture, 660);
    await _releaseSlowly(tester, previous);
    await tester.pumpAndSettle();
    _expectChapters(tester, ['FIRST', 'SECOND']);
    expect(fixture.locations.map((location) => location.chapterIndex), [0]);
  });
}
