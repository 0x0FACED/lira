import 'package:epub_engine/src/xhtml_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseStyle = TextStyle(fontSize: 16, color: Colors.black);

  group('XhtmlParser', () {
    test('parses direct text inside div containers', () {
      final parser = XhtmlParser(
        html: '''
          <html>
            <body>
              <div class="paragraph">Он вошел в комнату и огляделся.</div>
            </body>
          </html>
        ''',
        images: const {},
        baseStyle: baseStyle,
      );

      final blocks = parser.parse().whereType<TextBlock>().toList(
        growable: false,
      );

      expect(blocks, hasLength(1));
      expect(
        blocks.single.span.toPlainText(includeSemanticsLabels: false),
        contains('Он вошел в комнату и огляделся.'),
      );
    });

    test('unwraps span wrappers with nested block children', () {
      final parser = XhtmlParser(
        html: '''
          <html>
            <body>
              <span id="id1">
                <div><p>Chapter 1</p></div>
                <p>First paragraph.</p>
                <p>Second paragraph.</p>
              </span>
            </body>
          </html>
        ''',
        images: const {},
        baseStyle: baseStyle,
      );

      final blocks = parser
          .parse()
          .whereType<TextBlock>()
          .map(
            (block) =>
                block.span.toPlainText(includeSemanticsLabels: false).trim(),
          )
          .where((text) => text.isNotEmpty)
          .toList(growable: false);

      expect(blocks, hasLength(3));
      expect(
        blocks,
        containsAllInOrder([
          'Chapter 1',
          'First paragraph.',
          'Second paragraph.',
        ]),
      );
    });

    test(
      'parses chapter structure similar to problematic Martin Eden EPUB',
      () {
        final parser = XhtmlParser(
          html: '''
          <?xml version="1.0" encoding="UTF-8"?>
          <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
              <title/>
              <link rel="stylesheet" href="style.css" type="text/css"/>
            </head>
            <body class="z">
              <span id="id1">
                <div class="title1">
                  <p class="p">Chapter 1</p>
                </div>
                <p class="empty-line"/>
                <div class="image">
                  <img alt="" src="images/_1.jpg"/>
                </div>
                <p class="empty-line"/>
                <p class="p1">He opened the door with a key and went in.</p>
                <p class="p1">The wide rooms seemed too narrow for him.</p>
                <p class="p1">"Hold on, Arthur," he said.</p>
              </span>
            </body>
          </html>
        ''',
          images: const {},
          baseStyle: baseStyle,
        );

        final blocks = parser.parse().whereType<TextBlock>().toList(
          growable: false,
        );
        final texts = blocks
            .map(
              (block) =>
                  block.span.toPlainText(includeSemanticsLabels: false).trim(),
            )
            .where((text) => text.isNotEmpty)
            .toList(growable: false);

        expect(texts, contains('Chapter 1'));
        expect(texts, contains('He opened the door with a key and went in.'));
        expect(texts, contains('The wide rooms seemed too narrow for him.'));
        expect(texts, contains('"Hold on, Arthur," he said.'));
      },
    );

    test('mixed block and inline content keeps every text run in order', () {
      final parser = XhtmlParser(
        html:
            '<body><div>before <b>bold</b><p>paragraph</p> after</div></body>',
        images: const {},
        baseStyle: baseStyle,
      );
      final blocks = parser.parse().whereType<TextBlock>().toList();
      expect(
        blocks.map((block) => block.span.toPlainText()).join(),
        'before boldparagraph after',
      );
      var offset = 0;
      for (final block in blocks) {
        expect(block.charStart, offset);
        offset += block.span.toPlainText().length;
        expect(block.charEnd, offset);
      }
    });

    test('fragment and link offsets describe rendered text, not markup', () {
      for (final html in [
        '<html xmlns="http://www.w3.org/1999/xhtml"><body>',
        '<html><body><br>',
      ]) {
        final parser = XhtmlParser(
          html:
              '$html<p>one <b id="inside">two</b> '
              '<a href="../next.xhtml#part">next <em>chapter</em></a></p>'
              '<p id="later">last</p></body></html>',
          images: const {},
          baseStyle: baseStyle,
        );
        final blocks = parser.parse().whereType<TextBlock>().toList();
        final text = blocks.map((block) => block.span.toPlainText()).join();
        final origin = blocks.first.charStart;
        expect(parser.anchors['inside'], origin + text.indexOf('two'));
        expect(parser.anchors['later'], origin + text.indexOf('last'));
        final link = parser.links.single;
        expect(link.href, '../next.xhtml#part');
        expect(
          text.substring(link.startOffset - origin, link.endOffset - origin),
          'next chapter',
        );
      }
    });

    test('crossing and nested highlights never alter styled source text', () {
      final parser = XhtmlParser(
        html: '<p>012<b>345<i>6789</i>AB</b>CDEFGHIJ</p>',
        images: const {},
        baseStyle: baseStyle,
        highlights: [
          HighlightRange(startOffset: 2, endOffset: 10, color: '#FFEB3B'),
          HighlightRange(startOffset: 6, endOffset: 15, color: '#42A5F5'),
          HighlightRange(startOffset: 7, endOffset: 8, color: '#FF0000'),
          HighlightRange(startOffset: 7, endOffset: 8, color: '#FF0000'),
          HighlightRange(startOffset: -3, endOffset: 3, color: '#FF0000'),
        ],
      );
      final block = parser.parse().whereType<TextBlock>().single;
      expect(block.span.toPlainText(), '0123456789ABCDEFGHIJ');
      expect(block.charEnd, 20);
    });

    test(
      'relative block styles are applied once before inline descendants',
      () {
        for (final html in [
          '<html><body><p style="font-size: 2em">text</p></body></html>',
          '<p style="font-size: 2em">text</p><br>',
          '<ul><li style="font-size: 2em">text</li></ul>',
        ]) {
          final block = XhtmlParser(
            html: html,
            images: const {},
            baseStyle: baseStyle,
          ).parse().whereType<TextBlock>().single;
          final span = block.span as TextSpan;
          final leaf = span.text == null
              ? span.children!.last as TextSpan
              : span;
          expect(leaf.style!.fontSize, 32);
        }
      },
    );

    test(
      'block-wrapping links retain exact ranges without duplicating inline links',
      () {
        for (final prefix in ['<html><body>', '<html><body><br>']) {
          final parser = XhtmlParser(
            html:
                '$prefix<a href="next.xhtml#part">'
                '<div>Open <strong>destination</strong></div><p>after</p></a>'
                '<p id="target">end</p><p><a href="#target">inline</a></p></body></html>',
            images: const {},
            baseStyle: baseStyle,
          );
          final blocks = parser.parse().whereType<TextBlock>().toList();
          final origin = blocks.first.charStart;
          final text = blocks.map((block) => block.span.toPlainText()).join();
          expect(text, 'Open destinationafterendinline');
          expect(parser.links, hasLength(2));
          final outer = parser.links.first;
          expect(outer.href, 'next.xhtml#part');
          expect(
            text.substring(
              outer.startOffset - origin,
              outer.endOffset - origin,
            ),
            'Open destinationafter',
          );
          final inline = parser.links.last;
          expect(
            text.substring(
              inline.startOffset - origin,
              inline.endOffset - origin,
            ),
            'inline',
          );
        }
      },
    );
  });
}
