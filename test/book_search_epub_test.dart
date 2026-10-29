import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/reader/domain/engine/epub_book_reader_engine.dart';
import 'package:lira/features/reader/domain/models/book_location.dart';
import 'package:lira/features/reader/domain/models/book_search.dart';

Uint8List _epub({
  required List<String> chapters,
  List<int>? spine,
  String? navigation,
  String stylesheet = '',
}) {
  final files = <String, String>{
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
    'OEBPS/content.opf':
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:title>Search regressions</dc:title></metadata><manifest>'
        '${List.generate(chapters.length, (index) => '<item id="chapter-$index" href="Text/chapter-$index.xhtml" media-type="application/xhtml+xml"/>').join()}'
        '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
        '<item id="css" href="styles.css" media-type="text/css"/>'
        '<item id="image" href="pixel.svg" media-type="image/svg+xml"/>'
        '</manifest><spine>'
        '${(spine ?? List.generate(chapters.length, (index) => index)).map((index) => '<itemref idref="chapter-$index"/>').join()}'
        '</spine></package>',
    'OEBPS/nav.xhtml':
        '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">'
        '<body><nav epub:type="toc"><ol>'
        '${navigation ?? List.generate(chapters.length, (index) => '<li><a href="Text/chapter-$index.xhtml">Section $index</a></li>').join()}'
        '</ol></nav></body></html>',
    'OEBPS/styles.css': stylesheet,
    'OEBPS/pixel.svg':
        '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1">'
        '<rect width="1" height="1"/></svg>',
    for (var index = 0; index < chapters.length; index++)
      'OEBPS/Text/chapter-$index.xhtml':
          '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
          '<title>Chapter $index</title>'
          '<link rel="stylesheet" href="../styles.css"/>'
          '</head><body>${chapters[index]}</body></html>',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

EpubLocation _location(BookSearchMatch match) =>
    EpubLocation.fromJson(match.location.locator)!;

void _expectRange(BookSearchMatch match, int start, int end) {
  final location = _location(match);
  expect(location.hasExactCharOffset, isTrue);
  expect(location.cfi.hasRange, isTrue);
  expect(location.charOffset, start);
  expect(location.startOffset, start);
  expect(location.endOffset, end);
  expect(jsonDecode(match.location.locator)['v'], 2);
}

bool _fragmentIsVisible(WidgetTester tester, String fragment) {
  const viewport = Rect.fromLTWH(0, 24, 600, 352);
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    final text = paragraph.text.toPlainText();
    final start = text.indexOf(fragment);
    if (start < 0) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + fragment.length),
    );
    if (boxes.any(
      (box) => box
          .toRect()
          .shift(paragraph.localToGlobal(Offset.zero))
          .overlaps(viewport),
    )) {
      return true;
    }
  }
  return false;
}

void main() {
  test('search uses spine order and ignores Russian and Latin case', () async {
    final engine = EpubBookReaderEngine();
    addTearDown(engine.dispose);
    await engine.loadBook(
      _epub(
        chapters: [
          '<p>ПРИВЕТ LATIN</p>',
          '<p>привет latin</p>',
          '<p>ПрИвЕт LaTiN</p>',
        ],
        spine: [2, 0, 1],
      ),
    );

    final result = await engine.search(BookSearchRequest('привет latin'));

    expect(result.hasText, isTrue);
    expect(result.matches.map((match) => match.sectionIndex), [0, 1, 2]);
    expect(result.matches.map((match) => match.sectionTitle), [
      'Section 2',
      'Section 0',
      'Section 1',
    ]);
    expect(result.matches.map((match) => match.excerpt.text), [
      'ПрИвЕт LaTiN',
      'ПРИВЕТ LATIN',
      'привет latin',
    ]);
    for (final match in result.matches) {
      _expectRange(match, 0, 'привет latin'.length);
    }
  });

  test('a phrase crosses styled spans and normalized whitespace', () async {
    final engine = EpubBookReaderEngine();
    addTearDown(engine.dispose);
    await engine.loadBook(
      _epub(
        chapters: ['<p>😀 &amp; ПрИ<b>вЕт</b>\n\t&#160; <em>LA</em>tin</p>'],
      ),
    );

    final result = await engine.search(BookSearchRequest('  привет   latin  '));

    expect(result.matches, hasLength(1));
    final match = result.matches.single;
    expect(match.excerpt.text, 'ПрИвЕт LAtin');
    expect(match.excerpt.before, '😀 & ');
    _expectRange(match, '😀 & '.length, '😀 & ПрИвЕт\n\t\u00a0 LAtin'.length);
  });

  test(
    'block boundaries separate words without shifting native ranges',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);
      await engine.loadBook(
        _epub(
          chapters: [
            '<p>alpha</p><p>beta</p>'
                '<table><tr><td>gamma</td><td>delta</td></tr></table>',
          ],
        ),
      );

      expect(
        (await engine.search(BookSearchRequest('alphabeta'))).matches,
        isEmpty,
      );
      expect(
        (await engine.search(BookSearchRequest('gammadelta'))).matches,
        isEmpty,
      );
      final paragraphs = await engine.search(BookSearchRequest('alpha beta'));
      expect(paragraphs.matches.single.excerpt.text, 'alpha beta');
      _expectRange(paragraphs.matches.single, 0, 'alphabeta'.length);
      final cells = await engine.search(BookSearchRequest('gamma delta'));
      _expectRange(
        cells.matches.single,
        'alphabeta'.length,
        'alphabetagammadelta'.length,
      );
    },
  );

  test(
    'emoji entities nested tables lists and image gaps retain UTF16 ranges',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);
      await engine.loadBook(
        _epub(
          chapters: [
            '<p>&#x1F600; &amp; Начало</p><hr/>'
                '<img src="../pixel.svg" alt="picture-only-alt"/>'
                '<table><tr><td>Ячейка &amp; A😀</td><td>'
                '<table><tr><td><b>ГЛУБ</b>ИНА</td></tr></table>'
                '</td></tr></table>'
                '<ul><li>LIST <i>tail</i></li></ul><p>Последний</p>',
          ],
        ),
      );

      final deepStart = '😀 & Начало'.length + 2 + 'Ячейка & A😀'.length;
      final deep = await engine.search(BookSearchRequest('глубина'));
      _expectRange(
        deep.matches.single,
        deepStart,
        deepStart + 'ГЛУБИНА'.length,
      );
      final emoji = await engine.search(BookSearchRequest('😀'));
      expect(emoji.matches, hasLength(2));
      _expectRange(emoji.matches[0], 0, 2);
      _expectRange(emoji.matches[1], deepStart - 2, deepStart);
      final entity = await engine.search(BookSearchRequest('&'));
      expect(entity.matches, hasLength(2));
      _expectRange(entity.matches[0], 3, 4);
      final tailStart = deepStart + 'ГЛУБИНА'.length + '• LIST '.length;
      final tail = await engine.search(BookSearchRequest('TAIL'));
      _expectRange(tail.matches.single, tailStart, tailStart + 'tail'.length);
      final lastStart = tailStart + 'tail'.length;
      final last = await engine.search(BookSearchRequest('последний'));
      _expectRange(
        last.matches.single,
        lastStart,
        lastStart + 'Последний'.length,
      );
      expect(
        (await engine.search(BookSearchRequest('picture-only-alt'))).matches,
        isEmpty,
      );
    },
  );

  test(
    'hidden content scripts styles attributes and markup are not searched',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);
      await engine.loadBook(
        _epub(
          stylesheet: '.external-hidden { display: none; }',
          chapters: [
            '<p title="attribute-only">Visible '
                '<span style="display:none">display-secret</span>'
                '<span style="visibility:hidden">visibility-secret</span>'
                '<span class="external-hidden">stylesheet-secret</span>'
                '<script>script-secret</script>'
                '<style>.style-secret { color: red; }</style>'
                'text</p>',
          ],
        ),
      );

      for (final query in [
        'display-secret',
        'visibility-secret',
        'stylesheet-secret',
        'script-secret',
        'style-secret',
        'attribute-only',
        '<span',
        'Chapter 0',
      ]) {
        expect(
          (await engine.search(BookSearchRequest(query))).matches,
          isEmpty,
          reason: query,
        );
      }
      final visible = await engine.search(BookSearchRequest('visible text'));
      expect(visible.hasText, isTrue);
      _expectRange(visible.matches.single, 0, 'Visible text'.length);
    },
  );

  test(
    'section titles follow the nearest TOC anchor in the same document',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);
      await engine.loadBook(
        _epub(
          chapters: [
            '<p>needle introduction</p><h2 id="second">Part two</h2>'
                '<p>needle conclusion</p>',
          ],
          navigation:
              '<li><a href="Text/chapter-0.xhtml">Whole chapter</a><ol>'
              '<li><a href="Text/chapter-0.xhtml#second">Second part</a></li>'
              '</ol></li>',
        ),
      );

      final result = await engine.search(BookSearchRequest('needle'));

      expect(result.matches.map((match) => match.sectionTitle), [
        'Whole chapter',
        'Second part',
      ]);
    },
  );

  test('image-only and hidden-only books report no searchable text', () async {
    final engine = EpubBookReaderEngine();
    addTearDown(engine.dispose);
    for (final body in [
      '<img src="../pixel.svg" alt="not visible"/>',
      '<p style="display:none">hidden</p><script>hidden</script>',
    ]) {
      await engine.loadBook(_epub(chapters: [body]));
      final result = await engine.search(BookSearchRequest('hidden'));
      expect(result.hasText, isFalse);
      expect(result.matches, isEmpty);
    }
  });

  test('cancellation interrupts a cached chapter with many matches', () async {
    final engine = EpubBookReaderEngine();
    addTearDown(engine.dispose);
    await engine.loadBook(_epub(chapters: ['<p>${'echo ' * 1024}last</p>']));
    await engine.search(BookSearchRequest('absent'));
    final stale = BookSearchRequest('echo');
    final pending = engine.search(stale);
    await Future<void>.delayed(Duration.zero);
    stale.cancel();

    expect((await pending).matches, isEmpty);
    final replacement = await engine.search(BookSearchRequest('last'));
    expect(replacement.matches, hasLength(1));
    final alreadyCancelled = BookSearchRequest('echo')..cancel();
    expect((await engine.search(alreadyCancelled)).matches, isEmpty);
  });

  test(
    'loading disposing and failed loading invalidate cached book text',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);
      await engine.loadBook(_epub(chapters: ['<p>old text</p>']));
      expect(
        (await engine.search(BookSearchRequest('old'))).matches,
        hasLength(1),
      );
      final pending = engine.search(BookSearchRequest('old'));
      await engine.loadBook(_epub(chapters: ['<p>replacement</p>']));
      expect((await pending).matches, isEmpty);
      expect((await engine.search(BookSearchRequest('old'))).matches, isEmpty);
      expect(
        (await engine.search(BookSearchRequest('replacement'))).matches,
        hasLength(1),
      );
      engine.dispose();
      await expectLater(
        engine.search(BookSearchRequest('replacement')),
        throwsStateError,
      );
      await engine.loadBook(_epub(chapters: ['<p>after dispose</p>']));
      expect(
        (await engine.search(BookSearchRequest('replacement'))).matches,
        isEmpty,
      );
      await expectLater(
        engine.loadBook(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isNotNull),
      );
      await expectLater(
        engine.search(BookSearchRequest('after')),
        throwsStateError,
      );
    },
  );

  for (final mode in ReadingMode.values) {
    testWidgets(
      'search is read-only and locates exact result in ${mode.name}',
      (tester) async {
        final engine = EpubBookReaderEngine();
        addTearDown(engine.dispose);
        final prefix = '<p>${'Before the destination. ' * 15}</p>' * 16;
        await tester.runAsync(
          () => engine.loadBook(
            _epub(
              chapters: [
                '$prefix<p>😀 prefix SearchAnchor42 after destination.</p>'
                    '${'<p>${'After the destination. ' * 15}</p>' * 16}',
              ],
            ),
          ),
        );
        final unmounted = await tester.runAsync(
          () => engine.search(BookSearchRequest('searchanchor42')),
        );
        final target = unmounted!.matches.single;
        final reports = <BookLocation>[];
        var selections = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 600,
                height: 400,
                child: Builder(
                  builder: (context) => engine.buildReaderWidget(
                    context: context,
                    initialLocation: const BookLocation(locator: ''),
                    settings: ReaderSettings(
                      readingMode: mode,
                      enableDualPageSpread: false,
                    ),
                    theme: ThemeData.light(),
                    onProgressChanged: (location, _) => reports.add(location),
                    onTextSelected: (_, _) => selections++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final reportCount = reports.length;
        final mounted = await tester.runAsync(
          () => engine.search(BookSearchRequest('searchanchor42')),
        );
        await tester.pumpAndSettle();
        expect(
          mounted!.matches.single.location.locator,
          target.location.locator,
        );
        expect(reports.length, reportCount);
        expect(selections, 0);
        expect(_fragmentIsVisible(tester, 'SearchAnchor42'), isFalse);

        await engine.goToLocation(target.location);
        await tester.pumpAndSettle();

        expect(_fragmentIsVisible(tester, 'SearchAnchor42'), isTrue);
        final shown = EpubLocation.fromJson(reports.last.locator)!;
        expect(shown.hasExactCharOffset, isTrue);
        expect(shown.chapterIndex, _location(target).chapterIndex);
        expect(shown.charOffset, _location(target).charOffset);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
