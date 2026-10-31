import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ParsedEpub _book(String content) => ParsedEpub(
  title: 'Typography',
  author: 'Lira',
  language: 'en',
  chapters: [
    EpubChapter(
      title: 'Text',
      fileName: 'text.xhtml',
      htmlContent: '<html xml:lang="en"><body>$content</body></html>',
    ),
  ],
  toc: const [],
  images: const {},
);

Widget _frame(Widget child, {double width = 240, double height = 320}) =>
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );

Iterable<RenderParagraph> _paragraphs(WidgetTester tester) => find
    .byType(RichText)
    .evaluate()
    .map((element) => element.renderObject!)
    .whereType<RenderParagraph>();

Future<void> _select(
  WidgetTester tester,
  RenderParagraph paragraph,
  int start,
  int end,
) async {
  final first = paragraph
      .getBoxesForSelection(
        TextSelection(
          baseOffset: readerDisplayOffset(paragraph.text, start),
          extentOffset: readerDisplayOffset(paragraph.text, start + 1),
        ),
      )
      .first;
  final last = paragraph
      .getBoxesForSelection(
        TextSelection(
          baseOffset: readerDisplayOffset(paragraph.text, end - 1),
          extentOffset: readerDisplayOffset(paragraph.text, end),
        ),
      )
      .last;
  final gesture = await tester.startGesture(
    paragraph.localToGlobal(
      Offset(first.left + 1, (first.top + first.bottom) / 2),
    ),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.moveTo(
    paragraph.localToGlobal(
      Offset(first.left + 24, (first.top + first.bottom) / 2),
    ),
  );
  await tester.pump();
  await gesture.moveTo(
    paragraph.localToGlobal(
      Offset(last.right - 1, (last.top + last.bottom) / 2),
    ),
  );
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void _expectTakenHyphens(RenderParagraph paragraph) {
  final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final hyphen = TextPainter(
    text: TextSpan(text: '-', style: paragraph.text.style),
    textDirection: TextDirection.ltr,
  )..layout();
  for (
    var index = raw.indexOf('-');
    index >= 0;
    index = raw.indexOf('-', index + 1)
  ) {
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        )
        .single;
    expect(box.right - box.left, closeTo(hyphen.width, 0.01));
    expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.01));
    if (index + 1 < raw.length) {
      final next = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: index + 1, extentOffset: index + 2),
          )
          .first;
      expect(
        next.top,
        greaterThan(box.top),
        reason: 'A discretionary hyphen must end an actual painted line',
      );
    }
  }
  hyphen.dispose();
}

void main() {
  testWidgets('links remain tappable after inserted display hyphens', (
    tester,
  ) async {
    final book = _book(
      '<p><a href="#target">associate</a></p>'
      '<p>${'Filler content. ' * 50}</p><p id="target">Destination</p>',
    );
    final parsed = XhtmlParser(
      html: book.chapters.single.htmlContent,
      images: const {},
      baseStyle: const TextStyle(),
    ).parse();
    final target = parsed.whereType<TextBlock>().last.charStart;
    for (final mode in ReadingMode.values) {
      EpubLocation? latest;
      await tester.pumpWidget(
        _frame(
          EpubNativeView(
            key: ValueKey(mode),
            epub: book,
            settings: ReaderSettings(
              readingMode: mode,
              enableDualPageSpread: false,
              hyphenation: true,
            ),
            theme: ThemeData.dark(),
            onLocationChanged: (location, _) => latest = location,
          ),
          width: 160,
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = _paragraphs(
        tester,
      ).firstWhere((paragraph) => paragraph.text.toPlainText() == 'associate');
      final glyph = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: readerDisplayOffset(paragraph.text, 8),
              extentOffset: readerDisplayOffset(paragraph.text, 9),
            ),
          )
          .last;
      await tester.tapAt(paragraph.localToGlobal(glyph.toRect().center));
      await tester.pumpAndSettle();
      expect(latest!.charOffset, target, reason: '$mode');
    }
  });

  testWidgets(
    'reader layout affects paragraphs without changing headings/lists/pre',
    (tester) async {
      final book = _book(
        '<style>p { font-weight: normal; }</style>'
        '<h1>Heading</h1><p>Body text</p><ul><li>List item</li></ul>'
        '<pre>Preformatted</pre><table><tr><th>Table heading</th></tr></table>',
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
                fontWeight: 600,
                paragraphIndent: 2,
                paragraphSpacing: 1,
                textAlign: ReaderTextAlign.justify,
              ),
              theme: ThemeData.dark(),
            ),
            width: 600,
            height: 700,
          ),
        );
        await tester.pumpAndSettle();
        final paragraphs = _paragraphs(tester).toList();
        final body = paragraphs.firstWhere(
          (p) => p.text.toPlainText() == 'Body text',
        );
        final firstGlyph = body
            .getBoxesForSelection(
              TextSelection(
                baseOffset: readerDisplayOffset(body.text, 0),
                extentOffset: readerDisplayOffset(body.text, 1),
              ),
            )
            .first;
        expect(firstGlyph.left, closeTo(32, 0.1));
        expect(body.textAlign, TextAlign.justify);
        for (final label in [
          'Heading',
          '• List item',
          'Preformatted',
          'Table heading',
        ]) {
          final paragraph = paragraphs.firstWhere(
            (p) => p.text.toPlainText() == label,
          );
          final glyph = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: readerDisplayOffset(paragraph.text, 0),
                  extentOffset: readerDisplayOffset(paragraph.text, 1),
                ),
              )
              .first;
          expect(glyph.left, closeTo(0, 0.1), reason: label);
          expect(paragraph.textAlign, isNot(TextAlign.justify), reason: label);
        }
      }
    },
  );

  testWidgets(
    'EN/RU chosen hyphens paint at line ends and copy unchanged source',
    (tester) async {
      for (final mode in ReadingMode.values) {
        for (final alignment in [
          ReaderTextAlign.left,
          ReaderTextAlign.justify,
        ]) {
          for (final sample in [('en', 'associate'), ('ru', 'молоко')]) {
            String? selected;
            EpubLocation? selection;
            await tester.pumpWidget(
              _frame(
                EpubNativeView(
                  key: ValueKey((mode, alignment, sample.$1)),
                  epub: _book('<p lang="${sample.$1}">${sample.$2}</p>'),
                  settings: ReaderSettings(
                    readingMode: mode,
                    enableDualPageSpread: false,
                    hyphenation: true,
                    fontFamily: 'Ahem',
                    fontSize: 24,
                    textAlign: alignment,
                  ),
                  theme: ThemeData.dark(),
                  onTextSelected: (text, json) {
                    if (text.isEmpty) return;
                    selected = text;
                    selection = EpubLocation.fromJson(json);
                  },
                ),
                width: 160,
              ),
            );
            await tester.pumpAndSettle();
            final paragraph = _paragraphs(tester).firstWhere(
              (paragraph) => paragraph.text.toPlainText() == sample.$2,
            );
            final raw = paragraph.text.toPlainText(
              includeSemanticsLabels: false,
            );
            final marker = readerDisplayOffset(paragraph.text, 4) - 1;
            expect(raw[marker], '-'); // asso-ciate / моло-ко at this width.
            expect(raw.split('-'), hasLength(2));
            final firstGlyph = paragraph
                .getBoxesForSelection(
                  TextSelection(
                    baseOffset: readerDisplayOffset(paragraph.text, 0),
                    extentOffset: readerDisplayOffset(paragraph.text, 1),
                  ),
                )
                .first;
            expect(firstGlyph.left, closeTo(36, 0.01));
            _expectTakenHyphens(paragraph);
            await _select(tester, paragraph, 0, sample.$2.length);
            expect(
              selected,
              sample.$2,
              reason: '$mode / $alignment / ${sample.$1}',
            );
            expect(selection!.startOffset, 0);
            expect(selection!.endOffset, sample.$2.length);
          }
        }
      }
    },
  );

  testWidgets('continued paragraph pages cover the unmodified source once', (
    tester,
  ) async {
    final text = List.generate(
      80,
      (index) =>
          'associate 👩‍🔬 á representation hyphenation${index % 7 == 0 ? '\n' : ' '}',
    ).join();
    final boundaries = <int>{0};
    var boundary = 0;
    for (final grapheme in text.characters) {
      boundary += grapheme.length;
      boundaries.add(boundary);
    }
    var offset = -1;
    await tester.pumpWidget(
      _frame(
        EpubNativeView(
          epub: _book('<p>${text.replaceAll('\n', '<br/>')}</p>'),
          settings: const ReaderSettings(
            readingMode: ReadingMode.horizontal,
            enableDualPageSpread: false,
            hyphenation: true,
            paragraphIndent: 2,
            paragraphSpacing: 1,
            fontFamily: 'Ahem',
            fontSize: 24,
            textAlign: ReaderTextAlign.justify,
          ),
          theme: ThemeData.dark(),
          onLocationChanged: (location, _) => offset = location.charOffset,
        ),
        height: 200,
      ),
    );
    await tester.pumpAndSettle();
    final fragments = <String>[];
    var consumed = 0;
    for (var page = 0; page < 200; page++) {
      final paragraph = _paragraphs(tester).first;
      final fragment = paragraph.text.toPlainText();
      fragments.add(fragment);
      consumed += fragment.length;
      expect(boundaries, contains(consumed));
      _expectTakenHyphens(paragraph);
      if (page > 0) {
        var first = 0;
        while (first < fragment.length &&
            (fragment[first] == '\n' || fragment[first] == '\r')) {
          first++;
        }
        if (first < fragment.length) {
          final end = first + fragment.substring(first).characters.first.length;
          final glyph = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: readerDisplayOffset(paragraph.text, first),
                  extentOffset: readerDisplayOffset(paragraph.text, end),
                ),
              )
              .first;
          expect(
            glyph.left,
            closeTo(0, 0.1),
            reason: 'Continued paragraphs must not acquire a fresh indent',
          );
        }
      }
      final previous = offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      if (offset == previous) break;
    }
    expect(fragments.length, greaterThan(1));
    expect(fragments.join(), text);
  });

  testWidgets(
    'live palette changes keep position, paragraph metrics and mapping',
    (tester) async {
      final book = _book('<p>${'associate readable words ' * 100}</p>');
      var settings = const ReaderSettings(
        readingMode: ReadingMode.horizontal,
        enableDualPageSpread: false,
        hyphenation: true,
      );
      late StateSetter rebuild;
      EpubLocation? latest;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _frame(
              EpubNativeView(
                epub: book,
                settings: settings,
                theme: ThemeData.dark(),
                onLocationChanged: (location, _) => latest = location,
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final before = _paragraphs(tester).first;
      final size = before.size;
      final text = before.text.toPlainText();
      final location = latest!.charOffset;
      final mappedOffset = readerDisplayOffset(before.text, 10);
      rebuild(
        () => settings = settings.copyWith(
          backgroundColor: 0xfff5eddf,
          textColor: 0xff191919,
          linkColor: 0xff003399,
          selectionColor: 0x553399ff,
          textContrast: 0.8,
          brightness: 0.7,
        ),
      );
      await tester.pumpAndSettle();
      final after = _paragraphs(tester).first;
      expect(identical(before, after), isTrue);
      expect(after.size, size);
      expect(after.text.toPlainText(), text);
      expect(readerDisplayOffset(after.text, 10), mappedOffset);
      expect(latest!.charOffset, location);
    },
  );
}
