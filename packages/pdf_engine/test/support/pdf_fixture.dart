import 'dart:convert';
import 'dart:typed_data';

/// Three real, unencrypted PDF pages with selectable Helvetica text, a link
/// from page one to page three, and a "Last page" outline destination.
/// No plugins, assets, network access or document-generator package required.
Uint8List readerPdfFixtureBytes() {
  const streams = [
    'BT /F1 16 Tf 30 340 Td (Page one alpha bravo) Tj '
        '0 -30 Td (Jump to final page) Tj '
        '0 -110 Td (Highlight this sentence) Tj ET',
    'BT /F1 16 Tf 30 340 Td (Page two charlie delta) Tj '
        '0 -140 Td (Second page selection) Tj ET',
    'BT /F1 16 Tf 30 340 Td (Page three echo foxtrot) Tj '
        '0 -240 Td (Bottom target text) Tj ET',
  ];
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R /Outlines 10 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 5 0 R 7 0 R] /Count 3 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] '
        '/Resources << /Font << /F1 9 0 R >> >> '
        '/Contents 4 0 R /Annots [12 0 R] >>',
    '<< /Length ${streams[0].length} >>\nstream\n${streams[0]}\nendstream',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] '
        '/Resources << /Font << /F1 9 0 R >> >> /Contents 6 0 R >>',
    '<< /Length ${streams[1].length} >>\nstream\n${streams[1]}\nendstream',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] '
        '/Resources << /Font << /F1 9 0 R >> >> /Contents 8 0 R >>',
    '<< /Length ${streams[2].length} >>\nstream\n${streams[2]}\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Type /Outlines /First 11 0 R /Last 11 0 R /Count 1 >>',
    '<< /Title (Last page) /Parent 10 0 R /Dest [7 0 R /Fit] >>',
    '<< /Type /Annot /Subtype /Link /Rect [30 295 190 325] '
        '/Border [0 0 0] /Dest [7 0 R /Fit] >>',
  ];
  final bytes = BytesBuilder(copy: false);
  void append(String value) => bytes.add(ascii.encode(value));
  append('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(bytes.length);
    append('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
  }
  final xrefOffset = bytes.length;
  append('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    append('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  append(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xrefOffset\n%%EOF\n',
  );
  return bytes.takeBytes();
}
