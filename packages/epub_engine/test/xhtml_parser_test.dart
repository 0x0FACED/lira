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
  });
}
