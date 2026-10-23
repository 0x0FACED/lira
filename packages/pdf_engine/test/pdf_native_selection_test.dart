import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_engine/pdf_engine.dart';
import 'package:pdfrx/pdfrx.dart';

import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final modulePath = Platform.environment['PDFIUM_PATH'];
  final nativeRequirement = modulePath == null
      ? 'Set PDFIUM_PATH to the real platform PDFium module; no plugin mocks are used'
      : false;

  test(
    'native PDF text selection survives locator persistence with page geometry',
    () async {
      Pdfrx.pdfiumModulePath = modulePath;
      final document = await PdfDocument.openData(
        readerPdfFixtureBytes(),
        useProgressiveLoading: false,
      );
      addTearDown(document.dispose);
      expect(document.pages.length, 3);
      expect((await document.loadOutline()).single.dest!.pageNumber, 3);
      final text = await document.pages[2].loadText();
      final start = text.fullText.indexOf('Bottom target text');
      expect(start, greaterThanOrEqualTo(0));
      final selected = PdfReaderSelection.fromTextSelections([
        PdfTextRanges(
          pageText: text,
          ranges: [
            PdfTextRange(
              start: start,
              end: start + 'Bottom target text'.length,
            ),
          ],
        ),
      ])!;
      final restored = PdfReaderLocation.tryParse(selected.location.encode())!;
      expect(selected.text, 'Bottom target text');
      expect(restored.pageNumber, 3);
      final range = restored.selections.single.ranges.single;
      expect(
        text.fullText.substring(range.start, range.end),
        'Bottom target text',
      );
      final geometry = restored.targetRect!;
      expect(geometry.left, inInclusiveRange(29, 40));
      expect(geometry.right, inInclusiveRange(120, 200));
      expect(geometry.top, inInclusiveRange(100, 120));
      expect(geometry.bottom, inInclusiveRange(85, 105));
      expect(restored.rectsForPage(2), isEmpty);
    },
    skip: nativeRequirement,
  );
}
