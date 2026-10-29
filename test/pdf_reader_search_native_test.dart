import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/reader/domain/engine/pdf_book_reader_engine.dart';
import 'package:lira/features/reader/domain/models/book_location.dart';
import 'package:lira/features/reader/domain/models/book_search.dart';
import 'package:pdf_engine/pdf_engine.dart';
import 'package:pdfrx/pdfrx.dart';

import '../packages/pdf_engine/test/support/pdf_fixture.dart';

Future<void> _waitUntil(bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Real PDFium operation did not complete');
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (ready()) return;
  }
  fail('Real PDF viewer did not reach the expected state');
}

Future<int> _yellowPixels(WidgetTester tester, GlobalKey key) async {
  final bytes = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  });
  final pixels = bytes!.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  var yellow = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i] - pixels[i + 2] > 50 && pixels[i + 1] - pixels[i + 2] > 50) {
      yellow++;
    }
  }
  return yellow;
}

/// Records ownership while every document, page and text load is real PDFium.
/// A gate can delay returning an already-opened native document, not its data.
class _RecordingPdfFactory implements PdfDocumentFactory {
  _RecordingPdfFactory(this.delegate);

  final PdfDocumentFactory delegate;
  final documents = <PdfDocument>[];
  final disposed = <PdfDocument>{};
  Completer<void>? pauseNextOpen;
  _TextLoadGate? gateNextDocumentText;

  int get activeDocuments => documents.length - disposed.length;

  @override
  Future<PdfDocument> openData(
    Uint8List data, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
    String? sourceName,
    bool allowDataOwnershipTransfer = false,
    void Function()? onDispose,
  }) async {
    final pause = pauseNextOpen;
    pauseNextOpen = null;
    final textGate = gateNextDocumentText;
    gateNextDocumentText = null;
    late final PdfDocument document;
    document = await delegate.openData(
      data,
      passwordProvider: passwordProvider,
      firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
      useProgressiveLoading: useProgressiveLoading,
      sourceName: sourceName,
      allowDataOwnershipTransfer: allowDataOwnershipTransfer,
      onDispose: () {
        disposed.add(document);
        onDispose?.call();
      },
    );
    documents.add(document);
    if (pause != null) await pause.future;
    return textGate == null ? document : _GatedDocument(document, textGate);
  }

  @override
  Future<PdfDocument> openAsset(
    String name, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
  }) => delegate.openAsset(
    name,
    passwordProvider: passwordProvider,
    firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
    useProgressiveLoading: useProgressiveLoading,
  );

  @override
  Future<PdfDocument> openFile(
    String filePath, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
  }) => delegate.openFile(
    filePath,
    passwordProvider: passwordProvider,
    firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
    useProgressiveLoading: useProgressiveLoading,
  );

  @override
  Future<PdfDocument> openCustom({
    required FutureOr<int> Function(Uint8List, int, int) read,
    required int fileSize,
    required String sourceName,
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
    int? maxSizeToCacheOnMemory,
    void Function()? onDispose,
  }) => delegate.openCustom(
    read: read,
    fileSize: fileSize,
    sourceName: sourceName,
    passwordProvider: passwordProvider,
    firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
    useProgressiveLoading: useProgressiveLoading,
    maxSizeToCacheOnMemory: maxSizeToCacheOnMemory,
    onDispose: onDispose,
  );

  @override
  Future<PdfDocument> openUri(
    Uri uri, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
    PdfDownloadProgressCallback? progressCallback,
    bool preferRangeAccess = false,
    Map<String, String>? headers,
    bool withCredentials = false,
  }) => delegate.openUri(
    uri,
    passwordProvider: passwordProvider,
    firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
    useProgressiveLoading: useProgressiveLoading,
    progressCallback: progressCallback,
    preferRangeAccess: preferRangeAccess,
    headers: headers,
    withCredentials: withCredentials,
  );
}

class _TextLoadGate {
  final started = Completer<void>();
  final release = Completer<void>();
  bool claimed = false;
}

/// Only delays completion of a real native extraction so lifecycle races are
/// deterministic. All document/page APIs delegate to the actual PDFium objects.
class _GatedDocument extends PdfDocument {
  _GatedDocument(this.delegate, this.gate)
    : super(sourceName: delegate.sourceName);

  final PdfDocument delegate;
  final _TextLoadGate gate;

  @override
  PdfPermissions? get permissions => delegate.permissions;
  @override
  bool get isEncrypted => delegate.isEncrypted;
  @override
  Stream<PdfDocumentEvent> get events => delegate.events;
  @override
  late final List<PdfPage> pages = [
    for (final page in delegate.pages) _GatedPage(this, page, gate),
  ];
  @override
  Future<void> dispose() => delegate.dispose();
  @override
  Future<List<PdfOutlineNode>> loadOutline() => delegate.loadOutline();
  @override
  bool isIdenticalDocumentHandle(Object? other) =>
      delegate.isIdenticalDocumentHandle(
        other is _GatedDocument ? other.delegate : other,
      );
  @override
  Future<void> loadPagesProgressively<T>({
    PdfPageLoadingCallback<T>? onPageLoadProgress,
    T? data,
    Duration loadUnitDuration = const Duration(milliseconds: 250),
  }) => delegate.loadPagesProgressively(
    onPageLoadProgress: onPageLoadProgress,
    data: data,
    loadUnitDuration: loadUnitDuration,
  );
}

class _GatedPage extends PdfPage {
  _GatedPage(this.document, this.delegate, this.gate);

  final PdfPage delegate;
  final _TextLoadGate gate;
  @override
  final PdfDocument document;
  @override
  int get pageNumber => delegate.pageNumber;
  @override
  double get width => delegate.width;
  @override
  double get height => delegate.height;
  @override
  PdfPageRotation get rotation => delegate.rotation;
  @override
  bool get isLoaded => delegate.isLoaded;
  @override
  Future<PdfPageText> loadText() async {
    final nativeText = delegate.loadText();
    if (!gate.claimed) {
      gate.claimed = true;
      gate.started.complete();
      await gate.release.future;
    }
    return await nativeText;
  }

  @override
  PdfPageRenderCancellationToken createCancellationToken() =>
      delegate.createCancellationToken();
  @override
  Future<List<PdfLink>> loadLinks({
    bool compact = false,
    bool enableAutoLinkDetection = true,
  }) => delegate.loadLinks(
    compact: compact,
    enableAutoLinkDetection: enableAutoLinkDetection,
  );
  @override
  Future<PdfImage?> render({
    int x = 0,
    int y = 0,
    int? width,
    int? height,
    double? fullWidth,
    double? fullHeight,
    Color? backgroundColor,
    PdfAnnotationRenderingMode annotationRenderingMode =
        PdfAnnotationRenderingMode.annotationAndForms,
    int flags = PdfPageRenderFlags.none,
    PdfPageRenderCancellationToken? cancellationToken,
  }) => delegate.render(
    x: x,
    y: y,
    width: width,
    height: height,
    fullWidth: fullWidth,
    fullHeight: fullHeight,
    backgroundColor: backgroundColor,
    annotationRenderingMode: annotationRenderingMode,
    flags: flags,
    cancellationToken: cancellationToken,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final modulePath = Platform.environment['PDFIUM_PATH'];
  final nativeRequirement = modulePath == null;
  late PdfDocumentFactory nativeFactory;
  late _RecordingPdfFactory factory;

  setUp(() {
    Pdfrx.pdfiumModulePath = modulePath;
    nativeFactory = PdfDocumentFactory.instance;
    factory = _RecordingPdfFactory(nativeFactory);
    PdfDocumentFactory.instance = factory;
  });
  tearDown(() {
    PdfDocumentFactory.instance = nativeFactory;
  });

  PdfBookReaderEngine createEngine() {
    final engine = PdfBookReaderEngine();
    addTearDown(() async {
      engine.dispose();
      await _waitUntil(() => factory.activeDocuments == 0);
    });
    return engine;
  }

  test(
    'pre-mount PDF search returns all repeated ranges and native rectangles in order',
    () async {
      final engine = createEngine();
      await engine.loadBook(searchPdfFixtureBytes());
      final results = await engine.search(BookSearchRequest('REPEAT target'));
      expect(results.hasText, isTrue);
      expect(results.matches.map((match) => match.pageNumber), [1, 1, 1, 2]);
      expect(results.matches.map((match) => match.sectionIndex), [0, 0, 0, 1]);
      expect(
        results.matches.map((match) => match.location.locator).toSet(),
        hasLength(4),
      );
      expect(factory.documents, hasLength(1));
      final document = factory.documents.single;
      final locations = <PdfReaderLocation>[];
      for (final match in results.matches) {
        final location = PdfReaderLocation.tryParse(match.location.locator)!;
        locations.add(location);
        expect(location.isSelection, isTrue);
        final range = location.selections.single.ranges.single;
        expect(
          range,
          PdfTextRange(start: match.excerpt.start, end: match.excerpt.end),
        );
        final pageText = await document.pages[location.pageNumber - 1]
            .loadText();
        expect(
          pageText.fullText.substring(range.start, range.end).toLowerCase(),
          'repeat target',
        );
        expect(
          location.selections.single.rects,
          range
              .toTextRangeWithFragments(pageText)!
              .enumerateRectsForRange()
              .where((rect) => rect.isNotEmpty)
              .toList(),
        );
      }
      expect(
        locations[0].selections.single.ranges.single.start,
        lessThan(locations[1].selections.single.ranges.single.start),
      );
      expect(
        locations[1].selections.single.ranges.single.start,
        lessThan(locations[2].selections.single.ranges.single.start),
      );
      expect(
        locations[0].targetRect!.left,
        lessThan(locations[1].targetRect!.left),
      );
      expect(
        locations[0].targetRect!.top,
        greaterThan(locations[2].targetRect!.top),
      );
      final absent = await engine.search(BookSearchRequest('not in this PDF'));
      expect(absent.matches, isEmpty);
      expect(absent.hasText, isTrue);
      expect(factory.documents, hasLength(1));
    },
    skip: nativeRequirement,
  );

  test(
    'PDF whitespace phrase keeps original text offsets and both line rectangles',
    () async {
      final engine = createEngine();
      await engine.loadBook(searchPdfFixtureBytes());
      final results = await engine.search(
        BookSearchRequest('  WHITEspace \n phrase  '),
      );
      final match = results.matches.single;
      expect(match.excerpt.text, 'Whitespace phrase');
      final location = PdfReaderLocation.tryParse(match.location.locator)!;
      final range = location.selections.single.ranges.single;
      final text = await factory.documents.single.pages.first.loadText();
      expect(
        text.fullText.substring(range.start, range.end),
        matches(RegExp(r'^Whitespace\s+phrase$')),
      );
      expect(location.selections.single.rects.length, greaterThanOrEqualTo(2));
      expect(
        location.selections.single.rects.first.top,
        greaterThan(location.selections.single.rects.last.top),
      );
    },
    skip: nativeRequirement,
  );

  test(
    'graphics-only PDF has no text layer and does not manufacture OCR results',
    () async {
      final engine = createEngine();
      await engine.loadBook(searchPdfFixtureBytes(hasText: false));
      final results = await engine.search(BookSearchRequest('target'));
      expect(results.matches, isEmpty);
      expect(results.hasText, isFalse);
    },
    skip: nativeRequirement,
  );

  test(
    'cancelled and closed PDF searches discard results and release owned documents',
    () async {
      final engine = createEngine();
      await engine.loadBook(searchPdfFixtureBytes());
      final alreadyCancelled = BookSearchRequest('repeat')..cancel();
      expect((await engine.search(alreadyCancelled)).matches, isEmpty);
      final request = BookSearchRequest('repeat');
      final pending = engine.search(request);
      await Future<void>.value();
      request.cancel();
      expect((await pending).matches, isEmpty);
      // The pre-mount document remains engine-owned, not query-owned.
      expect(factory.activeDocuments, 1);
      expect(
        (await engine.search(BookSearchRequest('repeat'))).matches,
        hasLength(4),
      );
      final closing = engine.search(BookSearchRequest('repeat'));
      await Future<void>.value();
      engine.dispose();
      expect((await closing).matches, isEmpty);
      await _waitUntil(() => factory.activeDocuments == 0);
      expect(
        (await engine.search(BookSearchRequest('repeat'))).matches,
        isEmpty,
      );
    },
    skip: nativeRequirement,
  );
  for (final closeBook in [false, true]) {
    test('${closeBook ? 'closing' : 'cancelling'} during native extraction '
        'discards matches without disposing an active document', () async {
      final engine = createEngine();
      final gate = _TextLoadGate();
      factory.gateNextDocumentText = gate;
      addTearDown(() {
        if (!gate.release.isCompleted) gate.release.complete();
      });
      await engine.loadBook(searchPdfFixtureBytes());
      final request = BookSearchRequest('repeat target');
      final pending = engine.search(request);
      await gate.started.future;
      if (closeBook) {
        engine.dispose();
      } else {
        request.cancel();
      }
      // Native extraction has started; closing must wait for its lease.
      expect(factory.activeDocuments, 1);
      expect(factory.disposed, isEmpty);
      gate.release.complete();
      expect((await pending).matches, isEmpty);
      if (!closeBook) {
        expect(
          (await engine.search(BookSearchRequest('repeat'))).matches,
          hasLength(4),
        );
        engine.dispose();
      }
      await _waitUntil(() => factory.activeDocuments == 0);
    }, skip: nativeRequirement);
  }

  test(
    'replacing a PDF invalidates an active search without closing the new document',
    () async {
      final engine = createEngine();
      final gate = _TextLoadGate();
      factory.gateNextDocumentText = gate;
      addTearDown(() {
        if (!gate.release.isCompleted) gate.release.complete();
      });
      await engine.loadBook(searchPdfFixtureBytes());
      final firstDocument = factory.documents.single;
      final pending = engine.search(BookSearchRequest('repeat'));
      await gate.started.future;
      await engine.loadBook(searchPdfFixtureBytes(hasText: false));
      expect(factory.activeDocuments, 2);
      gate.release.complete();
      expect((await pending).matches, isEmpty);
      final current = await engine.search(BookSearchRequest('repeat'));
      expect(current.matches, isEmpty);
      expect(current.hasText, isFalse);
      await _waitUntil(() => factory.disposed.contains(firstDocument));
      expect(factory.documents, hasLength(2));
      expect(factory.activeDocuments, 1);
    },
    skip: nativeRequirement,
  );

  test(
    'closing during native PDF opening disposes the late document instead of resurrecting it',
    () async {
      final engine = createEngine();
      final gate = Completer<void>();
      factory.pauseNextOpen = gate;
      final loading = engine.loadBook(searchPdfFixtureBytes());
      await _waitUntil(() => factory.documents.isNotEmpty);
      engine.dispose();
      gate.complete();
      await loading;
      await _waitUntil(() => factory.activeDocuments == 0);
      expect(
        (await engine.search(BookSearchRequest('repeat'))).matches,
        isEmpty,
      );
    },
    skip: nativeRequirement,
  );

  testWidgets(
    'mounted PDF search reuses the live document and exact results navigate and paint temporarily',
    (tester) async {
      final engine = PdfBookReaderEngine();
      await tester.runAsync(() => engine.loadBook(searchPdfFixtureBytes()));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        engine.dispose();
        await tester.runAsync(
          () => _waitUntil(() => factory.activeDocuments == 0),
        );
      });
      final imageKey = GlobalKey();
      var highlights = <Map<String, dynamic>>[];
      Future<void> mount() => tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: imageKey,
            child: Builder(
              builder: (context) => engine.buildReaderWidget(
                context: context,
                initialLocation: const BookLocation(locator: '1'),
                settings: const ReaderSettings(),
                theme: Theme.of(context),
                onProgressChanged: (_, _) {},
                onTextSelected: (_, _) {},
                highlights: highlights,
              ),
            ),
          ),
        ),
      );
      await mount();
      final controller = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      await _pumpUntil(tester, () => controller.isReady);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => _waitUntil(() => factory.activeDocuments == 1),
      );
      expect(factory.documents, hasLength(2));
      final reference = controller.documentRef;
      final document = reference.resolveListenable().document!;
      final page = controller.pageNumber;
      final results = (await tester.runAsync(
        () => engine.search(BookSearchRequest('repeat target')),
      ))!;
      expect(results.matches, hasLength(4));
      expect(controller.pageNumber, page);
      expect(controller.documentRef, same(reference));
      expect(reference.resolveListenable().document, same(document));
      expect(factory.documents, hasLength(2));
      final target = results.matches.last;
      final location = PdfReaderLocation.tryParse(target.location.locator)!;
      unawaited(engine.goToLocation(target.location));
      await _pumpUntil(tester, () => controller.pageNumber == 2);
      await tester.pumpAndSettle();
      final targetRect = controller.calcRectForRectInsidePage(
        pageNumber: location.pageNumber,
        rect: location.targetRect!,
      );
      expect(controller.visibleRect.contains(targetRect.center), isTrue);
      final before = await _yellowPixels(tester, imageKey);
      highlights = [
        {'location': target.location.locator, 'color': '#FFFF00'},
      ];
      await mount();
      await tester.pumpAndSettle();
      expect(await _yellowPixels(tester, imageKey), greaterThan(before + 100));
      highlights = [];
      await mount();
      await tester.pumpAndSettle();
      expect(await _yellowPixels(tester, imageKey), before);
      expect(controller.documentRef, same(reference));
      expect(reference.resolveListenable().document, same(document));
      expect(factory.documents, hasLength(2));
    },
    skip: nativeRequirement,
  );
}
