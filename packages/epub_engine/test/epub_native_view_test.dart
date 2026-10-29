import 'dart:convert';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

ParsedEpub _book() => ParsedEpub(
  title: 'Reader regression book',
  author: 'Lira',
  chapters: [
    for (final name in ['FIRST', 'SECOND', 'THIRD'])
      EpubChapter(
        title: name,
        fileName: '${name.toLowerCase()}.xhtml',
        htmlContent:
            '<html><body><h1>$name CHAPTER</h1>'
            '${List.generate(12, (i) => '<p>$name paragraph $i. ${'Readable content. ' * 8}</p>').join()}'
            '</body></html>',
      ),
  ],
  toc: const [],
  images: const {},
);

String _renderedText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((widget) => widget.text.toPlainText())
    .join('\n');

Widget _frame(Widget child, {Size size = const Size(600, 400)}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: size.width, height: size.height, child: child),
  ),
);

Future<ParsedEpub> _encodedHrefBook() async {
  final files = <String, String>{
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
    'OEBPS/content.opf':
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:title>Encoded links</dc:title></metadata><manifest>'
        '<item id="first" href="text%20dir/first%20chapter.xhtml" media-type="application/xhtml+xml"/>'
        '<item id="second" href="text%20dir/second%20chapter.xhtml" media-type="application/xhtml+xml"/>'
        '</manifest><spine><itemref idref="first"/><itemref idref="second"/></spine></package>',
    'OEBPS/text dir/first chapter.xhtml':
        '<html><body><p>'
        '<a href="../text%20dir/second%20chapter.xhtml#deep%20anchor">'
        'Open destination</a></p></body></html>',
    'OEBPS/text dir/second chapter.xhtml':
        '<html><body>'
        '<p>${'Before destination. ' * 100}</p>'
        '<p id="deep anchor">DEEP DESTINATION</p></body></html>',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return EpubParser.parse(Uint8List.fromList(ZipEncoder().encode(archive)!));
}

String _topVisibleText(WidgetTester tester) {
  RenderParagraph? first;
  var firstTop = double.infinity;
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject! as RenderParagraph;
    final top = render.localToGlobal(Offset.zero).dy;
    if (top + render.size.height <= 24 || top >= 400 || top >= firstTop)
      continue;
    first = render;
    firstTop = top;
  }
  if (first == null) return '';
  final position = first.getPositionForOffset(
    Offset(0, (24 - firstTop).clamp(0.0, double.infinity)),
  );
  final text = first.text.toPlainText();
  final end = (position.offset + 200).clamp(0, text.length);
  return text.substring(position.offset, end);
}

ParsedEpub _htmlBook(String html, {Map<String, Uint8List> images = const {}}) =>
    ParsedEpub(
      title: 'Layout regressions',
      author: 'Lira',
      chapters: [
        EpubChapter(
          title: 'Chapter',
          fileName: 'OEBPS/text/chapter.xhtml',
          htmlContent: '<html><body>$html</body></html>',
        ),
      ],
      toc: const [],
      images: images,
    );

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );

Iterable<RenderParagraph> _visibleParagraphs(
  WidgetTester tester,
  Rect viewport,
) sync* {
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.attached || !render.hasSize) {
      continue;
    }
    final bounds = render.localToGlobal(Offset.zero) & render.size;
    if (bounds.overlaps(viewport)) yield render;
  }
}

void _expectFragmentVisible(
  WidgetTester tester,
  String fragment,
  Rect viewport,
) {
  final boxes = <Rect>[];
  for (final paragraph in _visibleParagraphs(tester, viewport)) {
    final index = paragraph.text.toPlainText().indexOf(fragment);
    if (index < 0) continue;
    boxes.addAll(
      paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: index,
              extentOffset: index + fragment.length,
            ),
          )
          .map(
            (box) => box.toRect().shift(paragraph.localToGlobal(Offset.zero)),
          ),
    );
  }
  expect(
    boxes.any((box) => box.overlaps(viewport)),
    isTrue,
    reason: 'The saved text must be painted in every transitional frame',
  );
}

Future<void> _pumpEveryFrame(WidgetTester tester, VoidCallback check) async {
  var frames = 0;
  do {
    await tester.pump(const Duration(milliseconds: 16));
    check();
    frames++;
    expect(
      frames,
      lessThan(30),
      reason: 'Reflow must settle without a frame loop',
    );
  } while (tester.binding.hasScheduledFrame);
}

Future<void> _tapFirstGlyph(WidgetTester tester, String text) {
  final paragraph = _paragraph(tester, text);
  final box = paragraph
      .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1))
      .first;
  return tester.tapAt(paragraph.localToGlobal(box.toRect().center));
}

Rect _cellRect(WidgetTester tester, String text) => tester.getRect(
  find.ancestor(of: find.text(text), matching: find.byType(Positioned)).first,
);

Future<Uint8List> _rasterBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xffff0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<void> _selectTextRange(
  WidgetTester tester,
  String startText,
  String endText,
) async {
  final start = _paragraph(tester, startText);
  final end = _paragraph(tester, endText);
  final first = start
      .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1))
      .first;
  final last = end
      .getBoxesForSelection(
        TextSelection(
          baseOffset: endText.length - 1,
          extentOffset: endText.length,
        ),
      )
      .last;
  final gesture = await tester.startGesture(
    start.localToGlobal(Offset(first.left + 1, (first.top + first.bottom) / 2)),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.moveTo(
    end.localToGlobal(Offset(last.right - 1, (last.top + last.bottom) / 2)),
  );
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('overlapping highlights preserve the original text exactly', (
    tester,
  ) async {
    const text = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final book = ParsedEpub(
      title: 'Highlights',
      author: 'Lira',
      chapters: [
        EpubChapter(
          title: 'Chapter',
          fileName: 'chapter.xhtml',
          htmlContent: '<p>$text</p>',
        ),
      ],
      toc: const [],
      images: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EpubNativeView(
          epub: book,
          settings: const ReaderSettings(),
          theme: ThemeData.dark(),
          highlights: const [
            {
              'chapterIndex': 0,
              'startOffset': 2,
              'endOffset': 10,
              'color': '#FFEB3B',
            },
            {
              'chapterIndex': 0,
              'startOffset': 6,
              'endOffset': 15,
              'color': '#42A5F5',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_renderedText(tester).trim(), text);
  });

  testWidgets('switching to horizontal preserves the current chapter', (
    tester,
  ) async {
    final book = _book();
    final location = EpubLocation.fromPosition(chapterIndex: 1);
    final settings = ValueNotifier(const ReaderSettings());
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReaderSettings>(
          valueListenable: settings,
          builder: (context, value, _) => EpubNativeView(
            epub: book,
            initialLocation: location,
            settings: value,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_renderedText(tester), contains('SECOND CHAPTER'));
    settings.value = settings.value.copyWith(
      readingMode: ReadingMode.horizontal,
      enableDualPageSpread: false,
    );
    await tester.pumpAndSettle();
    expect(_renderedText(tester), contains('SECOND CHAPTER'));
    expect(_renderedText(tester), isNot(contains('FIRST CHAPTER')));
  });

  testWidgets(
    'logical text position survives reflow, resize and persisted updates',
    (tester) async {
      final book = _book();
      final blocks = XhtmlParser(
        html: book.chapters[1].htmlContent,
        images: const {},
        baseStyle: const TextStyle(fontSize: 18),
      ).parse().whereType<TextBlock>();
      final offset = blocks
          .firstWhere(
            (block) =>
                block.span.toPlainText().startsWith('SECOND paragraph 6.'),
          )
          .charStart;
      final key = GlobalKey<EpubNativeViewState>();
      var settings = const ReaderSettings(
        readingMode: ReadingMode.horizontal,
        enableDualPageSpread: false,
      );
      var size = const Size(600, 400);
      var initial = EpubLocation.fromPosition(chapterIndex: 0);
      EpubLocation? latest;
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _frame(
              EpubNativeView(
                key: key,
                epub: book,
                initialLocation: initial,
                settings: settings,
                theme: ThemeData.dark(),
                onLocationChanged: (location, _) => latest = location,
              ),
              size: size,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.goToLocation(
        EpubLocation.fromPosition(
          hasExactCharOffset: true,
          chapterIndex: 1,
          charOffset: offset,
        ),
      );
      await tester.pumpAndSettle();
      expect(_renderedText(tester), contains('SECOND paragraph 6.'));
      for (final updated in [
        settings.copyWith(fontSize: 25),
        settings.copyWith(fontFamily: 'serif'),
        settings.copyWith(fontSize: 25, lineHeight: 1.8),
        settings.copyWith(horizontalPadding: 56),
        settings.copyWith(readingMode: ReadingMode.vertical),
        settings.copyWith(readingMode: ReadingMode.horizontal),
        settings.copyWith(enableDualPageSpread: true),
      ]) {
        rebuild(() => settings = updated);
        await tester.pumpAndSettle();
        expect(latest!.chapterIndex, 1);
        expect(latest!.charOffset, offset);
        expect(_renderedText(tester), contains('SECOND paragraph 6.'));
      }
      rebuild(() => size = const Size(750, 500));
      await tester.pumpAndSettle();
      expect(latest!.charOffset, offset);
      expect(_renderedText(tester), contains('SECOND paragraph 6.'));
      rebuild(() => initial = EpubLocation.fromPosition(chapterIndex: 2));
      await tester.pumpAndSettle();
      expect(latest!.chapterIndex, 1);
      expect(_renderedText(tester), isNot(contains('THIRD CHAPTER')));
    },
  );

  testWidgets(
    'every reflow frame paints the saved text instead of chapter zero',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final book = _book();
      final blocks = XhtmlParser(
        html: book.chapters[1].htmlContent,
        images: const {},
        baseStyle: const TextStyle(fontSize: 18),
      ).parse().whereType<TextBlock>();
      final offset = blocks
          .firstWhere(
            (block) =>
                block.span.toPlainText().startsWith('SECOND paragraph 6.'),
          )
          .charStart;
      final target = EpubLocation.fromPosition(
        chapterIndex: 1,
        charOffset: offset,
        hasExactCharOffset: true,
      );
      final reports = <EpubLocation>[];
      var settings = const ReaderSettings();
      var size = const Size(1200, 500);
      late StateSetter rebuild;
      void checkFrame() {
        final viewport = Rect.fromLTWH(0, 24, size.width, size.height - 48);
        _expectFragmentVisible(tester, 'SECOND paragraph 6.', viewport);
        for (final paragraph in _visibleParagraphs(tester, viewport)) {
          expect(
            paragraph.text.toPlainText(),
            isNot(contains('FIRST CHAPTER')),
          );
        }
        for (final report in reports) {
          expect(report.hasExactCharOffset, isTrue);
          expect(report.chapterIndex, target.chapterIndex);
          expect(report.charOffset, target.charOffset);
        }
      }

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _frame(
              EpubNativeView(
                epub: book,
                initialLocation: target,
                settings: settings,
                theme: ThemeData.dark(),
                onLocationChanged: (location, _) => reports.add(location),
              ),
              size: size,
            );
          },
        ),
      );
      checkFrame();
      await _pumpEveryFrame(tester, checkFrame);
      for (final mode in [
        (ReadingMode.vertical, false),
        (ReadingMode.horizontal, false),
        (ReadingMode.horizontal, true),
        (ReadingMode.vertical, false),
      ]) {
        rebuild(() {
          settings = settings.copyWith(
            readingMode: mode.$1,
            enableDualPageSpread: mode.$2,
          );
        });
        await _pumpEveryFrame(tester, checkFrame);
        for (final update in [
          settings.copyWith(fontSize: 25),
          settings.copyWith(fontFamily: 'serif'),
          settings.copyWith(lineHeight: 1.9),
          settings.copyWith(horizontalPadding: 120),
          settings.copyWith(horizontalPadding: 240),
        ]) {
          rebuild(() => settings = update);
          await _pumpEveryFrame(tester, checkFrame);
        }
        for (final width in [440.0, 140.0, 1200.0]) {
          rebuild(() => size = Size(width, 500));
          await _pumpEveryFrame(tester, checkFrame);
        }
      }
      expect(reports, isNotEmpty);
      expect(settings.horizontalPadding, 240);
    },
  );

  for (final mode in [
    (ReadingMode.vertical, false, 'vertical'),
    (ReadingMode.horizontal, false, 'single page'),
    (ReadingMode.horizontal, true, 'spread'),
  ]) {
    testWidgets('reader typography controls actual ${mode.$3} line metrics', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final book = _htmlBook(
        '<style>body { line-height: 1.45; font-family: publisher; }'
        'p { font-size: 16px !important; line-height: 12px !important; }</style>'
        '<p>Metric probe. ${'readable metric content. ' * 180}</p>',
      );
      var settings = ReaderSettings(
        readingMode: mode.$1,
        enableDualPageSpread: mode.$2,
        fontSize: 18,
        lineHeight: 1.2,
        horizontalPadding: 20,
      );
      var size = const Size(1200, 500);
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _frame(
              EpubNativeView(
                epub: book,
                settings: settings,
                theme: ThemeData.dark(),
              ),
              size: size,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final typography in [
        (18.0, 1.2, 20.0),
        (24.0, 1.2, 20.0),
        (24.0, 1.9, 20.0),
        (24.0, 1.9, 120.0),
        (24.0, 1.9, 240.0),
      ]) {
        rebuild(() {
          settings = settings.copyWith(
            fontSize: typography.$1,
            lineHeight: typography.$2,
            horizontalPadding: typography.$3,
          );
        });
        await tester.pumpAndSettle();
        final pageWidth = mode.$2 ? size.width * .48 : 800.0;
        final effectivePadding = typography.$3.clamp(
          0.0,
          (pageWidth - 160) / 2,
        );
        final paragraphs =
            _visibleParagraphs(
                  tester,
                  Rect.fromLTWH(0, 24, size.width, size.height - 48),
                )
                .where(
                  (paragraph) =>
                      paragraph.text.toPlainText().contains('metric content'),
                )
                .toList();
        expect(paragraphs.length, mode.$2 ? 2 : 1);
        for (var index = 0; index < paragraphs.length; index++) {
          final paragraph = paragraphs[index];
          expect(
            paragraph.size.width,
            closeTo(pageWidth - effectivePadding * 2, .01),
          );
          final pageLeft = mode.$2
              ? index * (pageWidth + size.width * .04)
              : (size.width - pageWidth) / 2;
          expect(
            paragraph.localToGlobal(Offset.zero).dx - pageLeft,
            closeTo(effectivePadding, .01),
          );
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            textHeightBehavior: const TextHeightBehavior(),
          )..layout(maxWidth: paragraph.size.width);
          final lines = painter.computeLineMetrics();
          expect(lines.length, greaterThan(1));
          expect(painter.height, closeTo(paragraph.size.height, .01));
          expect(
            lines[1].baseline - lines[0].baseline,
            closeTo(typography.$1 * typography.$2, 1.01),
          );
          painter.dispose();
        }
      }
      // A saved desktop margin survives narrowing, but the rendered page
      // always retains 160px (or the full viewport when it is even narrower).
      for (final width in [440.0, 140.0]) {
        rebuild(() => size = Size(width, 500));
        await tester.pumpAndSettle();
        final paragraphs =
            _visibleParagraphs(tester, Rect.fromLTWH(0, 24, width, 452))
                .where(
                  (paragraph) =>
                      paragraph.text.toPlainText().contains('metric content'),
                )
                .toList();
        expect(paragraphs, isNotEmpty);
        expect(
          paragraphs.first.size.width,
          closeTo(width < 160 ? width : 160, .01),
        );
        expect(settings.horizontalPadding, 240);
      }
    });
  }

  for (final spread in [false, true]) {
    testWidgets(
      'short SVG packs between text on one ${spread ? 'spread' : 'single'} page',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final size = Size(spread ? 1000 : 360, 600);
        final book = _htmlBook(
          '<p style="margin: 0">BEFORE SVG</p>'
          '<img src="../images/wide.svg"/>'
          '<p style="margin: 0">AFTER SVG</p>',
          images: {
            'OEBPS/images/wide.svg': Uint8List.fromList(
              utf8.encode(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100">'
                '<rect width="400" height="100" fill="red"/></svg>',
              ),
            ),
          },
        );
        EpubLocation? latest;
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              epub: book,
              settings: ReaderSettings(
                readingMode: ReadingMode.horizontal,
                enableDualPageSpread: spread,
                horizontalPadding: 20,
              ),
              theme: ThemeData.dark(),
              onLocationChanged: (location, _) => latest = location,
            ),
            size: size,
          ),
        );
        await tester.pumpAndSettle();
        final before = tester.getRect(find.text('BEFORE SVG'));
        final image = tester.getRect(find.byType(SvgPicture));
        final after = tester.getRect(find.text('AFTER SVG'));
        final pageWidth = spread ? size.width * .48 : size.width;
        expect(before.width, closeTo(pageWidth - 40, .01));
        expect(image.width, closeTo(before.width, .01));
        expect(image.height, closeTo(image.width / 4, .01));
        expect(image.left, closeTo(before.left, .01));
        expect(after.left, closeTo(before.left, .01));
        expect(after.right, closeTo(before.right, .01));
        expect(before.top, greaterThanOrEqualTo(24));
        expect(image.top, greaterThanOrEqualTo(before.bottom));
        expect(after.top, greaterThanOrEqualTo(image.bottom));
        expect(after.bottom, lessThanOrEqualTo(size.height - 24));
        final offset = latest!.charOffset;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(latest!.charOffset, offset);
        expect(find.text('BEFORE SVG'), findsOneWidget);
        expect(find.text('AFTER SVG'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'spread margins constrain tables and images to the same page boxes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final book = _htmlBook(
        '<table><tr><td>LEFT CELL</td><td>RIGHT CELL</td></tr></table>'
        '<img src="../images/diagram.svg"/>',
        images: {
          'OEBPS/images/diagram.svg': Uint8List.fromList(
            utf8.encode(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 80">'
              '<rect width="160" height="80" fill="red"/></svg>',
            ),
          ),
        },
      );
      var settings = const ReaderSettings(
        readingMode: ReadingMode.horizontal,
        enableDualPageSpread: true,
      );
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _frame(
              EpubNativeView(
                epub: book,
                settings: settings,
                theme: ThemeData.dark(),
              ),
              size: const Size(1200, 500),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final requested in [20.0, 120.0, 240.0]) {
        rebuild(() {
          settings = settings.copyWith(horizontalPadding: requested);
        });
        await tester.pumpAndSettle();
        final padding = requested.clamp(0.0, (576 - 160) / 2);
        final table = _cellRect(
          tester,
          'LEFT CELL',
        ).expandToInclude(_cellRect(tester, 'RIGHT CELL'));
        final image = tester.getRect(find.byType(SvgPicture));
        expect(table.width, closeTo(576 - padding * 2, .01));
        expect(image.width, closeTo(table.width, .01));
        expect(table.left, closeTo(padding, .01));
        final imagePage = [
          const Rect.fromLTWH(0, 24, 576, 452),
          const Rect.fromLTWH(624, 24, 576, 452),
        ].singleWhere((page) => page.contains(image.center));
        expect(image.left, closeTo(imagePage.left + padding, .01));
        expect(image.right, lessThanOrEqualTo(imagePage.right - padding + .01));
        expect(image.top, greaterThanOrEqualTo(imagePage.top));
        expect(image.bottom, lessThanOrEqualTo(imagePage.bottom));
        expect(image.height, closeTo(image.width / 2, .01));
      }
    },
  );

  testWidgets(
    'a fitting styled paragraph uses the current page before continuing',
    (tester) async {
      final firstLines = List.generate(12, (index) => 'FIRST $index');
      final secondLines = List.generate(
        12,
        (index) => 'B${index.toString().padLeft(2, '0')} 😀 á 👩‍💻',
      );
      final firstText = firstLines.join('\n');
      final secondText = secondLines.join('\n');
      final book = _htmlBook(
        '<p style="margin: 0">${firstLines.join('<br/>')}</p>'
        '<p style="margin: 0">'
        '${secondLines.map((line) => '<b>$line</b>').join('<br/>')}</p>',
      );
      EpubLocation? latest;
      const viewport = Rect.fromLTWH(0, 24, 360, 552);
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            epub: book,
            settings: const ReaderSettings(
              readingMode: ReadingMode.horizontal,
              enableDualPageSpread: false,
              fontSize: 18,
              lineHeight: 1.5,
              horizontalPadding: 20,
            ),
            theme: ThemeData.dark(),
            onLocationChanged: (location, _) => latest = location,
          ),
          size: const Size(360, 600),
        ),
      );
      await tester.pumpAndSettle();
      final firstPage = _visibleParagraphs(tester, viewport).toList();
      expect(firstPage, hasLength(2));
      expect(firstPage.first.text.toPlainText(), firstText);
      final beginning = firstPage.last.text.toPlainText();
      expect(beginning, startsWith(secondLines.first));
      expect(beginning.length, lessThan(secondText.length));
      expect(secondText, startsWith(beginning));
      final fullParagraph = TextPainter(
        text: TextSpan(style: firstPage.last.text.style, text: secondText),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        textHeightBehavior: const TextHeightBehavior(),
      )..layout(maxWidth: firstPage.last.size.width);
      expect(fullParagraph.height, lessThan(viewport.height));
      expect(
        fullParagraph.height,
        greaterThan(viewport.height - firstPage.first.size.height),
      );
      fullParagraph.dispose();
      void checkFragments() {
        var styledUnicode = false;
        for (final paragraph in _visibleParagraphs(tester, viewport)) {
          final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
          expect(rect.top, greaterThanOrEqualTo(viewport.top));
          expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + .01));
          paragraph.text.visitChildren((span) {
            if (span is TextSpan && (span.text?.contains('😀') ?? false)) {
              expect(span.style?.fontWeight, FontWeight.bold);
              styledUnicode = true;
            }
            return true;
          });
        }
        expect(styledUnicode, isTrue);
      }

      checkFragments();
      final firstPageText = firstPage
          .map((paragraph) => paragraph.text.toPlainText())
          .join();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(latest!.hasExactCharOffset, isTrue);
      expect(latest!.charOffset, firstPageText.length);
      final continuation = _visibleParagraphs(
        tester,
        viewport,
      ).map((paragraph) => paragraph.text.toPlainText()).join();
      expect(firstPageText + continuation, firstText + secondText);
      checkFragments();
      final endOffset = latest!.charOffset;
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(latest!.charOffset, endOffset);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(latest!.charOffset, 0);
      expect(
        _visibleParagraphs(
          tester,
          viewport,
        ).map((paragraph) => paragraph.text.toPlainText()).join(),
        firstPageText,
      );
    },
  );

  testWidgets('a page with less than one line left advances without clipping', (
    tester,
  ) async {
    final lines = List.generate(13, (index) => 'BOUNDARY $index');
    final firstText = lines.join('\n');
    EpubLocation? latest;
    await tester.pumpWidget(
      _frame(
        EpubNativeView(
          epub: _htmlBook(
            '<p style="margin: 0">${lines.join('<br/>')}</p>'
            '<p style="margin: 0">NEXT FULL LINE</p>',
          ),
          settings: const ReaderSettings(
            readingMode: ReadingMode.horizontal,
            enableDualPageSpread: false,
            fontSize: 18,
            lineHeight: 1.5,
            horizontalPadding: 20,
          ),
          theme: ThemeData.dark(),
          onLocationChanged: (location, _) => latest = location,
        ),
        size: const Size(360, 400),
      ),
    );
    await tester.pumpAndSettle();
    expect(_renderedText(tester), firstText);
    final filledPage = tester.getRect(find.text(firstText));
    expect(filledPage.bottom, greaterThan(375 - .01));
    expect(filledPage.bottom, lessThanOrEqualTo(376.01));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(_renderedText(tester), 'NEXT FULL LINE');
    expect(latest!.hasExactCharOffset, isTrue);
    expect(latest!.charOffset, firstText.length);
    final nextLine = tester.getRect(find.text('NEXT FULL LINE'));
    expect(nextLine.top, greaterThanOrEqualTo(24));
    expect(nextLine.bottom, lessThanOrEqualTo(376.01));
    final offset = latest!.charOffset;
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(latest!.charOffset, offset);
  });

  testWidgets('styled paragraph pages concatenate to exact original text', (
    tester,
  ) async {
    final pieces = List.generate(
      100,
      (index) => '[$index] readable 😀 á content. ',
    );
    final book = ParsedEpub(
      title: 'Pagination',
      author: 'Lira',
      chapters: [
        EpubChapter(
          title: 'Chapter',
          fileName: 'chapter.xhtml',
          htmlContent:
              '<blockquote style="margin: 0">'
              '<p style="text-align: right; margin: 10px 24px 16px 32px">'
              '${List.generate(pieces.length, (index) => '<span style="font-size: ${index.isEven ? 22 : 30}px">'
                  '<b>${pieces[index]}</b></span>').join()}</p></blockquote>',
        ),
      ],
      toc: const [],
      images: const {},
    );
    var offset = -1;
    await tester.pumpWidget(
      _frame(
        EpubNativeView(
          epub: book,
          settings: const ReaderSettings(
            readingMode: ReadingMode.horizontal,
            enableDualPageSpread: false,
          ),
          theme: ThemeData.dark(),
          onLocationChanged: (location, _) => offset = location.charOffset,
        ),
        size: const Size(560, 360),
      ),
    );
    await tester.pumpAndSettle();
    final text = StringBuffer();
    double? paragraphLeft;
    double? paragraphWidth;
    for (var page = 0; page < 200; page++) {
      final paragraphs = tester.widgetList<RichText>(find.byType(RichText));
      text.write(paragraphs.map((widget) => widget.text.toPlainText()).join());
      for (final element in find.byType(RichText).evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
        paragraphLeft ??= rect.left;
        paragraphWidth ??= rect.width;
        expect(paragraph.textAlign, TextAlign.right);
        expect(rect.left, closeTo(paragraphLeft, 0.01));
        expect(rect.width, closeTo(paragraphWidth, 0.01));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(336.01));
        if (paragraph.text.toPlainText().endsWith(pieces.last)) {
          expect(rect.bottom, lessThanOrEqualTo(320.01));
        }
      }
      final previous = offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      if (offset == previous) break;
    }
    expect(text.toString(), pieces.join());
  });

  testWidgets('right-page fragment remains the logical spread destination', (
    tester,
  ) async {
    final book = ParsedEpub(
      title: 'Spread',
      author: 'Lira',
      chapters: [
        EpubChapter(
          title: 'First',
          fileName: 'OEBPS/text/first.xhtml',
          htmlContent: '<p>FIRST CHAPTER</p>',
        ),
        EpubChapter(
          title: 'Second',
          fileName: 'OEBPS/text/second.xhtml',
          htmlContent: '<p>SECOND CHAPTER</p><p id="target">Destination</p>',
        ),
      ],
      toc: const [],
      images: const {},
    );
    final key = GlobalKey<EpubNativeViewState>();
    var settings = const ReaderSettings(
      readingMode: ReadingMode.horizontal,
      enableDualPageSpread: true,
    );
    EpubLocation? latest;
    late StateSetter rebuild;
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _frame(
            EpubNativeView(
              key: key,
              epub: book,
              settings: settings,
              theme: ThemeData.dark(),
              onLocationChanged: (location, _) => latest = location,
            ),
            size: const Size(1200, 500),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.scrollToChapter('OEBPS/text/second.xhtml#target');
    await tester.pumpAndSettle();
    expect(latest!.chapterIndex, 1);
    expect(latest!.anchor, 'target');
    expect(latest!.charOffset, 'SECOND CHAPTER'.length);
    rebuild(() => settings = settings.copyWith(enableDualPageSpread: false));
    await tester.pumpAndSettle();
    expect(_renderedText(tester), contains('Destination'));
    expect(_renderedText(tester), isNot(contains('FIRST CHAPTER')));
    expect(latest!.chapterIndex, 1);
  });

  testWidgets(
    'relative internal links decode paths and fragments without center tap',
    (tester) async {
      final book = await _encodedHrefBook();
      expect(book.chapters[1].fileName, contains('second chapter.xhtml'));
      var centerTaps = 0;
      EpubLocation? latest;
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            epub: book,
            settings: const ReaderSettings(
              readingMode: ReadingMode.horizontal,
              enableDualPageSpread: false,
            ),
            theme: ThemeData.dark(),
            onCenterTapped: () => centerTaps++,
            onLocationChanged: (location, _) => latest = location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapFirstGlyph(tester, 'Open destination');
      await tester.pumpAndSettle();
      expect(centerTaps, 0);
      expect(latest!.chapterIndex, 1);
      expect(latest!.anchor, 'deep anchor');
      expect(_renderedText(tester), contains('DEEP DESTINATION'));
    },
  );

  testWidgets(
    'legacy HTML offsets and v2 content offsets restore differently',
    (tester) async {
      final parts = List.generate(
        100,
        (index) => '[${index.toString().padLeft(3, '0')}] text body. ',
      );
      final text = parts.join();
      final html = '<p data-metadata="${'x' * 8000}">$text</p>';
      final book = ParsedEpub(
        title: 'Location versions',
        author: 'Lira',
        chapters: [
          EpubChapter(
            title: 'Chapter',
            fileName: 'chapter.xhtml',
            htmlContent: html,
          ),
        ],
        toc: const [],
        images: const {},
      );
      final exact = parts.first.length * 20;
      final oldOffset = html.length ~/ 2;
      for (final entry in <(String, int)>[
        ('{"s":0,"c":999999,"f":0.6}', (text.length * 0.6).round()),
        (
          '{"s":0,"c":$oldOffset,"f":0}',
          (oldOffset / html.length * text.length).round(),
        ),
        ('{"v":2,"s":0,"c":$exact,"f":0.8}', exact),
        ('{"s":0,"c":999999,"f":0.8,"so":$exact,"eo":${exact + 5}}', exact),
      ]) {
        EpubLocation? latest;
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: ValueKey(entry.$1),
              epub: book,
              initialLocation: EpubLocation.fromJson(entry.$1),
              settings: const ReaderSettings(
                readingMode: ReadingMode.horizontal,
                enableDualPageSpread: false,
              ),
              theme: ThemeData.dark(),
              onLocationChanged: (location, _) => latest = location,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(latest!.charOffset, entry.$2);
        expect(latest!.hasExactCharOffset, isTrue);
        final index = entry.$2 ~/ parts.first.length;
        expect(
          _renderedText(tester),
          contains('[${index.toString().padLeft(3, '0')}]'),
        );
      }
    },
  );

  testWidgets('link boxes include emoji and trailing halves of final glyphs', (
    tester,
  ) async {
    for (final label in ['😀', 'W']) {
      final book = ParsedEpub(
        title: 'Glyph links',
        author: 'Lira',
        chapters: [
          EpubChapter(
            title: 'Source',
            fileName: 'source.xhtml',
            htmlContent: '<p><a href="target.xhtml#dest">$label</a></p>',
          ),
          EpubChapter(
            title: 'Target',
            fileName: 'target.xhtml',
            htmlContent: '<p id="dest">DESTINATION</p>',
          ),
        ],
        toc: const [],
        images: const {},
      );
      var centerTaps = 0;
      EpubLocation? latest;
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            key: ValueKey(label),
            epub: book,
            settings: const ReaderSettings(
              readingMode: ReadingMode.horizontal,
              enableDualPageSpread: false,
            ),
            theme: ThemeData.dark(),
            onCenterTapped: () => centerTaps++,
            onLocationChanged: (location, _) => latest = location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rich = find.descendant(
        of: find.text(label),
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          )
          .single;
      await tester.tapAt(
        paragraph.localToGlobal(
          Offset(
            box.left + (box.right - box.left) * 0.8,
            (box.top + box.bottom) / 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(centerTaps, 0);
      expect(latest!.chapterIndex, 1);
      expect(_renderedText(tester), contains('DESTINATION'));
    }
  });

  testWidgets('block-wrapping XHTML links remain actionable', (tester) async {
    for (final prefix in ['<html><body>', '<html><body><br>']) {
      final book = ParsedEpub(
        title: 'Block links',
        author: 'Lira',
        chapters: [
          EpubChapter(
            title: 'Chapter',
            fileName: 'chapter.xhtml',
            htmlContent:
                '$prefix<a href="#destination"><div>Open block link</div></a>'
                '<p>${'Before target. ' * 200}</p>'
                '<p id="destination">BLOCK DESTINATION</p></body></html>',
          ),
        ],
        toc: const [],
        images: const {},
      );
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            key: ValueKey(prefix),
            epub: book,
            settings: const ReaderSettings(
              readingMode: ReadingMode.horizontal,
              enableDualPageSpread: false,
            ),
            theme: ThemeData.dark(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapFirstGlyph(tester, 'Open block link');
      await tester.pumpAndSettle();
      expect(_renderedText(tester), contains('BLOCK DESTINATION'));
    }
  });

  testWidgets('an interior paragraph position stays visibly restored', (
    tester,
  ) async {
    final units = List.generate(
      800,
      (index) => '[${index.toString().padLeft(4, '0')}] readable content. ',
    );
    final text = units.join();
    final book = ParsedEpub(
      title: 'Interior position',
      author: 'Lira',
      chapters: [
        EpubChapter(
          title: 'Chapter',
          fileName: 'chapter.xhtml',
          htmlContent: '<p>$text</p>',
        ),
      ],
      toc: const [],
      images: const {},
    );
    var settings = const ReaderSettings();
    var size = const Size(600, 400);
    var readerId = 0;
    EpubLocation initial = EpubLocation.fromPosition(
      chapterIndex: 0,
      charOffset: units.first.length * 300,
      hasExactCharOffset: true,
    );
    EpubLocation? latest;
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _frame(
            EpubNativeView(
              key: ValueKey(readerId),
              epub: book,
              initialLocation: initial,
              settings: settings,
              theme: ThemeData.dark(),
              onLocationChanged: (location, _) => latest = location,
            ),
            size: size,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(_topVisibleText(tester), contains('[0300]'));
    final beforeDrag = _topVisibleText(tester);
    await tester.drag(find.byType(EpubNativeView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(_topVisibleText(tester), isNot(beforeDrag));
    final saved = latest!;
    expect(saved.charOffset, greaterThan(initial.charOffset));
    final marker = RegExp(
      r'\[\d{4}\]',
    ).firstMatch(text.substring(saved.charOffset))!.group(0)!;
    rebuild(() {
      initial = EpubLocation.fromJson(saved.toJson())!;
      readerId++;
    });
    await tester.pumpAndSettle();
    expect(_topVisibleText(tester), contains(marker));
    for (final update in [
      settings.copyWith(fontSize: 23, lineHeight: 1.8),
      settings.copyWith(horizontalPadding: 45),
    ]) {
      rebuild(() => settings = update);
      await tester.pumpAndSettle();
      expect(_topVisibleText(tester), contains(marker));
    }
    rebuild(() => size = const Size(700, 400));
    await tester.pumpAndSettle();
    expect(_topVisibleText(tester), contains(marker));
    rebuild(
      () => settings = settings.copyWith(
        readingMode: ReadingMode.horizontal,
        enableDualPageSpread: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(_renderedText(tester), contains(marker));
    rebuild(
      () => settings = settings.copyWith(readingMode: ReadingMode.vertical),
    );
    await tester.pumpAndSettle();
    expect(_topVisibleText(tester), contains(marker));
  });

  testWidgets(
    'cached chapter jumps keep mounted selection scopes independent',
    (tester) async {
      final key = GlobalKey<EpubNativeViewState>();
      String? selected;
      EpubLocation? selection;
      final book = ParsedEpub(
        title: 'Cached chapters',
        author: 'Lira',
        chapters: [
          for (final name in ['FIRST', 'SECOND', 'THIRD'])
            EpubChapter(
              title: name,
              fileName: '$name.xhtml',
              htmlContent: '<p>$name selectable words</p>',
            ),
        ],
        toc: const [],
        images: const {},
      );
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            key: key,
            epub: book,
            settings: const ReaderSettings(),
            theme: ThemeData.dark(),
            onTextSelected: (text, location) {
              if (text.isNotEmpty) {
                selected = text;
                selection = EpubLocation.fromJson(location);
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.scrollToChapter('SECOND.xhtml');
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('SECOND selectable words'),
          matching: find.byType(RichText),
        ),
      );
      final box = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 6),
          )
          .single;
      final gesture = await tester.startGesture(
        paragraph.localToGlobal(
          Offset(box.left + 1, (box.top + box.bottom) / 2),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(
        paragraph.localToGlobal(
          Offset(box.right - 1, (box.top + box.bottom) / 2),
        ),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, 'SECOND');
      expect(selection!.chapterIndex, 1);
      expect(selection!.startOffset, 0);
      expect(selection!.endOffset, 6);
    },
  );

  testWidgets(
    'empty spine targets finish restoring before later page navigation',
    (tester) async {
      final book = ParsedEpub(
        title: 'Empty spine chapter',
        author: 'Lira',
        chapters: [
          EpubChapter(
            title: 'First',
            fileName: 'first.xhtml',
            htmlContent: '<p>${'FIRST content. ' * 100}</p>',
          ),
          EpubChapter(
            title: 'Empty',
            fileName: 'empty.xhtml',
            htmlContent: '<html><body></body></html>',
          ),
          EpubChapter(
            title: 'Third',
            fileName: 'third.xhtml',
            htmlContent: '<p>THIRD</p>',
          ),
          EpubChapter(
            title: 'Fourth',
            fileName: 'fourth.xhtml',
            htmlContent: '<p>FOURTH</p><p>${'Fourth content. ' * 100}</p>',
          ),
        ],
        toc: const [],
        images: const {},
      );
      var settings = const ReaderSettings(
        readingMode: ReadingMode.horizontal,
        enableDualPageSpread: false,
      );
      EpubLocation? latest;
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _frame(
              EpubNativeView(
                epub: book,
                initialLocation: EpubLocation.fromPosition(chapterIndex: 1),
                settings: settings,
                theme: ThemeData.dark(),
                onLocationChanged: (location, _) => latest = location,
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(latest!.chapterIndex, 2);
      expect(_renderedText(tester), contains('THIRD'));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(latest!.chapterIndex, 3);
      rebuild(
        () => settings = settings.copyWith(readingMode: ReadingMode.vertical),
      );
      await tester.pumpAndSettle();
      expect(latest!.chapterIndex, 3);
      expect(_topVisibleText(tester), contains('FOURTH'));
    },
  );

  testWidgets(
    'table grid retains spans, borders and wrapped cells in both modes',
    (tester) async {
      const leftText = 'Left column text wraps over several readable lines.';
      final book = _htmlBook(
        '<table>'
        '<tr><th colspan="2">Wide heading</th></tr>'
        '<tr><td rowspan="2"><p>$leftText</p></td><td>Upper right</td></tr>'
        '<tr><td>Lower right</td></tr>'
        '</table>',
      );
      for (final mode in ReadingMode.values) {
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: ValueKey(mode),
              epub: book,
              settings: ReaderSettings(
                readingMode: mode,
                enableDualPageSpread: false,
              ),
              theme: ThemeData.dark(),
            ),
            size: const Size(600, 500),
          ),
        );
        await tester.pumpAndSettle();
        final heading = _cellRect(tester, 'Wide heading');
        final left = _cellRect(tester, leftText);
        final upper = _cellRect(tester, 'Upper right');
        final lower = _cellRect(tester, 'Lower right');
        expect(heading.width, closeTo(left.width + upper.width, 0.01));
        expect(left.top, closeTo(upper.top, 0.01));
        expect(left.right, closeTo(upper.left, 0.01));
        expect(upper.bottom, closeTo(lower.top, 0.01));
        expect(left.height, closeTo(upper.height + lower.height, 0.01));
        expect(
          _paragraph(tester, leftText)
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: leftText.length),
              )
              .length,
          greaterThan(1),
        );
        final headingSpan =
            _paragraph(
                  tester,
                  'Wide heading',
                ).text.getSpanForPosition(const TextPosition(offset: 0))
                as TextSpan;
        expect(headingSpan.style?.fontWeight, FontWeight.bold);
        final borders = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(EpubNativeView),
                matching: find.byType(DecoratedBox),
              ),
            )
            .where((box) {
              final decoration = box.decoration;
              return decoration is BoxDecoration && decoration.border != null;
            });
        expect(borders, hasLength(4));
      }
    },
  );

  testWidgets(
    'table pages cover every source cell without splitting rowspans',
    (tester) async {
      final expected = <String>[];
      final rows = StringBuffer('<table>');
      for (var group = 0; group < 10; group++) {
        for (var row = 0; row < 3; row++) {
          rows.write('<tr>');
          if (row == 0) {
            expected.add('GROUP $group');
            rows.write('<td rowspan="3">GROUP $group</td>');
          }
          final label = 'ROW $group.$row';
          expected.add(label);
          rows.write('<td>$label</td></tr>');
        }
      }
      rows.write('</table>');
      var offset = -1;
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            epub: _htmlBook(rows.toString()),
            settings: const ReaderSettings(
              readingMode: ReadingMode.horizontal,
              enableDualPageSpread: false,
            ),
            theme: ThemeData.dark(),
            onLocationChanged: (location, _) => offset = location.charOffset,
          ),
          size: const Size(600, 360),
        ),
      );
      await tester.pumpAndSettle();
      final actual = <String>[];
      final pagesByLabel = <String, int>{};
      var pageCount = 0;
      for (var page = 0; page < 50; page++) {
        pageCount++;
        final labels = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((text) => text.text.toPlainText())
            .toList();
        actual.addAll(labels);
        for (final label in labels) {
          pagesByLabel[label] = page;
        }
        final previous = offset;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        if (offset == previous) break;
      }
      expect(pageCount, greaterThan(1));
      expect(actual, expected);
      for (var group = 0; group < 10; group++) {
        for (var row = 0; row < 3; row++) {
          expect(pagesByLabel['ROW $group.$row'], pagesByLabel['GROUP $group']);
        }
      }
    },
  );

  testWidgets(
    'oversized table cells scroll and their links reveal deep anchors',
    (tester) async {
      final key = GlobalKey<EpubNativeViewState>();
      EpubLocation? latest;
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            key: key,
            epub: _htmlBook(
              '<table><tr><td><p>${'Tall cell content. ' * 100}</p>'
              '<p id="deep">DEEP CELL</p></td>'
              '<td><a href="#deep">Jump deep</a></td></tr></table>',
            ),
            settings: const ReaderSettings(
              readingMode: ReadingMode.horizontal,
              enableDualPageSpread: false,
            ),
            theme: ThemeData.dark(),
            onLocationChanged: (location, _) => latest = location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(400));
      expect(tester.getTopLeft(find.text('DEEP CELL')).dy, greaterThan(400));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      await _tapFirstGlyph(tester, 'Jump deep');
      await tester.pumpAndSettle();
      expect(latest!.anchor, 'deep');
      expect(latest!.charOffset, greaterThan(500));
      final target = tester.getRect(find.text('DEEP CELL'));
      expect(target.top, greaterThanOrEqualTo(24));
      expect(target.bottom, lessThanOrEqualTo(376.01));
    },
  );

  testWidgets('rowspan cell selections and highlights retain source offsets', (
    tester,
  ) async {
    String? selected;
    EpubLocation? location;
    await tester.pumpWidget(
      _frame(
        EpubNativeView(
          epub: _htmlBook(
            '<p>Before</p><table><tr>'
            '<td rowspan="2"><p>Left heading</p><p>CHOSEN</p></td>'
            '<td>Upper right</td></tr><tr><td>Lower right</td></tr></table>',
          ),
          settings: const ReaderSettings(),
          theme: ThemeData.dark(),
          highlights: const [
            {
              'chapterIndex': 0,
              'startOffset': 18,
              'endOffset': 24,
              'color': '#FFEB3B',
            },
          ],
          onTextSelected: (text, json) {
            if (text.isNotEmpty) {
              selected = text;
              location = EpubLocation.fromJson(json);
            }
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = _paragraph(tester, 'CHOSEN');
    var highlighted = false;
    paragraph.text.visitChildren((span) {
      if (span is TextSpan && span.style?.backgroundColor != null) {
        highlighted = true;
      }
      return true;
    });
    expect(highlighted, isTrue);
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 6),
        )
        .single;
    final gesture = await tester.startGesture(
      paragraph.localToGlobal(Offset(box.left + 1, (box.top + box.bottom) / 2)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(
      paragraph.localToGlobal(
        Offset(box.right - 1, (box.top + box.bottom) / 2),
      ),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 'CHOSEN');
    expect(location!.startOffset, 18);
    expect(location!.endOffset, 24);
  });

  testWidgets('linked SVG covers remain contained on their horizontal page', (
    tester,
  ) async {
    EpubLocation? latest;
    final bytes = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 900">'
        '<rect width="300" height="900" fill="#ff0000"/></svg>',
      ),
    );
    await tester.pumpWidget(
      _frame(
        EpubNativeView(
          epub: _htmlBook(
            '<a href="#end"><img src="../images/cover.svg"/></a>'
            '<p id="end">END OF COVER</p>',
            images: {'OEBPS/images/cover.svg': bytes},
          ),
          settings: const ReaderSettings(
            readingMode: ReadingMode.horizontal,
            enableDualPageSpread: false,
          ),
          theme: ThemeData.dark(),
          onLocationChanged: (location, _) => latest = location,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cover = tester.getRect(find.byType(SvgPicture));
    expect(cover.top, greaterThanOrEqualTo(24));
    expect(cover.bottom, lessThanOrEqualTo(376));
    expect(cover.left, greaterThanOrEqualTo(0));
    expect(cover.right, lessThanOrEqualTo(600));
    await tester.tap(find.byType(SvgPicture));
    await tester.pumpAndSettle();
    expect(latest!.anchor, 'end');
    expect(_renderedText(tester), contains('END OF COVER'));
  });
  testWidgets(
    'escaped percent filenames and space filenames stay distinct in links',
    (tester) async {
      final book = ParsedEpub(
        title: 'Distinct paths',
        author: 'Lira',
        chapters: [
          EpubChapter(
            title: 'Links',
            fileName: 'OPS/chapter.xhtml',
            htmlContent:
                '<p><a href="figure%2520one.xhtml">Literal percent</a></p>'
                '<p><a href="figure%20one.xhtml">Space</a></p>',
          ),
          EpubChapter(
            title: 'Percent',
            fileName: 'OPS/figure%20one.xhtml',
            htmlContent: '<p>LITERAL PERCENT DOCUMENT</p>',
          ),
          EpubChapter(
            title: 'Space',
            fileName: 'OPS/figure one.xhtml',
            htmlContent: '<p>SPACE DOCUMENT</p>',
          ),
        ],
        toc: const [],
        images: const {},
      );
      for (final mode in ReadingMode.values) {
        final key = GlobalKey<EpubNativeViewState>();
        EpubLocation? latest;
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: key,
              epub: book,
              settings: ReaderSettings(
                readingMode: mode,
                enableDualPageSpread: false,
              ),
              theme: ThemeData.light(),
              onLocationChanged: (value, _) => latest = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _tapFirstGlyph(tester, 'Literal percent');
        await tester.pumpAndSettle();
        expect(latest!.chapterIndex, 1);
        expect(_renderedText(tester), contains('LITERAL PERCENT DOCUMENT'));
        key.currentState!.goToLocation(
          EpubLocation.fromPosition(chapterIndex: 0),
        );
        await tester.pumpAndSettle();
        await _tapFirstGlyph(tester, 'Space');
        await tester.pumpAndSettle();
        expect(latest!.chapterIndex, 2);
        expect(_renderedText(tester), contains('SPACE DOCUMENT'));
      }
    },
  );

  testWidgets(
    'upper-right cell selection uses geometry while copied ranges use source order',
    (tester) async {
      final book = _htmlBook(
        '<p>Before</p><table><tr>'
        '<td rowspan="2"><p>Left heading</p><p>SECOND LEFT</p></td>'
        '<td>UPPER RIGHT</td></tr><tr><td>LOWER RIGHT</td></tr></table>',
      );
      for (final mode in ReadingMode.values) {
        String? selected;
        EpubLocation? location;
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: ValueKey(mode),
              epub: book,
              settings: ReaderSettings(
                readingMode: mode,
                enableDualPageSpread: false,
              ),
              theme: ThemeData.dark(),
              onTextSelected: (text, json) {
                if (text.isEmpty) return;
                selected = text;
                location = EpubLocation.fromJson(json);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _selectTextRange(tester, 'UPPER RIGHT', 'UPPER RIGHT');
        final rightStart = 'BeforeLeft headingSECOND LEFT'.length;
        expect(selected, 'UPPER RIGHT', reason: '$mode');
        expect(location!.startOffset, rightStart);
        expect(location!.endOffset, rightStart + 'UPPER RIGHT'.length);
        await _selectTextRange(tester, 'Left heading', 'UPPER RIGHT');
        expect(selected, 'Left headingSECOND LEFTUPPER RIGHT');
        expect(location!.startOffset, 'Before'.length);
        expect(location!.endOffset, rightStart + 'UPPER RIGHT'.length);
      }
    },
  );

  testWidgets(
    'manual oversized-page scrolling survives reflow, resize, modes and reopening',
    (tester) async {
      final text = List.generate(
        300,
        (i) => '[${i.toString().padLeft(4, '0')}] sample ',
      ).join();
      final book = _htmlBook(
        '<table><tr><td><p>$text</p></td><td>SIDE CELL</td></tr></table>',
      );
      var settings = const ReaderSettings(
        readingMode: ReadingMode.horizontal,
        enableDualPageSpread: false,
      );
      var size = const Size(600, 400);
      var readerId = 0;
      EpubLocation? initial;
      EpubLocation? latest;
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _frame(
              EpubNativeView(
                key: ValueKey(readerId),
                epub: book,
                initialLocation: initial,
                settings: settings,
                theme: ThemeData.dark(),
                onLocationChanged: (location, _) => latest = location,
              ),
              size: size,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      final saved = latest!;
      expect(saved.hasExactCharOffset, isTrue);
      expect(saved.charOffset, greaterThan(100));
      final marker = RegExp(
        r'\[\d{4}\]',
      ).firstMatch(text.substring(saved.charOffset))!.group(0)!;
      expect(_topVisibleText(tester), contains(marker));
      void checkSavedFrame() {
        expect(_topVisibleText(tester), contains(marker));
        expect(latest!.chapterIndex, saved.chapterIndex);
        expect(latest!.charOffset, saved.charOffset);
      }

      rebuild(() {
        initial = EpubLocation.fromJson(saved.toJson());
        readerId++;
      });
      await _pumpEveryFrame(tester, checkSavedFrame);
      rebuild(
        () => settings = settings.copyWith(fontSize: 23, lineHeight: 1.8),
      );
      await _pumpEveryFrame(tester, checkSavedFrame);
      rebuild(() => size = const Size(700, 400));
      await _pumpEveryFrame(tester, checkSavedFrame);
      rebuild(
        () => settings = settings.copyWith(readingMode: ReadingMode.vertical),
      );
      await _pumpEveryFrame(tester, checkSavedFrame);
      rebuild(
        () => settings = settings.copyWith(readingMode: ReadingMode.horizontal),
      );
      await _pumpEveryFrame(tester, checkSavedFrame);
    },
  );

  testWidgets('table rows use constrained SVG and cached raster aspect ratios', (
    tester,
  ) async {
    final wideRaster = await tester.runAsync(() => _rasterBytes(8, 1));
    final portraitRaster = await tester.runAsync(() => _rasterBytes(1, 8));
    for (final mode in ReadingMode.values) {
      for (final svg in [true, false]) {
        final heights = <double>[];
        for (final portrait in [false, true]) {
          final bytes = svg
              ? Uint8List.fromList(
                  utf8.encode(
                    '<svg xmlns="http://www.w3.org/2000/svg" '
                    'viewBox="0 0 ${portrait ? 100 : 800} ${portrait ? 800 : 100}">'
                    '<rect width="100%" height="100%" fill="red"/></svg>',
                  ),
                )
              : (portrait ? portraitRaster! : wideRaster!);
          final path = 'OEBPS/images/figure.${svg ? 'svg' : 'png'}';
          await tester.pumpWidget(
            _frame(
              EpubNativeView(
                key: ValueKey((mode, svg, portrait)),
                epub: _htmlBook(
                  '<table><tr><td><img src="../images/${path.split('/').last}"/>'
                  '</td><td>IMAGE ROW</td></tr></table>'
                  '<p>AFTER IMAGE</p>',
                  images: {path: bytes},
                ),
                settings: ReaderSettings(
                  readingMode: mode,
                  enableDualPageSpread: false,
                ),
                theme: ThemeData.dark(),
              ),
            ),
          );
          if (!svg) {
            await tester.runAsync(
              () => precacheImage(
                MemoryImage(bytes),
                tester.element(find.byType(EpubNativeView)),
              ),
            );
          }
          await tester.pumpAndSettle();
          heights.add(_cellRect(tester, 'IMAGE ROW').height);
          if (!portrait) {
            expect(heights.last, lessThan(140));
            final after = tester.getRect(find.text('AFTER IMAGE'));
            expect(after.top, greaterThanOrEqualTo(24));
            expect(after.bottom, lessThanOrEqualTo(376));
          }
        }
        expect(heights.first, lessThan(heights.last / 2));
      }
    }
  });

  testWidgets(
    'raster SVG covers retain their viewport ratio inside table cells',
    (tester) async {
      final raster = (await tester.runAsync(() => _rasterBytes(1, 8)))!;
      final svg = utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200">'
        '<image href="portrait.png" width="400" height="200"/></svg>',
      );
      for (final mode in ReadingMode.values) {
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: ValueKey(mode),
              epub: _htmlBook(
                '<table><tr><td><img src="../images/cover.svg"/></td>'
                '<td>VIEWPORT ROW</td></tr></table><p>AFTER VIEWPORT</p>',
                images: {
                  'OEBPS/images/cover.svg': svg,
                  'OEBPS/images/portrait.png': raster,
                },
              ),
              settings: ReaderSettings(
                readingMode: mode,
                enableDualPageSpread: false,
              ),
              theme: ThemeData.light(),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(raster),
            tester.element(find.byType(EpubNativeView)),
          ),
        );
        await tester.pumpAndSettle();
        final row = _cellRect(tester, 'VIEWPORT ROW');
        expect(row.height, closeTo(172, 0.1));
        expect(
          tester.getRect(find.text('AFTER VIEWPORT')).bottom,
          lessThan(376),
        );
      }
    },
  );

  testWidgets(
    'late raster dimensions pack with text without losing a restored target',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final layout in [
        (inTable: true, spread: false),
        (inTable: false, spread: false),
        (inTable: false, spread: true),
      ]) {
        final bytes = (await tester.runAsync(() => _rasterBytes(16, 1)))!;
        final figure = layout.inTable
            ? '<table><tr><td><img src="../images/wide.png"/></td>'
                  '<td>RASTER ROW</td></tr></table>'
            : '<img src="../images/wide.png"/>';
        final book = _htmlBook(
          '<p style="margin: 0">BEFORE RASTER</p>$figure'
          '<p id="after" style="margin: 0">AFTER RASTER</p>',
          images: {'OEBPS/images/wide.png': bytes},
        );
        final leaves = contentLeaves(
          XhtmlParser(
            html: book.chapters.single.htmlContent,
            images: book.images,
            documentPath: book.chapters.single.fileName,
            baseStyle: const TextStyle(fontSize: 18),
          ).parse(),
        );
        final offset = leaves.whereType<TextBlock>().last.charStart;
        final size = layout.inTable
            ? const Size(600, 400)
            : Size(layout.spread ? 1000 : 360, 600);
        final viewport = Rect.fromLTWH(0, 24, size.width, size.height - 48);
        final reports = <EpubLocation>[];
        void checkFrame() {
          _expectFragmentVisible(tester, 'AFTER RASTER', viewport);
          for (final report in reports) {
            expect(report.hasExactCharOffset, isTrue);
            expect(report.chapterIndex, 0);
            expect(report.charOffset, offset);
          }
        }

        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: ValueKey(layout),
              epub: book,
              initialLocation: EpubLocation.fromPosition(
                chapterIndex: 0,
                charOffset: offset,
                hasExactCharOffset: true,
              ),
              settings: ReaderSettings(
                readingMode: ReadingMode.horizontal,
                enableDualPageSpread: layout.spread,
                horizontalPadding: 20,
              ),
              theme: ThemeData.dark(),
              onLocationChanged: (value, _) => reports.add(value),
            ),
            size: size,
          ),
        );
        checkFrame();
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(bytes),
            tester.element(find.byType(EpubNativeView)),
          ),
        );
        await _pumpEveryFrame(tester, checkFrame);
        expect(reports, isNotEmpty);
        final before = tester.getRect(find.text('BEFORE RASTER'));
        final target = tester.getRect(find.text('AFTER RASTER'));
        expect(before.top, greaterThanOrEqualTo(viewport.top));
        expect(target.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(target.left, closeTo(before.left, .01));
        expect(target.right, closeTo(before.right, .01));
        if (layout.inTable) {
          expect(_cellRect(tester, 'RASTER ROW').height, lessThan(140));
        } else {
          final image = tester.getRect(find.byType(Image));
          expect(image.width, closeTo(before.width, .01));
          expect(image.height, closeTo(image.width / 16, .01));
          expect(image.left, closeTo(before.left, .01));
          expect(image.top, greaterThanOrEqualTo(before.bottom));
          expect(target.top, greaterThanOrEqualTo(image.bottom));
        }
      }
    },
  );

  testWidgets(
    'linked cover padding and contained-image gutters do not activate links',
    (tester) async {
      final raster = (await tester.runAsync(() => _rasterBytes(1, 3)))!;
      for (final svg in [true, false]) {
        var centerTaps = 0;
        EpubLocation? latest;
        final bytes = svg
            ? Uint8List.fromList(
                utf8.encode(
                  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 900">'
                  '<rect width="300" height="900" fill="red"/></svg>',
                ),
              )
            : raster;
        final path = 'cover.${svg ? 'svg' : 'png'}';
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: ValueKey(svg),
              epub: ParsedEpub(
                title: 'Cover gutters',
                author: 'Lira',
                chapters: [
                  EpubChapter(
                    title: 'Cover',
                    fileName: 'cover.xhtml',
                    htmlContent:
                        '<a href="target.xhtml"><img src="$path"/></a>',
                  ),
                  EpubChapter(
                    title: 'Next',
                    fileName: 'next.xhtml',
                    htmlContent: '<p>NEXT PAGE</p>',
                  ),
                  EpubChapter(
                    title: 'Link target',
                    fileName: 'target.xhtml',
                    htmlContent: '<p>LINK TARGET</p>',
                  ),
                ],
                toc: const [],
                images: {path: bytes},
              ),
              settings: const ReaderSettings(
                readingMode: ReadingMode.horizontal,
                enableDualPageSpread: false,
              ),
              theme: ThemeData.dark(),
              onCenterTapped: () => centerTaps++,
              onLocationChanged: (value, _) => latest = value,
            ),
          ),
        );
        if (!svg) {
          await tester.runAsync(
            () => precacheImage(
              MemoryImage(bytes),
              tester.element(find.byType(EpubNativeView)),
            ),
          );
        }
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(300, 25));
        await tester.pumpAndSettle();
        expect(centerTaps, 1);
        expect(latest!.chapterIndex, 0);
        await tester.tapAt(const Offset(550, 180));
        await tester.pumpAndSettle();
        expect(latest!.chapterIndex, 1);
        expect(_renderedText(tester), contains('NEXT PAGE'));
        expect(_renderedText(tester), isNot(contains('LINK TARGET')));
      }
    },
  );

  testWidgets(
    'terminal anchors reveal the final caret inside an oversized table row',
    (tester) async {
      final text = '${'Tall terminal content. ' * 120}TERMINAL WORD';
      EpubLocation? latest;
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            epub: _htmlBook(
              '<table><tr><td><a href="#terminal">Jump terminal</a></td>'
              '<td><p>$text<span id="terminal"></span></p></td>'
              '</tr></table>',
            ),
            settings: const ReaderSettings(
              readingMode: ReadingMode.horizontal,
              enableDualPageSpread: false,
            ),
            theme: ThemeData.dark(),
            onLocationChanged: (value, _) => latest = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapFirstGlyph(tester, 'Jump terminal');
      await tester.pumpAndSettle();
      expect(latest!.charOffset, 'Jump terminal'.length + text.length);
      final paragraph = _paragraph(tester, text);
      final last = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: text.length - 'TERMINAL WORD'.length,
              extentOffset: text.length,
            ),
          )
          .last
          .toRect();
      final top = paragraph.localToGlobal(last.topLeft).dy;
      final bottom = paragraph.localToGlobal(last.bottomRight).dy;
      expect(top, greaterThanOrEqualTo(24));
      expect(bottom, lessThanOrEqualTo(376));
    },
  );

  testWidgets(
    'escaped package TOC locators distinguish percent and space filenames',
    (tester) async {
      final book = ParsedEpub(
        title: 'TOC paths',
        author: 'Lira',
        chapters: [
          EpubChapter(
            title: 'Start',
            fileName: 'OPS/start.xhtml',
            htmlContent: '<p>START</p>',
          ),
          EpubChapter(
            title: 'Percent',
            fileName: 'OPS/figure%20one.xhtml',
            htmlContent: '<p>LITERAL PERCENT DOCUMENT</p>',
          ),
          EpubChapter(
            title: 'Space',
            fileName: 'OPS/figure one.xhtml',
            htmlContent: '<p>SPACE DOCUMENT</p>',
          ),
        ],
        toc: const [],
        images: const {},
      );
      for (final mode in ReadingMode.values) {
        final key = GlobalKey<EpubNativeViewState>();
        EpubLocation? latest;
        await tester.pumpWidget(
          _frame(
            EpubNativeView(
              key: key,
              epub: book,
              settings: ReaderSettings(
                readingMode: mode,
                enableDualPageSpread: false,
              ),
              theme: ThemeData.dark(),
              onLocationChanged: (value, _) => latest = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final index in [2, 1]) {
          key.currentState!.scrollToChapter(
            Uri(
              pathSegments: book.chapters[index].fileName.split('/'),
            ).toString(),
          );
          await tester.pumpAndSettle();
          expect(latest!.chapterIndex, index);
          expect(
            _renderedText(tester),
            contains(
              index == 1 ? 'LITERAL PERCENT DOCUMENT' : 'SPACE DOCUMENT',
            ),
          );
        }
      }
    },
  );
}
