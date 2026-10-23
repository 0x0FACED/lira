# pdf_engine

Native `pdfrx` PDF viewer integration for Lira.

`PdfViewerWidget` owns a stable document reference and keeps its controller attached across progress, settings and highlight rebuilds. A new document/controller gets a new viewer identity.

## Selection and navigation

- Native text selection emits the selected text and an encoded `PdfReaderLocation`.
- Empty selection clears the application-owned action bar.
- Reader taps are observed without competing with native selection gestures; single taps wait for the double-click window.
- Internal PDF annotations navigate to destinations; external HTTP(S) links use `url_launcher`.
- Saved highlights are painted from native PDF fragment geometry, independent of zoom and viewport size.
- Navigation centers saved selections without zooming in; it only zooms out when needed to fit the complete selected area.
- After Copy/save, the application releases selection focus; Flutter clears the native selection.

pdfrx 1.3.5 rejects non-collapsed edge selections with zero rectangular width/height. A PDF-local `SelectionContainerDelegate` gives only those degenerate active edges a 0.001 logical-pixel thickness. Collapsed carets and persisted native fragment geometry are unchanged.

`pdfrx 1.3.5` does not implement paragraph selection on triple-click. Multi-click is not converted into a reader single tap.

## Stored locations

Progress remains a 1-based page-number string. Text selections use:

```json
{"pdf":1,"p":3,"s":[{"p":3,"r":[[10,25]],"q":[[30,110,150,90]]}]}
```

- `p`: 1-based page number;
- `r`: extracted-text ranges, zero-based and end-exclusive;
- `q`: fragment rectangles `[left, top, right, bottom]` in PDF coordinates, Y up.

`PdfReaderLocation.tryParse` rejects malformed/unknown location data. Navigation clamps valid numeric pages to actual document bounds. Highlights enter the widget as `{highlightId, location, color}` maps; the PDF package decodes their location strings.

## Verification

Run from the Lira repository root:

```bash
flutter test packages/pdf_engine/test
```

Tests exercising the real PDFium library require `PDFIUM_PATH`; without it they explicitly skip rather than mock the native document. See `READER.md` for the macOS framework command and end-to-end reader test suite.
