import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/reader/domain/engine/pdf_book_reader_engine.dart';
import 'package:lira/features/reader/domain/models/book_location.dart';
import 'package:pdf_engine/pdf_engine.dart';
import 'package:pdfrx/pdfrx.dart';

import '../packages/pdf_engine/test/support/pdf_fixture.dart';

Future<void> _pumpNativeUntil(
  WidgetTester tester,
  bool Function() ready,
) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (ready()) return;
  }
  fail('Real PDF viewer did not reach the expected state');
}

Future<int> _yellowPixelCount(WidgetTester tester, GlobalKey imageKey) async {
  final raw = await tester.runAsync(() async {
    final boundary =
        imageKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  });
  final bytes = raw!.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
  var count = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] - bytes[i + 2] > 50 && bytes[i + 1] - bytes[i + 2] > 50) {
      count++;
    }
  }
  return count;
}

Future<PdfViewerController> _openNativePdfReader(
  WidgetTester tester, {
  VoidCallback? onCenterTapped,
}) async {
  final engine = PdfBookReaderEngine();
  await tester.runAsync(() => engine.loadBook(readerPdfFixtureBytes()));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Builder(
        builder: (context) => engine.buildReaderWidget(
          context: context,
          initialLocation: const BookLocation(locator: '1'),
          settings: const ReaderSettings(),
          theme: Theme.of(context),
          onProgressChanged: (_, _) {},
          onTextSelected: (_, _) {},
          onCenterTapped: onCenterTapped,
        ),
      ),
    ),
  );
  final controller = tester
      .widget<PdfViewer>(find.byType(PdfViewer))
      .controller!;
  await _pumpNativeUntil(tester, () => controller.isReady);
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final modulePath = Platform.environment['PDFIUM_PATH'];
  final nativeRequirement = modulePath == null;

  testWidgets(
    'PDF reading width stays bounded on desktop while explicit zoom remains available',
    (tester) async {
      Pdfrx.pdfiumModulePath = modulePath;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = await _openNativePdfReader(tester);
      final readingWidth =
          controller.layout.pageLayouts.first.width * controller.currentZoom;
      expect(readingWidth, lessThanOrEqualTo(800));
      expect(readingWidth, greaterThan(600));
      final documentRef = controller.documentRef;
      unawaited(controller.goToPage(pageNumber: 2, duration: Duration.zero));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(2100, 1000);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.documentRef, same(documentRef));
      expect(controller.pageNumber, 2);
      expect(
        controller.layout.pageLayouts[1].width * controller.currentZoom,
        closeTo(readingWidth, 0.001),
      );
      final zoomBefore = controller.currentZoom;
      controller.value = controller.calcMatrixFor(
        controller.visibleRect.center,
        zoom: zoomBefore * 1.5,
      );
      await tester.pump();
      expect(controller.currentZoom, greaterThan(zoomBefore * 1.4));
      expect(
        controller.layout.pageLayouts[1].width * controller.currentZoom,
        greaterThan(800),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: nativeRequirement,
  );

  testWidgets(
    'wheel and trackpad scroll over selectable PDF text without changing zoom or toggling chrome',
    (tester) async {
      Pdfrx.pdfiumModulePath = modulePath;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var taps = 0;
      final controller = await _openNativePdfReader(
        tester,
        onCenterTapped: () => taps++,
      );
      final overlay = find.byWidgetPredicate(
        (widget) => widget is PdfPageTextOverlay && widget.page.pageNumber == 1,
      );
      await _pumpNativeUntil(
        tester,
        () =>
            overlay.evaluate().isNotEmpty &&
            tester
                .widget<PdfPageTextOverlay>(overlay)
                .selectables
                .containsKey(1),
      );
      final pageText = tester
          .widget<PdfPageTextOverlay>(overlay)
          .selectables[1]!
          .selectedRanges
          .pageText;
      final start = pageText.fullText.indexOf('alpha');
      final word = PdfTextRangeWithFragments.fromTextRange(
        pageText,
        start,
        start + 'alpha'.length,
      )!;
      final wordRect = controller.calcRectForRectInsidePage(
        pageNumber: 1,
        rect: word.bounds,
      );
      final point = controller.documentToGlobal(wordRect.center)!;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(point);
      await tester.pump();
      final initialZoom = controller.currentZoom;
      final initialTop = controller.visibleRect.top;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: point,
          scrollDelta: const Offset(0, 100),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();
      expect(controller.visibleRect.top, greaterThan(initialTop));
      expect(controller.currentZoom, closeTo(initialZoom, 0.000001));

      final trackpadPoint = controller.documentToGlobal(wordRect.center)!;
      await mouse.moveTo(trackpadPoint);
      await tester.pump();
      final beforePan = controller.visibleRect.top;
      final trackpad = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await trackpad.panZoomStart(trackpadPoint);
      for (var step = 1; step <= 10; step++) {
        await trackpad.panZoomUpdate(
          trackpadPoint,
          pan: Offset(0, -20.0 * step),
          timeStamp: Duration(milliseconds: step * 16),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await trackpad.panZoomEnd(timeStamp: const Duration(milliseconds: 176));
      await tester.pump();
      expect(
        controller.visibleRect.top,
        greaterThan(beforePan + 50 / initialZoom),
      );
      expect(controller.currentZoom, closeTo(initialZoom, 0.000001));
      unawaited(controller.goToPage(pageNumber: 1, duration: Duration.zero));
      await tester.pumpAndSettle();
      final pinchPoint = controller.documentToGlobal(wordRect.center)!;
      await mouse.moveTo(pinchPoint);
      await tester.pump();
      final pinch = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await pinch.panZoomStart(pinchPoint);
      for (var step = 1; step <= 5; step++) {
        await pinch.panZoomUpdate(
          pinchPoint,
          scale: 1 + step * 0.1,
          timeStamp: Duration(milliseconds: 200 + step * 16),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await pinch.panZoomEnd(timeStamp: const Duration(milliseconds: 300));
      await tester.pump();
      expect(controller.currentZoom, greaterThan(initialZoom * 1.2));
      final beforeMargin = controller.visibleRect.top;
      final zoomBeforeMargin = controller.currentZoom;
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(20, 400),
          scrollDelta: Offset(0, 100),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();
      expect(controller.visibleRect.top, greaterThan(beforeMargin));
      expect(controller.currentZoom, closeTo(zoomBeforeMargin, 0.000001));
      expect(taps, 0);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: nativeRequirement,
  );

  testWidgets(
    'navigation still moves the mounted viewer after progress/settings/highlight rebuilds',
    (tester) async {
      Pdfrx.pdfiumModulePath = modulePath;
      final engine = PdfBookReaderEngine();
      await tester.runAsync(() => engine.loadBook(readerPdfFixtureBytes()));
      addTearDown(engine.dispose);
      expect(engine.getToc().single.fileName, '3');
      var settings = const ReaderSettings(backgroundColor: 0xFFFFFFFF);
      var progress = const BookLocation(locator: '1');
      var highlights = <Map<String, dynamic>>[];
      final imageKey = GlobalKey();
      Future<void> mount() => tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: imageKey,
            child: Builder(
              builder: (context) => engine.buildReaderWidget(
                context: context,
                initialLocation: progress,
                settings: settings,
                theme: Theme.of(context),
                onProgressChanged: (location, percentage) =>
                    progress = location,
                onTextSelected: (text, location) {},
                highlights: highlights,
              ),
            ),
          ),
        ),
      );
      PdfViewerController controller() =>
          tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;
      await mount();
      await _pumpNativeUntil(tester, () => controller().isReady);
      // Queue a real adapter navigation, then let pdfrx complete its animation.
      unawaited(engine.goToLocation(const BookLocation(locator: '2')));
      await _pumpNativeUntil(tester, () => controller().pageNumber == 2);
      settings = settings.copyWith(backgroundColor: 0xFFF1E7CF);
      final selected = await tester.runAsync(
        () async => controller().useDocument((document) async {
          final text = await document.pages[2].loadText();
          final start = text.fullText.indexOf('Bottom target text');
          return PdfReaderSelection.fromTextSelections([
            PdfTextRanges(
              pageText: text,
              ranges: [
                PdfTextRange(
                  start: start,
                  end: start + 'Bottom target text'.length,
                ),
              ],
            ),
          ])!;
        }),
      );
      final locator = selected!.location.encode();
      highlights = [
        {'highlightId': 'saved', 'location': locator, 'color': '#FFFF00'},
      ];
      await mount();
      final zoomBeforeHighlight = controller().currentZoom;
      unawaited(engine.goToLocation(BookLocation(locator: locator)));
      await _pumpNativeUntil(tester, () => controller().pageNumber == 3);
      final target = controller().calcRectForRectInsidePage(
        pageNumber: 3,
        rect: selected.location.targetRect!,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(controller().visibleRect.overlaps(target), isTrue);
      expect(controller().currentZoom, closeTo(zoomBeforeHighlight, 0.000001));
      expect(controller().visibleRect.contains(target.topLeft), isTrue);
      expect(controller().visibleRect.contains(target.bottomRight), isTrue);
      expect(await _yellowPixelCount(tester, imageKey), greaterThan(20));
      // Removing a saved highlight must repaint the real viewer without reloading
      // the book or leaving its old geometry on screen.
      highlights = [];
      await mount();
      await tester.pump(const Duration(seconds: 1));
      expect(await _yellowPixelCount(tester, imageKey), 0);
      // Legacy upper bounds are clamped before entering pdfrx's page indexing.
      unawaited(engine.goToLocation(const BookLocation(locator: '999')));
      await tester.pump(const Duration(seconds: 1));
      expect(controller().pageNumber, 3);
      unawaited(engine.goToLocation(const BookLocation(locator: '0')));
      await tester.pump(const Duration(seconds: 1));
      expect(controller().pageNumber, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    },
    skip: nativeRequirement,
  );

  testWidgets(
    'native multi-click selection, deselection and PDF links do not compete with reader taps',
    (tester) async {
      Pdfrx.pdfiumModulePath = modulePath;
      final engine = PdfBookReaderEngine();
      await tester.runAsync(() => engine.loadBook(readerPdfFixtureBytes()));
      addTearDown(engine.dispose);
      var selectedText = '';
      String? selectedLocation;
      var panelsVisible = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: StatefulBuilder(
            builder: (context, update) => Stack(
              children: [
                engine.buildReaderWidget(
                  context: context,
                  initialLocation: const BookLocation(locator: '1'),
                  settings: const ReaderSettings(backgroundColor: 0xFFFFFFFF),
                  theme: Theme.of(context),
                  onProgressChanged: (location, percentage) {},
                  onTextSelected: (text, location) => update(() {
                    selectedText = text;
                    selectedLocation = location.locator;
                  }),
                  onCenterTapped: () =>
                      update(() => panelsVisible = !panelsVisible),
                ),
                if (selectedText.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    child: IgnorePointer(
                      child: Text('Selected: ${selectedText.trim()}'),
                    ),
                  ),
                if (panelsVisible)
                  const Positioned(
                    bottom: 25,
                    child: IgnorePointer(child: Text('Reader controls')),
                  ),
              ],
            ),
          ),
        ),
      );
      PdfViewerController controller() =>
          tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;
      await _pumpNativeUntil(tester, () => controller().isReady);
      final pageText = await tester.runAsync(
        () async => controller().useDocument(
          (document) => document.pages.first.loadText(),
        ),
      );
      // Wait for the actual PDF text to load and register its selectable.
      // Controller readiness alone precedes native text-overlay readiness.
      final firstPageOverlay = find.byWidgetPredicate(
        (widget) => widget is PdfPageTextOverlay && widget.page.pageNumber == 1,
      );
      await _pumpNativeUntil(
        tester,
        () =>
            firstPageOverlay.evaluate().isNotEmpty &&
            tester
                .widget<PdfPageTextOverlay>(firstPageOverlay)
                .selectables
                .containsKey(1),
      );
      final wordStart = pageText!.fullText.indexOf('alpha');
      final word = PdfTextRangeWithFragments.fromTextRange(
        pageText,
        wordStart,
        wordStart + 'alpha'.length,
      )!;
      Offset globalPdfPoint(double x, double y) {
        final rect = controller().calcRectForRectInsidePage(
          pageNumber: 1,
          rect: PdfRect(x, y + 1, x + 1, y),
        );
        return controller().documentToGlobal(rect.center)!;
      }

      final wordRect = controller().calcRectForRectInsidePage(
        pageNumber: 1,
        rect: word.bounds,
      );
      final wordPosition = controller().documentToGlobal(wordRect.center)!;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final pointerEpoch = tester.binding.clock.now();
      Duration pointerTime() =>
          tester.binding.clock.now().difference(pointerEpoch);
      await mouse.addPointer(location: Offset.zero, timeStamp: pointerTime());
      addTearDown(() => mouse.removePointer(timeStamp: pointerTime()));
      Future<void> clickAt(Offset position) async {
        // pdfrx enables the native text hit target only after MouseRegion hover.
        // Reuse a real mouse and pump that hover rebuild before pressing.
        await mouse.moveTo(position, timeStamp: pointerTime());
        await tester.pump();
        await mouse.down(position, timeStamp: pointerTime());
        await tester.pump(const Duration(milliseconds: 10));
        await mouse.up(timeStamp: pointerTime());
      }

      Future<void> clickWord() => clickAt(wordPosition);
      // A collapsed caret click must stay empty, not become a synthetic range.
      await clickWord();
      await _pumpNativeUntil(tester, () => panelsVisible);
      expect(selectedText, isEmpty);
      await clickAt(globalPdfPoint(250, 260));
      await _pumpNativeUntil(tester, () => !panelsVisible);
      await tester.pump(const Duration(milliseconds: 400));

      await clickWord();
      await tester.pump(const Duration(milliseconds: 70));
      await clickWord();
      await _pumpNativeUntil(tester, () => selectedText.trim() == 'alpha');
      expect(find.text('Selected: alpha'), findsOneWidget);
      expect(find.text('Reader controls'), findsNothing);
      final saved = PdfReaderLocation.tryParse(selectedLocation!)!;
      expect(saved.isSelection, isTrue);
      expect(saved.pageNumber, 1);
      final range = saved.selections.single.ranges.single;
      expect(
        pageText.fullText.substring(range.start, range.end).trim(),
        'alpha',
      );

      // A fresh native triple click must not be turned into a reader single tap.
      // pdfrx 1.3.5 has no selectParagraph support; it may clear native selection.
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 3; i++) {
        await clickWord();
        await tester.pump(const Duration(milliseconds: 70));
      }
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Reader controls'), findsNothing);

      await clickWord();
      await tester.pump(const Duration(milliseconds: 70));
      await clickWord();
      await _pumpNativeUntil(tester, () => selectedText.trim() == 'alpha');
      await tester.pump(const Duration(milliseconds: 400));
      final blank = globalPdfPoint(250, 260);
      expect(tester.getRect(find.byType(PdfViewer)).contains(blank), isTrue);
      await clickAt(blank);
      await _pumpNativeUntil(
        tester,
        () => selectedText.isEmpty && panelsVisible,
      );
      expect(find.text('Selected: alpha'), findsNothing);
      expect(PdfReaderLocation.tryParse(selectedLocation!)!.encode(), '1');

      // The fixture's actual PDF annotation targets page three. Its confirmed
      // single click must navigate instead of toggling application controls.
      await tester.pump(const Duration(milliseconds: 400));
      await clickAt(globalPdfPoint(100, 310));
      await _pumpNativeUntil(tester, () => controller().pageNumber == 3);
      expect(find.text('Reader controls'), findsOneWidget);

      unawaited(engine.goToLocation(const BookLocation(locator: '1')));
      await _pumpNativeUntil(
        tester,
        () =>
            controller().pageNumber == 1 &&
            firstPageOverlay.evaluate().isNotEmpty &&
            tester
                .widget<PdfPageTextOverlay>(firstPageOverlay)
                .selectables
                .containsKey(1),
      );
      await tester.pump(const Duration(milliseconds: 400));
      Rect globalTextRect(int start, int end) {
        final range = PdfTextRangeWithFragments.fromTextRange(
          pageText,
          start,
          end,
        )!;
        final rect = controller().calcRectForRectInsidePage(
          pageNumber: 1,
          rect: range.bounds,
        );
        return Rect.fromPoints(
          controller().documentToGlobal(rect.topLeft)!,
          controller().documentToGlobal(rect.bottomRight)!,
        );
      }

      Future<void> dragText(Offset start, Offset end, String expected) async {
        if (selectedText.isNotEmpty) {
          final previousPanels = panelsVisible;
          await clickAt(globalPdfPoint(250, 260));
          await _pumpNativeUntil(
            tester,
            () => selectedText.isEmpty && panelsVisible != previousPanels,
          );
        }
        final previousPanels = panelsVisible;
        final viewport = tester.getRect(find.byType(PdfViewer));
        expect(viewport.contains(start), isTrue);
        expect(viewport.contains(end), isTrue);
        await mouse.moveTo(start, timeStamp: pointerTime());
        await tester.pump(const Duration(milliseconds: 100));
        await mouse.down(start, timeStamp: pointerTime());
        await tester.pump(const Duration(milliseconds: 10));
        for (var step = 1; step <= 10; step++) {
          await tester.pump(const Duration(milliseconds: 25));
          await mouse.moveTo(
            Offset.lerp(start, end, step / 10)!,
            timeStamp: pointerTime(),
          );
        }
        await mouse.up(timeStamp: pointerTime());
        await _pumpNativeUntil(tester, () => selectedText == expected);
        expect(panelsVisible, previousPanels);
        final location = PdfReaderLocation.tryParse(selectedLocation!)!;
        final storedText = location.selections.single.ranges
            .map((range) => pageText.fullText.substring(range.start, range.end))
            .join();
        expect(storedText, expected);
        expect(
          tester
              .widget<PdfPageTextOverlay>(firstPageOverlay)
              .selectables[1]!
              .selectedRanges
              .text,
          expected,
        );
      }

      const phrase = 'Highlight this sentence';
      final phraseStart = pageText.fullText.indexOf(phrase);
      final phraseRect = globalTextRect(
        phraseStart,
        phraseStart + phrase.length,
      );
      // Equal Y is intentional: pdfrx 1.3.5 used to reject this non-collapsed
      // selection because its edge rectangle had zero height.
      final phraseLeft = phraseRect.centerLeft + const Offset(0.5, 0);
      final phraseRight = phraseRect.centerRight - const Offset(0.5, 0);
      expect(phraseLeft.dy, phraseRight.dy);
      await dragText(phraseLeft, phraseRight, phrase);
      await dragText(phraseRight, phraseLeft, phrase);
      await dragText(
        phraseLeft - const Offset(0, 1),
        phraseRight + const Offset(0, 1),
        phrase,
      );

      const firstLine = 'Page one alpha bravo';
      const secondLine = 'Jump to final page';
      final firstStart = pageText.fullText.indexOf(firstLine);
      final secondStart = pageText.fullText.indexOf(secondLine);
      final firstRect = globalTextRect(
        firstStart,
        firstStart + firstLine.length,
      );
      final secondRect = globalTextRect(
        secondStart,
        secondStart + secondLine.length,
      );
      await dragText(
        firstRect.centerLeft + const Offset(0.5, 0),
        secondRect.centerRight - const Offset(0.5, 0),
        pageText.fullText.substring(
          firstStart,
          secondStart + secondLine.length,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    },
    skip: nativeRequirement,
  );

  test(
    'invalid PDF bytes fail loading rather than creating an apparently loaded reader',
    () async {
      Pdfrx.pdfiumModulePath = modulePath;
      final engine = PdfBookReaderEngine();
      addTearDown(engine.dispose);
      await expectLater(
        engine.loadBook(Uint8List.fromList([1, 2, 3, 4])),
        throwsException,
      );
    },
    skip: nativeRequirement,
  );
}
