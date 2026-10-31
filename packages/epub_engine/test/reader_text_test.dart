import 'package:epub_engine/epub_engine.dart';
import 'package:epub_engine/src/reader_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextStyle _effectiveStyleAt(
  InlineSpan span,
  int offset, [
  TextStyle inherited = const TextStyle(),
]) {
  if (span is! TextSpan) return inherited;
  final style = inherited.merge(span.style);
  final ownLength = span.text?.length ?? 0;
  if (offset < ownLength) return style;
  offset -= ownLength;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final length = child.toPlainText(includeSemanticsLabels: false).length;
    if (offset < length) return _effectiveStyleAt(child, offset, style);
    offset -= length;
  }
  return style;
}

void main() {
  test(
    'legacy reader JSON preserves saved preferences and independent contrast/dimming',
    () {
      final saved = <String, dynamic>{
        'fontFamily': 'serif',
        'fontSize': 21.0,
        'backgroundColor': 0xfff5eedc,
        'lineHeight': 1.8,
        'horizontalPadding': 28.0,
        'readingMode': 'horizontal',
        'enableDualPageSpread': false,
        'brightness': 0.4,
      };
      final settings = ReaderSettings.fromJson(saved);
      final serialized = settings.toJson();
      for (final entry in saved.entries) {
        expect(serialized[entry.key], entry.value, reason: entry.key);
      }
      expect(
        settings.copyWith(brightness: 1).resolvedTextColor,
        settings.resolvedTextColor,
      );
      expect(
        settings.copyWith(textContrast: 0).resolvedTextColor,
        Color(settings.backgroundColor),
      );
    },
  );

  test('TeX English and Russian exceptions are language aware across runs', () {
    final spans = TextSpan(
      style: const TextStyle(locale: Locale('en-US')),
      children: const [
        TextSpan(text: 'as'),
        TextSpan(
          text: 'sociate',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: ' '),
        TextSpan(
          text: 'также',
          style: TextStyle(locale: Locale('ru-RU')),
        ),
      ],
    );
    expect(readerHyphenationOffsets(spans), [2, 4, 13]);
    expect(
      readerHyphenationOffsets(
        const TextSpan(
          text: 'associate также',
          style: TextStyle(locale: Locale('de')),
        ),
      ),
      isEmpty,
    );
    expect(
      readerHyphenationOffsets(const TextSpan(text: 'associate также')),
      isEmpty,
    );
  });

  test(
    'pattern tries find known EN/RU word boundaries and inherit language',
    () {
      for (final sample in [
        ('en', 'hyphenation', [2, 6]), // hy-phen-ation
        ('ru', 'молоко', [2, 4]), // мо-ло-ко
      ]) {
        final points = readerHyphenationOffsets(
          TextSpan(
            text: sample.$2,
            style: TextStyle(locale: Locale(sample.$1)),
          ),
        );
        expect(points, sample.$3, reason: sample.$2);
      }
      final blocks = XhtmlParser(
        html:
            '<html xml:lang="ru"><body><p>молоко '
            '<span lang="en">hyphenation</span> '
            '<span lang="">hyphenation</span></p></body></html>',
        images: const {},
        baseStyle: const TextStyle(),
      ).parse().whereType<TextBlock>().toList();
      expect(readerHyphenationOffsets(blocks.single.span), [2, 4, 9, 13]);
    },
  );

  test(
    'inserted display hyphens and indent preserve every UTF-16 boundary',
    () {
      const source = TextSpan(
        text: '😀 associate также',
        style: TextStyle(locale: Locale('en')),
      );
      final presentation = ReaderTextPresentation(
        source: source,
        hyphenationOffsets: [5, 7, 16],
        selectedHyphens: {5, 7, 16},
        firstLineIndent: 24,
      );
      expect(presentation.span.toPlainText(), '😀 associate также');
      for (var offset = 0; offset <= presentation.sourceText.length; offset++) {
        expect(presentation.toSource(presentation.toDisplay(offset)), offset);
      }
      for (final boundary in [5, 7, 16]) {
        final after = presentation.toDisplay(boundary);
        expect(presentation.toSource(after - 1), boundary);
        expect(presentation.toSource(after), boundary);
      }
      final wrapped = TextSpan(children: [presentation.span]);
      expect(readerSourceOffset(wrapped, presentation.toDisplay(7)), 7);
    },
  );

  test('first line has indent while wrapped lines use the full width', () {
    final presentation = ReaderTextPresentation(
      source: const TextSpan(
        text: 'A readable paragraph wraps onto several lines.',
      ),
      firstLineIndent: 32,
    );
    final painter = TextPainter(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.5),
        children: [presentation.span],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 180);
    final first = painter
        .getBoxesForSelection(
          TextSelection(
            baseOffset: presentation.toDisplay(0),
            extentOffset: presentation.toDisplay(1),
          ),
        )
        .first;
    expect(first.left, closeTo(32, 0.1));
    final lines = painter.computeLineMetrics();
    expect(lines.length, greaterThan(1));
    final secondStart = painter
        .getLineBoundary(
          painter.getPositionForOffset(
            Offset(lines[1].left, lines[1].baseline - lines[1].ascent / 2),
          ),
        )
        .start;
    final second = painter
        .getBoxesForSelection(
          TextSelection(baseOffset: secondStart, extentOffset: secondStart + 1),
        )
        .first;
    expect(second.left, closeTo(0, 0.1));
    painter.dispose();
  });

  test('hyphenated line boundaries map to a valid original word boundary', () {
    const source = TextSpan(
      text: 'associate',
      style: TextStyle(fontFamily: 'Ahem', fontSize: 16, locale: Locale('en')),
    );
    final presentation = ReaderTextPresentation(
      source: source,
      hyphenationOffsets: readerHyphenationOffsets(source),
      maxWidth: 80,
    );
    final painter = TextPainter(
      text: presentation.span,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);
    final lines = painter.computeLineMetrics();
    expect(lines.length, greaterThan(1));
    final next = lines[1];
    final boundary = painter
        .getLineBoundary(
          painter.getPositionForOffset(
            Offset(next.left, next.baseline - next.ascent / 2),
          ),
        )
        .start;
    expect(presentation.toSource(boundary), 4);
    final displayed = presentation.span.toPlainText(
      includeSemanticsLabels: false,
    );
    expect(displayed[boundary - 1], '-');
    final glyph = painter
        .getBoxesForSelection(
          TextSelection(baseOffset: boundary - 1, extentOffset: boundary),
        )
        .single;
    final hyphen = TextPainter(
      text: const TextSpan(
        text: '-',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(glyph.right - glyph.left, closeTo(hyphen.width, 0.01));
    expect(lines.first.width, lessThanOrEqualTo(80.001));
    expect(presentation.span.toPlainText(), 'associate');
    hyphen.dispose();
    painter.dispose();
  });

  test(
    'styled probe windows keep hyphens at real breaks across UTF-16 and newlines',
    () {
      const baseStyle = TextStyle(fontFamily: 'Ahem', fontSize: 16);
      const source = TextSpan(
        style: TextStyle(locale: Locale('en')),
        children: [
          TextSpan(text: '😀 as'),
          TextSpan(
            text: 'sociate ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            children: [
              TextSpan(text: 'associate\n'),
              TextSpan(
                text: 'associate',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      );
      final offsets = readerHyphenationOffsets(source);
      for (final width in [80.0, 96.0, 112.0]) {
        final presentation = ReaderTextPresentation(
          source: source,
          hyphenationOffsets: offsets,
          firstLineIndent: 16,
          baseStyle: baseStyle,
          maxWidth: width,
        );
        final painter = TextPainter(
          text: TextSpan(style: baseStyle, children: [presentation.span]),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width);
        final displayed = presentation.span.toPlainText(
          includeSemanticsLabels: false,
        );
        final lines = painter.computeLineMetrics();
        final lineEnds = <int>{
          displayed.length,
          for (final line in lines.skip(1))
            painter
                .getLineBoundary(
                  painter.getPositionForOffset(
                    Offset(
                      line.left + line.width / 2,
                      line.baseline - line.ascent / 2,
                    ),
                  ),
                )
                .start,
        };
        final visible = offsets.where(presentation.hasVisibleHyphenAt).toList();
        expect(visible, isNotEmpty, reason: 'width $width');
        for (final point in visible) {
          final displayEnd = presentation.toDisplay(point);
          expect(displayed[displayEnd - 1], '-');
          expect(lineEnds, contains(displayEnd), reason: 'width $width');
          final before = _effectiveStyleAt(source, point - 1, baseStyle);
          final hyphen = _effectiveStyleAt(
            presentation.span,
            displayEnd - 1,
            baseStyle,
          );
          expect(hyphen.fontSize, before.fontSize);
          expect(hyphen.fontWeight, before.fontWeight);
          expect(hyphen.locale, before.locale);
        }
        for (
          var offset = 0;
          offset <= presentation.sourceText.length;
          offset++
        ) {
          expect(presentation.toSource(presentation.toDisplay(offset)), offset);
        }
        expect(presentation.span.toPlainText(), source.toPlainText());
        expect(
          lines.every((line) => line.width <= width + 0.001),
          isTrue,
          reason: 'width $width',
        );
        painter.dispose();
      }
    },
  );

  test(
    'reader palette keeps highlights and links at original source offsets',
    () {
      final source = applyHighlightRanges(
        const TextSpan(text: 'associate'),
        20,
        [HighlightRange(startOffset: 22, endOffset: 26, color: '#FF0000')],
      );
      final colored = applyReaderPalette(
        source,
        20,
        Colors.white,
        Colors.blue,
        [(22, 26)],
      );
      final presentation = ReaderTextPresentation(
        source: colored,
        hyphenationOffsets: [2, 4],
        firstLineIndent: 24,
        maxWidth: 80,
        baseStyle: const TextStyle(fontSize: 16),
      );
      expect(presentation.span.toPlainText(), 'associate');
      final style = _effectiveStyleAt(
        presentation.span,
        presentation.toDisplay(3),
      );
      expect(style.color, Colors.blue);
      expect(style.backgroundColor, const Color(0xffff0000).withAlpha(90));
      expect(colored.toPlainText(), source.toPlainText());
      expect(presentation.toSource(presentation.toDisplay(6)), 6);
    },
  );
}
