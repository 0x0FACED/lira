import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:epub_engine/src/epub_parser.dart';
import 'package:epub_engine/src/epub_paths.dart';
import 'package:epub_engine/src/xhtml_parser.dart';
import 'package:flutter/material.dart' show TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  group('EpubParser reading order', () {
    test('does not discard stockholm.xhtml as a TOC file', () async {
      final documents = {
        'stockholm.xhtml': _document('Stockholm', '<p>Стокгольм: начало.</p>'),
        'chapter2.xhtml': _document(
          'Departure',
          '<p>The journey continues.</p>',
        ),
      };
      final spine = ['stockholm.xhtml', 'chapter2.xhtml'];

      final parsed = await EpubParser.parse(
        _epub(
          documents: documents,
          spine: spine,
          ncxPoints: '''
            <navPoint id="stockholm" playOrder="1">
              <navLabel><text>Stockholm</text></navLabel>
              <content src="stockholm.xhtml"/>
            </navPoint>
            <navPoint id="departure" playOrder="2">
              <navLabel><text>Departure</text></navLabel>
              <content src="chapter2.xhtml"/>
            </navPoint>
          ''',
        ),
      );

      _expectChapters(parsed, documents, spine, [
        'Стокгольм: начало.',
        'The journey continues.',
      ]);
      expect(parsed.title, 'Fixture Book');
      expect(parsed.author, 'Автор & Author');
    });

    test('keeps cover-like names and front matter in the spine', () async {
      final documents = {
        'cover.xhtml': _document('Cover', '<p>Words on the cover.</p>'),
        'titlepage.xhtml': _document('Title', '<p>The complete title.</p>'),
        'copyright.xhtml': _document('Rights', '<p>Publication details.</p>'),
        'undercover.xhtml': _document('Undercover', '<p>The first scene.</p>'),
        'chapter.xhtml': _document('Chapter', '<p>The second scene.</p>'),
      };
      final spine = documents.keys.toList();

      final parsed = await EpubParser.parse(
        _epub(
          documents: documents,
          spine: spine,
          ncxPoints: '''
            <navPoint id="chapter" playOrder="1">
              <navLabel><text>Chapter</text></navLabel>
              <content src="chapter.xhtml"/>
            </navPoint>
          ''',
        ),
      );

      _expectChapters(parsed, documents, spine, [
        'Words on the cover.',
        'The complete title.',
        'Publication details.',
        'The first scene.',
        'The second scene.',
      ]);
    });

    test(
      'keeps documents absent from TOC in spine, not manifest order',
      () async {
        final documents = {
          'last.xhtml': _document('Last', '<p>The ending.</p>'),
          'unlisted.xhtml': _document('Unlisted', '<p>The missing middle.</p>'),
          'first.xhtml': _document('First', '<p>The beginning.</p>'),
        };
        final spine = ['first.xhtml', 'unlisted.xhtml', 'last.xhtml'];

        final parsed = await EpubParser.parse(
          _epub(
            documents: documents,
            spine: spine,
            ncxPoints: '''
            <navPoint id="last" playOrder="1">
              <navLabel><text>Last</text></navLabel>
              <content src="last.xhtml"/>
            </navPoint>
            <navPoint id="first" playOrder="2">
              <navLabel><text>First</text></navLabel>
              <content src="first.xhtml"/>
            </navPoint>
          ''',
          ),
        );

        _expectChapters(parsed, documents, spine, [
          'The beginning.',
          'The missing middle.',
          'The ending.',
        ]);
        expect(parsed.chapters[1].title, 'Unlisted');
        expect(parsed.toc.map((item) => item.fileName), [
          'OEBPS/last.xhtml',
          'OEBPS/first.xhtml',
        ]);
      },
    );

    test(
      'preserves nested NCX anchors without duplicating or reordering text',
      () async {
        final documents = {
          'first.xhtml': _document(
            'First',
            '<p id="intro">First section.</p><p id="later">Later section.</p>',
          ),
          'second.xhtml': _document(
            'Second',
            '<p id="start">Second chapter.</p><p id="end">The end.</p>',
          ),
        };
        final spine = ['first.xhtml', 'second.xhtml'];

        final parsed = await EpubParser.parse(
          _epub(
            documents: documents,
            spine: spine,
            ncxPoints: '''
            <navPoint id="book" playOrder="1">
              <navLabel><text>Fixture Book</text></navLabel>
              <content src="second.xhtml#start"/>
              <navPoint id="intro" playOrder="2">
                <navLabel><text>Introduction</text></navLabel>
                <content src="first.xhtml#intro"/>
              </navPoint>
              <navPoint id="later" playOrder="3">
                <navLabel><text>Later</text></navLabel>
                <content src="first.xhtml#later"/>
                <navPoint id="end" playOrder="4">
                  <navLabel><text>Ending</text></navLabel>
                  <content src="second.xhtml#end"/>
                </navPoint>
              </navPoint>
            </navPoint>
          ''',
          ),
        );

        _expectChapters(parsed, documents, spine, [
          'First section.Later section.',
          'Second chapter.The end.',
        ]);
        expect(parsed.toc, hasLength(1));
        final root = parsed.toc.single;
        expect(root.title, 'Fixture Book');
        expect(root.fileName, 'OEBPS/second.xhtml#start');
        expect(root.subItems.map((item) => item.title), [
          'Introduction',
          'Later',
        ]);
        expect(root.subItems.map((item) => item.fileName), [
          'OEBPS/first.xhtml#intro',
          'OEBPS/first.xhtml#later',
        ]);
        expect(root.subItems.first.subItems, isEmpty);
        final ending = root.subItems.last.subItems.single;
        expect(ending.title, 'Ending');
        expect(ending.fileName, 'OEBPS/second.xhtml#end');
      },
    );

    test('keeps EPUB3 navigation separate from the spine', () async {
      final documents = {
        'text/naval.xhtml': _document(
          'Naval',
          '<p id="first">At sea.</p><p id="second">Still at sea.</p>',
        ),
        'text/arrival.xhtml': _document('Arrival', '<p id="port">In port.</p>'),
      };
      final spine = ['text/naval.xhtml', 'text/arrival.xhtml'];

      final parsed = await EpubParser.parse(
        _epub(
          documents: documents,
          spine: spine,
          navigation: '''
            <nav epub:type="toc">
              <ol>
                <li>
                  <a href="text/arrival.xhtml#port">Arrival</a>
                  <ol>
                    <li><a href="text/naval.xhtml#first">At sea</a></li>
                    <li><a href="text/naval.xhtml#second">Still at sea</a></li>
                  </ol>
                </li>
              </ol>
            </nav>
          ''',
        ),
      );

      _expectChapters(parsed, documents, spine, [
        'At sea.Still at sea.',
        'In port.',
      ]);
      final root = parsed.toc.single;
      expect(root.title, 'Arrival');
      expect(root.fileName, 'OEBPS/text/arrival.xhtml#port');
      expect(root.subItems.map((item) => item.fileName), [
        'OEBPS/text/naval.xhtml#first',
        'OEBPS/text/naval.xhtml#second',
      ]);
    });

    for (final includeSpine in [true, false]) {
      test(
        'recovers document order with ${includeSpine ? 'empty' : 'absent'} spine',
        () async {
          final documents = {
            'stockholm.xhtml': _document('Stockholm', '<p>Start.</p>'),
            'cover.xhtml': _document('Cover notes', '<p>Cover notes.</p>'),
          };

          final parsed = await EpubParser.parse(
            _epub(documents: documents, spine: [], includeSpine: includeSpine),
          );

          _expectChapters(parsed, documents, documents.keys.toList(), [
            'Start.',
            'Cover notes.',
          ]);
          expect(parsed.toc.map((item) => item.fileName), [
            'OEBPS/stockholm.xhtml',
            'OEBPS/cover.xhtml',
          ]);
        },
      );
    }
  });

  group('EpubParser corrupted content', () {
    test(
      'rejects a missing manifest item instead of returning partial text',
      () async {
        final bytes = _epub(
          documents: {'chapter.xhtml': _document('Chapter', '<p>Present.</p>')},
          spine: ['chapter.xhtml', 'missing-manifest-id'],
        );

        await expectLater(
          EpubParser.parse(bytes),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'EPUB spine item "missing-manifest-id" is missing from the manifest',
            ),
          ),
        );
      },
    );

    test(
      'rejects an empty spine item reference instead of manifest recovery',
      () async {
        final bytes = _epub(
          documents: {'chapter.xhtml': _document('Chapter', '<p>Present.</p>')},
          spine: [''],
        );

        await expectLater(
          EpubParser.parse(bytes),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'EPUB spine itemref is missing idref',
            ),
          ),
        );
      },
    );

    test(
      'rejects a missing spine document instead of returning partial text',
      () async {
        final bytes = _epub(
          documents: {
            'chapter.xhtml': _document('Chapter', '<p>Present.</p>'),
            'missing.xhtml': _document('Missing', '<p>Must not disappear.</p>'),
          },
          spine: ['chapter.xhtml', 'missing.xhtml'],
          omittedDocuments: {'missing.xhtml'},
        );

        await expectLater(
          EpubParser.parse(bytes),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'EPUB spine document not found: OEBPS/missing.xhtml',
            ),
          ),
        );
      },
    );

    test(
      'rejects an empty spine document instead of returning partial text',
      () async {
        final bytes = _epub(
          documents: {
            'chapter.xhtml': _document('Chapter', '<p>Present.</p>'),
            'empty.xhtml': ' \n\t ',
          },
          spine: ['chapter.xhtml', 'empty.xhtml'],
        );

        await expectLater(
          EpubParser.parse(bytes),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'EPUB spine document is empty: OEBPS/empty.xhtml',
            ),
          ),
        );
      },
    );

    test('rejects books with no readable documents after recovery', () async {
      for (final documents in <Map<String, String>>[
        {},
        {'empty.xhtml': ' \n\t '},
      ]) {
        await expectLater(
          EpubParser.parse(_epub(documents: documents, spine: [])),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'EPUB contains no readable documents',
            ),
          ),
        );
      }
    });
  });

  for (final endian in [Endian.little, Endian.big]) {
    final label = endian == Endian.little ? 'LE' : 'BE';
    test(
      'preserves UTF-16 $label package, metadata and chapter text',
      () async {
        final document = _document('Глава 😀', '<p>Текст без потерь 😀</p>');
        final parsed = await EpubParser.parse(
          _epub(
            documents: {'chapter.xhtml': document},
            spine: ['chapter.xhtml'],
            textEndian: endian,
          ),
        );
        expect(parsed.author, 'Автор & Author');
        expect(parsed.chapters.single.htmlContent, document);
        expect(parsed.chapters.single.title, 'Глава 😀');
      },
    );

    test('recognizes UTF-16 $label XHTML without a BOM', () async {
      final document =
          '<?xml version="1.0" encoding="UTF-16"?>'
          '${_document('Глава 😀', '<p>Текст без потерь 😀</p>')}';
      final parsed = await EpubParser.parse(
        _epub(
          documents: {'chapter.xhtml': document},
          spine: ['chapter.xhtml'],
          rawText: {
            'OEBPS/chapter.xhtml': _utf16(document, endian, bom: false),
          },
        ),
      );
      expect(parsed.chapters.single.htmlContent, document);
      expect(parsed.chapters.single.title, 'Глава 😀');
    });
  }

  for (final malformed in <String, List<int>>{
    'UTF-8': [...utf8.encode('<p>'), 0xC3, 0x28, ...utf8.encode('</p>')],
    'truncated UTF-16': [0xFF, 0xFE, 0x3C],
    'unpaired UTF-16 surrogate': [0xFF, 0xFE, 0x00, 0xD8, 0x41, 0x00],
  }.entries) {
    test(
      'rejects ${malformed.key} instead of replacing book characters',
      () async {
        await expectLater(
          EpubParser.parse(
            _epub(
              documents: {'chapter.xhtml': '<p>Original text</p>'},
              spine: ['chapter.xhtml'],
              rawText: {'OEBPS/chapter.xhtml': malformed.value},
            ),
          ),
          throwsFormatException,
        );
      },
    );
  }

  for (final declaration in ['metadata', 'property', 'filename']) {
    test(
      'preserves images and $declaration cover without using cover XHTML',
      () async {
        final documents = {
          'cover.xhtml': _document('Cover', '<p>The cover text remains.</p>'),
          'chapter.xhtml': _document(
            'Chapter',
            '<p>The chapter text remains.</p>',
          ),
        };
        final imagePath = declaration == 'filename'
            ? 'images/book-cover.png'
            : 'images/front.png';
        final coverBytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        );
        final illustrationBytes = coverBytes;

        final parsed = await EpubParser.parse(
          _epub(
            documents: documents,
            spine: documents.keys.toList(),
            images: {
              imagePath: coverBytes,
              'images/illustration.png': illustrationBytes,
            },
            coverImage: imagePath,
            coverDeclaration: declaration,
          ),
        );

        _expectChapters(parsed, documents, documents.keys.toList(), [
          'The cover text remains.',
          'The chapter text remains.',
        ]);
        expect(parsed.coverImage, orderedEquals(coverBytes));
        expect(parsed.images['OEBPS/$imagePath'], orderedEquals(coverBytes));
        expect(
          parsed.images['OEBPS/images/illustration.png'],
          orderedEquals(illustrationBytes),
        );
      },
    );
  }

  test(
    'keeps same-basename illustrations distinct at their resolved paths',
    () async {
      final parsed = await EpubParser.parse(
        _epub(
          documents: {
            'Text/one.xhtml': _document(
              'One',
              '<p><img src="../Images/one/figure.png"/></p>',
            ),
            'Text/two.xhtml': _document(
              'Two',
              '<p><img src="../Images/two/figure.png"/></p>',
            ),
          },
          spine: ['Text/one.xhtml', 'Text/two.xhtml'],
          images: {
            'Images/one/figure.png': [1, 2, 3],
            'Images/two/figure.png': [4, 5, 6],
          },
        ),
      );
      for (var index = 0; index < parsed.chapters.length; index++) {
        final chapter = parsed.chapters[index];
        final src = XmlDocument.parse(chapter.htmlContent).descendants
            .whereType<XmlElement>()
            .singleWhere((element) => element.name.local == 'img')
            .getAttribute('src')!;
        expect(
          parsed.images[resolveEpubPath(chapter.fileName, src)],
          orderedEquals(index == 0 ? [1, 2, 3] : [4, 5, 6]),
        );
      }
    },
  );

  test(
    'renders distinct raw percent and space ZIP image names from escaped URIs',
    () async {
      final parsed = await EpubParser.parse(
        _epub(
          documents: {
            'Text/chapter.xhtml': _document(
              'Chapter',
              '<p><img src="../Images/figure%2520one.png"/>'
                  '<img src="../Images/figure%20one.png"/></p>',
            ),
          },
          spine: ['Text/chapter.xhtml'],
          images: {
            'Images/figure%20one.png': [1, 2, 3],
            'Images/figure one.png': [4, 5, 6],
          },
          imageHrefs: {
            'Images/figure%20one.png': 'Images/figure%2520one.png',
            'Images/figure one.png': 'Images/figure%20one.png',
          },
        ),
      );
      final chapter = parsed.chapters.single;
      final rendered = XhtmlParser(
        html: chapter.htmlContent,
        documentPath: chapter.fileName,
        images: parsed.images,
        baseStyle: const TextStyle(fontSize: 16),
      ).parse().whereType<ImageBlock>().toList();
      expect(rendered, hasLength(2));
      expect(rendered[0].bytes, orderedEquals([1, 2, 3]));
      expect(rendered[1].bytes, orderedEquals([4, 5, 6]));
    },
  );

  test(
    'loads linked CSS and percent-encoded resource paths canonically',
    () async {
      const css = 'div.title1 { font-weight: bold; } /* Заголовок 😀 */';
      final parsed = await EpubParser.parse(
        _epub(
          documents: {
            'Text/chapter%20one.xhtml': _document(
              'Chapter',
              '<p><img src="../Images/figure%20one.png?size=2#preview"/></p>',
            ),
          },
          spine: ['Text/chapter%20one.xhtml'],
          images: {
            'Images/figure one.png': [7, 8, 9],
          },
          stylesheets: {'Styles/book%20styles.css': css},
          rawText: {
            'OEBPS/Styles/book%20styles.css': _utf16(css, Endian.little),
          },
        ),
      );
      final chapter = parsed.chapters.single;
      expect(chapter.fileName, 'OEBPS/Text/chapter one.xhtml');
      final stylesheetPath = resolveEpubPath(
        chapter.fileName,
        '../Styles/book%20styles.css',
      );
      expect(parsed.stylesheets[stylesheetPath], css);
      expect(
        parsed.images[resolveEpubPath(
          chapter.fileName,
          '../Images/figure%20one.png?size=2#preview',
        )],
        orderedEquals([7, 8, 9]),
      );
    },
  );

  test(
    'TOC locators escape reserved filename characters without changing title lookup',
    () async {
      final parsed = await EpubParser.parse(
        _epub(
          documents: {
            'Text/a%23b%2520c.xhtml': _document(
              'Original',
              '<p id="deep anchor">Destination</p>',
            ),
          },
          spine: ['Text/a%23b%2520c.xhtml'],
          navigation:
              '<nav epub:type="toc"><ol><li>'
              '<a href="Text/a%23b%2520c.xhtml#deep%20anchor">Named destination</a>'
              '</li></ol></nav>',
        ),
      );
      final locator = parsed.toc.single.fileName;
      expect(resolveEpubPath('', locator), parsed.chapters.single.fileName);
      expect(Uri.decodeComponent(Uri.parse(locator).fragment), 'deep anchor');
      expect(parsed.chapters.single.title, 'Named destination');
      expect(locator, contains('%23'));
      expect(locator, contains('%2520'));
    },
  );

  group('EPUB local resource paths', () {
    test('resolves dots, escaping, backslashes, root paths and fragments', () {
      expect(
        resolveEpubPath(
          'OPS/Text/chapter.xhtml',
          r'..\\Images\\cover%20one.png?x=1#y',
        ),
        'OPS/Images/cover one.png',
      );
      expect(
        resolveEpubPath('OPS/Text/chapter.xhtml', '/Images/a%23b.png'),
        'Images/a#b.png',
      );
      expect(
        resolveEpubPath('OPS/Text/chapter.xhtml', '#footnote'),
        'OPS/Text/chapter.xhtml',
      );
      expect(
        resolveEpubPath('OPS/Text/chapter.xhtml', '../Images/%2e%2e/cover.png'),
        'OPS/cover.png',
      );
    });

    test('rejects remote, data and protocol-relative references', () {
      for (final href in [
        'https://example.com/cover.png',
        '//example.com/cover.png',
        'data:image/png;base64,AA==',
        'file:///tmp/cover.png',
      ]) {
        expect(resolveEpubPath('OPS/chapter.xhtml', href), isNull);
      }
    });

    test('does not lowercase distinct archive resource names', () {
      expect(
        resolveEpubPath('OPS/chapter.xhtml', 'Images/Cover.png'),
        isNot(resolveEpubPath('OPS/chapter.xhtml', 'Images/cover.png')),
      );
    });

    test('does not decode an already canonical document directory twice', () {
      const documentPath = 'OPS/notes%20source/chapter.xhtml';
      expect(
        normalizeEpubArchivePath('OPS/figure%20one.png'),
        'OPS/figure%20one.png',
      );
      expect(
        resolveEpubPath(documentPath, 'figure.png'),
        'OPS/notes%20source/figure.png',
      );
      expect(resolveEpubPath(documentPath, '#note'), documentPath);
    });
  });
}

void _expectChapters(
  ParsedEpub parsed,
  Map<String, String> documents,
  List<String> spine,
  List<String> texts,
) {
  expect(parsed.chapters.map((chapter) => chapter.fileName), [
    for (final path in spine) 'OEBPS/$path',
  ]);
  expect(parsed.chapters.map((chapter) => chapter.htmlContent), [
    for (final path in spine) documents[path],
  ]);
  expect(
    parsed.chapters.map(
      (chapter) => XmlDocument.parse(chapter.htmlContent).descendants
          .whereType<XmlElement>()
          .singleWhere((element) => element.name.local == 'body')
          .innerText,
    ),
    texts,
  );
}

String _document(String title, String body) =>
    '<html xmlns="http://www.w3.org/1999/xhtml">'
    '<head><title>${_escape(title)}</title></head><body>$body</body></html>';

String _escape(String value) => const HtmlEscape().convert(value);

Uint8List _utf16(String text, Endian endian, {bool bom = true}) {
  final start = bom ? 2 : 0;
  final data = ByteData(start + text.length * 2);
  if (bom) data.setUint16(0, 0xFEFF, endian);
  for (var index = 0; index < text.length; index++) {
    data.setUint16(start + index * 2, text.codeUnitAt(index), endian);
  }
  return data.buffer.asUint8List();
}

Uint8List _epub({
  required Map<String, String> documents,
  required List<String> spine,
  bool includeSpine = true,
  Set<String> omittedDocuments = const {},
  Endian? textEndian,
  Map<String, List<int>> rawText = const {},
  String? ncxPoints,
  String? navigation,
  Map<String, List<int>> images = const {},
  Map<String, String> stylesheets = const {},
  Map<String, String> imageHrefs = const {},
  String? coverImage,
  String coverDeclaration = 'metadata',
}) {
  final archive = Archive();

  void addBytes(String path, List<int> bytes, {bool compress = true}) {
    archive.addFile(
      ArchiveFile(path, bytes.length, bytes)..compress = compress,
    );
  }

  void addText(String path, String text) {
    final bytes =
        rawText[path] ??
        (textEndian == null
            ? utf8.encode(text)
            : _utf16(
                text.replaceAll('encoding="UTF-8"', 'encoding="UTF-16"'),
                textEndian,
              ));
    addBytes(path, bytes);
  }

  addBytes('mimetype', utf8.encode('application/epub+zip'), compress: false);
  addText(
    'META-INF/container.xml',
    '''
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
  '''
        .trim(),
  );

  final documentIds = <String, String>{};
  for (final path in documents.keys) {
    documentIds[path] = 'document-${documentIds.length}';
  }
  final imageIds = <String, String>{};
  for (final path in images.keys) {
    imageIds[path] = 'image-${imageIds.length}';
  }
  final metadataCover = coverImage != null && coverDeclaration == 'metadata'
      ? '<meta name="cover" content="${imageIds[coverImage]}"/>'
      : '';
  final manifest = StringBuffer();
  for (final entry in documents.entries) {
    manifest.write(
      '<item id="${documentIds[entry.key]}" href="${_escape(entry.key)}" '
      'media-type="application/xhtml+xml"/>',
    );
    if (!omittedDocuments.contains(entry.key)) {
      addText('OEBPS/${entry.key}', entry.value);
    }
  }
  for (final entry in images.entries) {
    final properties = entry.key == coverImage && coverDeclaration == 'property'
        ? ' properties="cover-image"'
        : '';
    manifest.write(
      '<item id="${imageIds[entry.key]}" href="${_escape(imageHrefs[entry.key] ?? entry.key)}" '
      'media-type="image/png"$properties/>',
    );
    addBytes('OEBPS/${entry.key}', entry.value);
  }
  for (final entry in stylesheets.entries) {
    manifest.write(
      '<item id="stylesheet-${manifest.length}" href="${_escape(entry.key)}" '
      'media-type="text/css"/>',
    );
    addText('OEBPS/${entry.key}', entry.value);
  }
  if (ncxPoints != null) {
    manifest.write(
      '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
    );
    addText('OEBPS/toc.ncx', '''
      <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
        <head><meta name="dtb:uid" content="fixture"/></head>
        <docTitle><text>Fixture Book</text></docTitle>
        <navMap>$ncxPoints</navMap>
      </ncx>
    ''');
  }
  if (navigation != null) {
    manifest.write(
      '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
    );
    addText('OEBPS/nav.xhtml', '''
      <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><title>Contents</title></head><body>$navigation</body>
      </html>
    ''');
  }
  final spineItems = spine
      .map((path) => '<itemref idref="${documentIds[path] ?? _escape(path)}"/>')
      .join();
  final spineToc = ncxPoints == null ? '' : ' toc="ncx"';
  final spineElement = includeSpine
      ? '<spine$spineToc>$spineItems</spine>'
      : '';
  final version = navigation != null || coverDeclaration == 'property'
      ? '3.0'
      : '2.0';
  addText('OEBPS/content.opf', '''
    <package xmlns="http://www.idpf.org/2007/opf" version="$version" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="uid">fixture</dc:identifier>
        <dc:title>Fixture Book</dc:title>
        <dc:creator>Автор &amp; Author</dc:creator>
        <dc:language>en</dc:language>
        $metadataCover
      </metadata>
      <manifest>$manifest</manifest>
      $spineElement
    </package>
  ''');
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
