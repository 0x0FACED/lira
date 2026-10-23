import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_engine/pdf_engine.dart';
import 'package:pdfrx/pdfrx.dart';

// A page-text value fixture: real pdfrx fragments/character geometry, without
// loading a native PDF library for the locator's pure coordinate contract.
class _PageText extends PdfPageText {
  _PageText(this.pageNumber);

  @override
  final int pageNumber;

  @override
  String get fullText => 'ABCDEFGH';

  @override
  List<PdfPageTextFragment> get fragments => [
    PdfPageTextFragment.fromParams(
      0,
      4,
      const PdfRect(10, 90, 50, 80),
      'ABCD',
      [
        for (var i = 0; i < 4; i++)
          PdfRect(10.0 + i * 10, 90, 20.0 + i * 10, 80),
      ],
    ),
    PdfPageTextFragment.fromParams(
      4,
      4,
      const PdfRect(10, 70, 50, 60),
      'EFGH',
      [
        for (var i = 0; i < 4; i++)
          PdfRect(10.0 + i * 10, 70, 20.0 + i * 10, 60),
      ],
    ),
  ];
}

void main() {
  test(
    'selection stores partial-line geometry and exact exclusive offsets',
    () {
      final selection = PdfReaderSelection.fromTextSelections([
        PdfTextRanges(
          pageText: _PageText(3),
          ranges: const [PdfTextRange(start: 1, end: 6)],
        ),
      ])!;
      expect(selection.text, 'BCDEF');
      final restored = PdfReaderLocation.tryParse(selection.location.encode())!;
      expect(restored.pageNumber, 3);
      expect(restored.selections.single.ranges, const [
        PdfTextRange(start: 1, end: 6),
      ]);
      expect(restored.rectsForPage(3), const [
        PdfRect(20, 90, 50, 80),
        PdfRect(10, 70, 30, 60),
      ]);
      expect(restored.rectsForPage(2), isEmpty);
      expect(restored.targetRect, const PdfRect(10, 90, 50, 60));
      expect(restored.encode(), selection.location.encode());
    },
  );

  test(
    'cross-page selection is ordered by page, not callback insertion order',
    () {
      final selection = PdfReaderSelection.fromTextSelections([
        PdfTextRanges(
          pageText: _PageText(5),
          ranges: const [PdfTextRange(start: 4, end: 8)],
        ),
        PdfTextRanges(
          pageText: _PageText(2),
          ranges: const [PdfTextRange(start: 0, end: 4)],
        ),
      ])!;
      expect(selection.text, 'ABCD\nEFGH');
      expect(selection.location.pageNumber, 2);
      final restored = PdfReaderLocation.tryParse(selection.location.encode())!;
      expect(restored.selections.map((page) => page.pageNumber), [2, 5]);
      expect(restored.rectsForPage(5), const [PdfRect(10, 70, 50, 60)]);
    },
  );

  test(
    'empty or out-of-text selection ranges cannot become saved highlights',
    () {
      expect(PdfReaderSelection.fromTextSelections([]), isNull);
      for (final range in const [
        PdfTextRange(start: -1, end: 2),
        PdfTextRange(start: 1, end: 9),
        PdfTextRange(start: 4, end: 4),
        PdfTextRange(start: 4, end: 2),
      ]) {
        expect(
          PdfReaderSelection.fromTextSelections([
            PdfTextRanges(pageText: _PageText(1), ranges: [range]),
          ]),
          isNull,
        );
      }
    },
  );

  test(
    'legacy pages stay numeric and navigation clamps to document bounds',
    () {
      expect(PdfReaderLocation.tryParse(' 2 ')!.encode(), '2');
      expect(PdfReaderLocation.tryParse('99')!.pageFor(3), 3);
      expect(PdfReaderLocation.page(1).pageFor(3), 1);
      expect(() => PdfReaderLocation.page(1).pageFor(0), throwsArgumentError);
      for (final value in ['', '0', '-1', '1.5', 'chapter', 'null', '[]']) {
        expect(PdfReaderLocation.tryParse(value), isNull, reason: value);
      }
    },
  );

  test(
    'malformed versions, geometry and inconsistent page ranges are rejected',
    () {
      Map<String, dynamic> location({
        Object? page = 1,
        Object? ranges,
        Object? rects,
      }) => {
        'pdf': 1,
        'p': 1,
        's': [
          {
            'p': page,
            'r':
                ranges ??
                [
                  [0, 3],
                ],
            'q':
                rects ??
                [
                  [10, 90, 40, 80],
                ],
          },
        ],
      };
      final invalid = [
        {...location(), 'pdf': 2},
        {...location(), 'p': 2},
        location(page: 0),
        location(page: 1.5),
        location(
          ranges: [
            [-1, 3],
          ],
        ),
        location(
          ranges: [
            [3, 3],
          ],
        ),
        location(
          ranges: [
            [0, 3],
            [2, 5],
          ],
        ),
        location(
          ranges: [
            [0.5, 3],
          ],
        ),
        location(rects: []),
        location(
          rects: [
            [10, 80, 40, 90],
          ],
        ),
        location(
          rects: [
            [10, 90, 10, 80],
          ],
        ),
        location(
          rects: [
            ['10', 90, 40, 80],
          ],
        ),
        location(
          rects: [
            [10, 90, 40],
          ],
        ),
      ];
      for (final value in invalid) {
        expect(
          PdfReaderLocation.tryParse(jsonEncode(value)),
          isNull,
          reason: '$value',
        );
      }
      expect(
        PdfReaderLocation.tryParse(
          '{"pdf":1,"p":1,"s":[{"p":1,"r":[[0,3]],"q":[[0,1e999,3,0]]}]}',
        ),
        isNull,
      );
    },
  );
}
