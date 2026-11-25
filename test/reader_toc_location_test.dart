import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/reader/domain/engine/epub_book_reader_engine.dart';
import 'package:lira/features/reader/domain/engine/pdf_book_reader_engine.dart';
import 'package:lira/features/reader/domain/models/book_location.dart';
import 'package:lira/features/reader/domain/models/book_search.dart';
import 'package:pdfrx/pdfrx.dart';

Uint8List _epub({bool fileOnly = false}) {
  final chapters = [
    '<p>Intro</p><h1 id="раздел">First</h1><p>middle</p>'
        '<h2 id="later">Later</h2>',
    '<p>Next chapter</p>',
    '<p>Front matter</p>',
    '<p>Untitled continuation</p>',
  ];
  final files = <String, String>{
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
    'OEBPS/content.opf':
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:title>TOC locations</dc:title></metadata><manifest>'
        '${List.generate(chapters.length, (i) => '<item id="c$i" href="Text/c$i.xhtml" media-type="application/xhtml+xml"/>').join()}'
        '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
        '</manifest><spine>'
        '${[2, 0, 3, 1].map((i) => '<itemref idref="c$i"/>').join()}'
        '</spine></package>',
    'OEBPS/nav.xhtml':
        '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">'
        '<body><nav epub:type="toc"><ol>'
        '<li><a href="Text/c1.xhtml">Next</a></li>'
        '<li><a href="Text/c0.xhtml${fileOnly ? '' : '#раздел'}">Parent</a>'
        '${fileOnly ? '' : '<ol><li><a href="Text/c0.xhtml#раздел">Child</a></li><li><a href="Text/c0.xhtml#later">Later</a></li><li><a href="Text/c0.xhtml#missing">Broken</a></li></ol>'}'
        '</li></ol></nav></body></html>',
    for (var i = 0; i < chapters.length; i++)
      'OEBPS/Text/c$i.xhtml':
          '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
          '${chapters[i]}</body></html>',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

BookLocation _position(int chapter, int offset) => BookLocation(
  locator: EpubLocation.fromPosition(
    chapterIndex: chapter,
    charOffset: offset,
    hasExactCharOffset: true,
  ).toJson(),
);

Uint8List _pdf() {
  const stream = 'BT /F1 16 Tf 30 340 Td (Chapter) Tj ET';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R /Outlines 10 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 5 0 R 7 0 R] /Count 3 >>',
    for (var page = 0; page < 3; page++) ...[
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] '
          '/Resources << /Font << /F1 9 0 R >> >> '
          '/Contents ${4 + page * 2} 0 R >>',
      '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
    ],
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Type /Outlines /First 11 0 R /Last 12 0 R /Count 4 >>',
    '<< /Title (Next) /Parent 10 0 R /Next 12 0 R /Dest [7 0 R /Fit] >>',
    '<< /Title (Group) /Parent 10 0 R /Prev 11 0 R '
        '/First 13 0 R /Last 13 0 R /Count 2 >>',
    '<< /Title (Parent) /Parent 12 0 R /Dest [5 0 R /Fit] '
        '/First 14 0 R /Last 14 0 R /Count 1 >>',
    '<< /Title (Child) /Parent 13 0 R /Dest [5 0 R /Fit] >>',
  ];
  final bytes = BytesBuilder(copy: false);
  void append(String value) => bytes.add(ascii.encode(value));
  append('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(bytes.length);
    append('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = bytes.length;
  append('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    append('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  append(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return bytes.takeBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'EPUB uses spine and exact anchor boundaries, retaining TOC identity',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);
      await engine.loadBook(_epub());
      final toc = engine.getToc();
      final child = toc[1].subItems[0];
      final later = toc[1].subItems[1];

      expect(engine.tocItemAt(_position(0, 100)), isNull);
      expect(engine.tocItemAt(_position(1, 4)), isNull);
      expect(engine.tocItemAt(_position(1, 5)), same(child));
      expect(engine.tocItemAt(_position(1, 15)), same(child));
      expect(engine.tocItemAt(_position(1, 16)), same(later));
      expect(engine.tocItemAt(_position(1, 100)), same(later));
      expect(engine.tocItemAt(_position(2, 0)), same(later));
      expect(engine.tocItemAt(_position(3, 0)), same(toc[0]));
      expect(
        engine.tocItemAt(BookLocation(locator: child.fileName)),
        same(child),
      );
      expect(
        engine.tocItemAt(
          BookLocation(
            locator: EpubLocation.fromPosition(
              chapterIndex: 1,
              anchor: 'раздел',
            ).toJson(),
          ),
        ),
        same(child),
      );
      expect(
        engine.tocItemAt(BookLocation(locator: toc[1].subItems[2].fileName)),
        isNull,
      );
    },
  );

  test('EPUB search and TOC use the same parsed-content offsets', () async {
    final engine = EpubBookReaderEngine();
    addTearDown(engine.dispose);
    await engine.loadBook(_epub());
    final results = await engine.search(BookSearchRequest('Later'));
    expect(results.matches, hasLength(1));
    expect(
      engine.tocItemAt(results.matches.single.location),
      same(engine.getToc()[1].subItems[1]),
    );
  });

  test(
    'EPUB file-only headings, unknown locations and reload boundaries',
    () async {
      final engine = EpubBookReaderEngine();
      addTearDown(engine.dispose);
      expect(engine.tocItemAt(_position(0, 0)), isNull);
      await engine.loadBook(_epub(fileOnly: true));
      expect(engine.tocItemAt(_position(1, 0)), same(engine.getToc()[1]));
      expect(engine.tocItemAt(_position(2, 0)), same(engine.getToc()[1]));
      for (final locator in [
        '{}',
        '{"v":3,"s":1}',
        'garbage',
        'missing.xhtml',
        _position(-1, 0).locator,
        _position(99, 0).locator,
        _position(1, -1).locator,
        EpubLocation.fromPosition(
          chapterIndex: 1,
          scrollFraction: 0.5,
        ).toJson(),
      ]) {
        expect(
          engine.tocItemAt(BookLocation(locator: locator)),
          isNull,
          reason: locator,
        );
      }
      final previous = engine.getToc()[1];
      await engine.loadBook(_epub(fileOnly: true));
      final current = engine.tocItemAt(_position(1, 0));
      expect(current, same(engine.getToc()[1]));
      expect(current, isNot(same(previous)));
      await expectLater(
        engine.loadBook(Uint8List.fromList([0, 1, 2])),
        throwsA(isNotNull),
      );
      expect(engine.tocItemAt(_position(1, 0)), isNull);
    },
  );

  test(
    'PDF uses destination pages, deeper ties and original outline items',
    () async {
      Pdfrx.pdfiumModulePath = Platform.environment['PDFIUM_PATH'];
      final engine = PdfBookReaderEngine();
      addTearDown(engine.dispose);
      expect(engine.tocItemAt(const BookLocation(locator: '2')), isNull);
      await engine.loadBook(_pdf());
      final toc = engine.getToc();
      expect(toc[1].fileName, isEmpty);
      expect(engine.tocItemAt(const BookLocation(locator: '1')), isNull);
      expect(
        engine.tocItemAt(const BookLocation(locator: '2')),
        same(toc[1].subItems[0].subItems[0]),
      );
      expect(engine.tocItemAt(const BookLocation(locator: '3')), same(toc[0]));
      expect(engine.tocItemAt(const BookLocation(locator: '4')), isNull);
      expect(engine.tocItemAt(const BookLocation(locator: 'unknown')), isNull);
      expect(
        engine.tocItemAt(const BookLocation(locator: '{"pdf":1,"p":2,"s":[]}')),
        same(toc[1].subItems[0].subItems[0]),
      );
    },
    skip: Platform.environment['PDFIUM_PATH'] == null,
  );
}
