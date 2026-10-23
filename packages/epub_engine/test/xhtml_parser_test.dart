import 'dart:convert';
import 'dart:typed_data';

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
          final block =
              XhtmlParser(
                html: html,
                images: const {},
                baseStyle: baseStyle,
              ).parse().whereType<TextBlock>().firstWhere(
                (block) => block.span.toPlainText().contains('text'),
              );
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
          expect(text.trimLeft(), 'Open destinationafterendinline');
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
    test('inline and SVG images keep text order and resolve full resource paths', () {
      final correct = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final other = Uint8List.fromList([9, 8, 7]);
      for (final prefix in [
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title/></head><body>',
        '<html><body><br>',
      ]) {
        final parser = XhtmlParser(
          html:
              '$prefix<p>Before<img src="../images/my%20cover.png?size=1#part"/>'
              '<b>between</b><svg viewBox="0 0 1 1" xmlns:xlink="http://www.w3.org/1999/xlink">'
              '<image width="1" height="1" xlink:href="../images/my%20cover.png"/></svg>After</p>'
              '<p id="end">End</p></body></html>',
          documentPath: 'OPS/text/chapter.xhtml',
          images: {
            'other/my cover.png': other,
            'OPS/images/my cover.png': correct,
          },
          baseStyle: baseStyle,
        );
        final blocks = parser
            .parse()
            .where(
              (element) =>
                  element is! TextBlock ||
                  element.span.toPlainText().trim().isNotEmpty,
            )
            .toList();
        expect(
          blocks.whereType<ImageBlock>().map((e) => e.bytes),
          everyElement(orderedEquals(correct)),
        );
        expect(
          blocks
              .map((e) => e is TextBlock ? e.span.toPlainText() : '[image]')
              .join(),
          'Before[image]between[image]AfterEnd',
        );
        final start = blocks.first.charStart;
        expect(blocks.last.charEnd - start, 'BeforebetweenAfterEnd'.length + 2);
        expect(parser.anchors['end'], start + 'BeforebetweenAfter'.length + 2);
      }
    });

    test(
      'resource lookup never substitutes another directory or suffix match',
      () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final blocks = XhtmlParser(
          html: '<p><img src="cover.png"/></p>',
          documentPath: 'OPS/text/chapter.xhtml',
          images: {'other/cover.png': bytes, 'OPS/text/not-cover.png': bytes},
          baseStyle: baseStyle,
        ).parse();
        expect(blocks.whereType<ImageBlock>(), isEmpty);
      },
    );

    test('nested lists preserve items, depth and explicit numbering', () {
      final blocks = XhtmlParser(
        html:
            '<ul><li>First<p>Continuation</p><ul><li>Nested</li></ul></li>'
            '<li>Second</li><li>Third</li></ul>'
            '<ol start="7"><li>Seven</li><li value="12">Twelve</li></ol>',
        images: const {},
        baseStyle: baseStyle,
      ).parse().whereType<TextBlock>().toList();
      expect(blocks.map((e) => e.span.toPlainText()), [
        '• First',
        'Continuation',
        '• Nested',
        '• Second',
        '• Third',
        '7. Seven',
        '12. Twelve',
      ]);
      expect(blocks[2].indent, greaterThan(blocks[0].indent));
      expect(blocks[3].indent, blocks[0].indent);
      var offset = 0;
      for (final block in blocks) {
        expect(block.charStart, offset);
        offset += block.span.toPlainText().length;
        expect(block.charEnd, offset);
      }
    });

    test('quote paragraphs stay separate without swallowing linked text', () {
      final parser = XhtmlParser(
        html:
            '<blockquote><p>First.</p><p><a href="#last">Second.</a></p>'
            '</blockquote><p id="last">Last.</p>',
        images: const {},
        baseStyle: baseStyle,
      );
      final blocks = parser.parse().whereType<TextBlock>().toList();
      expect(blocks.map((e) => e.span.toPlainText()), [
        'First.',
        'Second.',
        'Last.',
      ]);
      expect(blocks[0].indent, greaterThan(blocks.last.indent));
      expect(blocks[1].indent, blocks[0].indent);
      expect(parser.links.single.startOffset, 'First.'.length);
      expect(parser.links.single.endOffset, 'First.Second.'.length);
      expect(parser.anchors['last'], 'First.Second.'.length);
    });

    test('table cells retain grid spans and reading-order offsets', () {
      final parser = XhtmlParser(
        html:
            '<table><tr><th rowspan="2">Category</th><th colspan="2">Prices</th>'
            '</tr><tr><td><p id="bread">Bread</p><p>Fresh</p></td><td>50</td></tr>'
            '<tr><td>Other</td><td colspan="2"><a href="#bread">Back</a></td></tr>'
            '</table>',
        images: const {},
        baseStyle: baseStyle,
      );
      final table = parser.parse().whereType<TableBlock>().single;
      expect(table.rowCount, 3);
      expect(table.columnCount, 3);
      expect(
        table.cells.map((c) => (c.row, c.column, c.rowSpan, c.columnSpan)),
        [
          (0, 0, 2, 1),
          (0, 1, 1, 2),
          (1, 1, 1, 1),
          (1, 2, 1, 1),
          (2, 0, 1, 1),
          (2, 1, 1, 2),
        ],
      );
      final text = contentLeaves([table]).whereType<TextBlock>().toList();
      expect(
        text.map((e) => e.span.toPlainText()).join(),
        'CategoryPricesBreadFresh50OtherBack',
      );
      expect(parser.anchors['bread'], 'CategoryPrices'.length);
      final link = parser.links.single;
      expect(link.startOffset, 'CategoryPricesBreadFresh50Other'.length);
      expect(link.endOffset, table.charEnd);
      expect(text[2].charEnd, text[3].charStart);
    });

    test(
      'external classes style headings and footnotes while hidden text is absent',
      () {
        final parser = XhtmlParser(
          html:
              '<html><head><title/><link rel="stylesheet" href="../styles/book.css"/>'
              '</head><body><div class="title1"><p>Heading</p></div>'
              '<p>Text<span class="hidden">SECRET</span>'
              '<a class="note" href="#note">[1]</a></p>'
              '<p id="note">Note</p></body></html>',
          documentPath: 'OPS/text/chapter.xhtml',
          stylesheets: const {
            'OPS/styles/book.css':
                '.title1 { font-size: 2em; font-weight: bold; '
                'text-align: center } .note { font-size: .7em; vertical-align: super } '
                '.hidden { display: none }',
          },
          images: const {},
          baseStyle: baseStyle,
        );
        final blocks = parser.parse().whereType<TextBlock>().toList();
        expect(
          blocks.map((e) => e.span.toPlainText()).join(),
          'HeadingText[1]Note',
        );
        final heading = blocks.first.span as TextSpan;
        expect(heading.style!.fontSize, 32);
        expect(heading.style!.fontWeight, FontWeight.bold);
        expect(blocks.first.textAlign, TextAlign.center);
        final body = blocks[1].span as TextSpan;
        final note = body.children!.last as TextSpan;
        expect(note.style!.fontSize, closeTo(11.2, 0.001));
        expect(
          note.style!.fontFeatures,
          contains(const FontFeature.superscripts()),
        );
        expect(parser.links.single.startOffset, 'HeadingText'.length);
        expect(parser.anchors['note'], 'HeadingText[1]'.length);
      },
    );
    test('explicit leading and empty paragraph line breaks remain visible', () {
      final parser = XhtmlParser(
        html:
            '<html><body><p><br/>Text<a href="#end">go</a></p>'
            '<p><br/></p><p id="end">End</p></body></html>',
        images: const {},
        baseStyle: baseStyle,
      );
      final blocks = parser.parse().whereType<TextBlock>().toList();
      expect(blocks.map((block) => block.span.toPlainText()), [
        '\nTextgo',
        '\n',
        'End',
      ]);
      expect(parser.links.single.startOffset, '\nText'.length);
      expect(parser.anchors['end'], '\nTextgo\n'.length);
    });

    test(
      'unresolved objects retain fallback paragraphs, links and anchors',
      () {
        final parser = XhtmlParser(
          html:
              '<object data="missing.svg"><p>Diagram description</p>'
              '<p><a href="#detail">Read detail</a></p></object>'
              '<p id="detail">Detail</p>',
          images: const {},
          baseStyle: baseStyle,
        );
        final text = parser
            .parse()
            .whereType<TextBlock>()
            .map((block) => block.span.toPlainText())
            .toList();
        expect(text, ['Diagram description', 'Read detail', 'Detail']);
        expect(parser.links.single.href, '#detail');
        expect(
          parser.anchors['detail'],
          'Diagram descriptionRead detail'.length,
        );
      },
    );

    test(
      'table rowspans stop at row groups and caption anchors remain navigable',
      () {
        for (final span in [0, 99]) {
          final parser = XhtmlParser(
            html:
                '<html><body><p>Intro</p><table><caption id="prices">Prices</caption>'
                '<thead><tr><th rowspan="$span">Header</th><th>One</th></tr>'
                '<tr><th>Two</th></tr></thead><tbody>'
                '<tr><td>A</td><td>B</td></tr></tbody></table></body></html>',
            images: const {},
            baseStyle: baseStyle,
          );
          final table = parser.parse().whereType<TableBlock>().single;
          expect(table.columnCount, 2);
          expect(table.cells.first.rowSpan, 2);
          expect(table.cells[3].row, 2);
          expect(table.cells[3].column, 0);
          expect(parser.anchors['prices'], 'Intro'.length);
        }
      },
    );
  });
}
