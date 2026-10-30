import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fontAssets = {
  'Lora': ['Lora-Variable.ttf', 'Lora-Italic-Variable.ttf'],
  'Literata': ['Literata-Variable.ttf', 'Literata-Italic-Variable.ttf'],
  'Inter': ['Inter-Variable.ttf', 'Inter-Italic-Variable.ttf'],
  'PT Serif': ['PTSerif-Regular.ttf', 'PTSerif-Italic.ttf'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParsedEpub book;
  final locations = <String, EpubLocation>{};
  const paragraphs = {
    'en': 'A railway map rested on the windowsill.',
    'ru': 'На подоконнике лежала карта.',
  };

  setUpAll(() async {
    for (final entry in _fontAssets.entries) {
      final loader = FontLoader(entry.key);
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$asset'));
      }
      await loader.load();
    }
    final data = await rootBundle.load('assets/reader/reading_sample.epub');
    book = await EpubParser.parse(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    for (final entry in paragraphs.entries) {
      final chapter = book.chapters.indexWhere(
        (chapter) => chapter.htmlContent.contains(entry.value),
      );
      final document = book.chapters[chapter];
      final elements = XhtmlParser(
        html: document.htmlContent,
        images: book.images,
        documentPath: document.fileName,
        stylesheets: book.stylesheets,
        baseStyle: const TextStyle(fontSize: 16),
      ).parse();
      final paragraph = contentLeaves(elements)
          .whereType<TextBlock>()
          .firstWhere(
            (block) => block.span.toPlainText().startsWith(entry.value),
          );
      locations[entry.key] = EpubLocation.fromPosition(
        chapterIndex: chapter,
        charOffset: paragraph.charStart,
        hasExactCharOffset: true,
      );
    }
  });

  for (final family in _fontAssets.keys) {
    for (final mode in ReadingMode.values) {
      for (final size in [16.0, 24.0]) {
        for (final language in paragraphs.keys) {
          testWidgets(
            '$family $size $language $mode keeps justified glyphs inside the page',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = const Size(1000, 1000);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(tester.view.resetPhysicalSize);
              await tester.pumpWidget(
                MaterialApp(
                  home: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 390,
                      height: 760,
                      child: EpubNativeView(
                        epub: book,
                        initialLocation: locations[language],
                        settings: ReaderSettings(
                          fontFamily: family,
                          fontSize: size,
                          lineHeight: 1.5,
                          paragraphIndent: 1.5,
                          horizontalPadding: 16,
                          textAlign: ReaderTextAlign.justify,
                          hyphenation: true,
                          readingMode: mode,
                          enableDualPageSpread: false,
                        ),
                        theme: ThemeData.dark(),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final paragraph = find
                  .byType(RichText)
                  .evaluate()
                  .map((element) => element.renderObject)
                  .whereType<RenderParagraph>()
                  .firstWhere(
                    (render) => render.text.toPlainText().startsWith(
                      paragraphs[language]!,
                    ),
                  );
              final displayText = paragraph.text.toPlainText(
                includeSemanticsLabels: false,
              );
              final firstOffset = readerDisplayOffset(paragraph.text, 0);
              final firstGlyph = paragraph
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: firstOffset,
                      extentOffset: firstOffset + 1,
                    ),
                  )
                  .first;
              expect(firstGlyph.left, closeTo(size * 1.5, 0.1));
              var offset = 0;
              for (final grapheme in displayText.characters) {
                final end = offset + grapheme.length;
                if (offset >= firstOffset && grapheme.trim().isNotEmpty) {
                  final boxes = paragraph.getBoxesForSelection(
                    TextSelection(baseOffset: offset, extentOffset: end),
                  );
                  for (final box in boxes) {
                    expect(
                      box.left,
                      greaterThanOrEqualTo(-0.1),
                      reason: 'Left edge of $grapheme',
                    );
                    expect(
                      box.right,
                      lessThanOrEqualTo(paragraph.size.width + 0.1),
                      reason: 'Right edge of $grapheme',
                    );
                  }
                }
                offset = end;
              }
              final painter = TextPainter(
                text: paragraph.text,
                textDirection: TextDirection.ltr,
                textAlign: paragraph.textAlign,
                textScaler: TextScaler.noScaling,
                textHeightBehavior: const TextHeightBehavior(),
              )..layout(maxWidth: paragraph.size.width);
              final unindented = TextPainter(
                text: TextSpan(
                  text: paragraph.text.toPlainText(),
                  style: paragraph.text.style,
                ),
                textDirection: TextDirection.ltr,
                textAlign: paragraph.textAlign,
                textScaler: TextScaler.noScaling,
                textHeightBehavior: const TextHeightBehavior(),
              )..layout(maxWidth: paragraph.size.width);
              expect(
                painter.computeLineMetrics().first.height,
                closeTo(unindented.computeLineMetrics().first.height, 0.1),
                reason: 'The indent must not change the source font metrics',
              );
              unindented.dispose();
              painter.dispose();
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }
}
