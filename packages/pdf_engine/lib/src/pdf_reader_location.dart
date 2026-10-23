import 'dart:convert';

import 'package:pdfrx/pdfrx.dart';

/// A persistent PDF location. Page numbers and text offsets are 1-based and
/// 0-based respectively; text range ends are exclusive.
///
/// Plain page numbers remain the wire format for reading progress. Selections
/// use {"pdf":1,"p":page,"s":[{"p":page,"r":[[start,end]],
/// "q":[[left,top,right,bottom]]}]}. Rectangles use PDF coordinates (Y up),
/// independent of viewport size, zoom and device pixels.
class PdfReaderLocation {
  PdfReaderLocation.page(this.pageNumber) : selections = const [] {
    if (pageNumber < 1) throw ArgumentError.value(pageNumber, 'pageNumber');
  }

  PdfReaderLocation._(this.pageNumber, this.selections);

  final int pageNumber;
  final List<PdfPageSelection> selections;

  bool get isSelection => selections.isNotEmpty;

  /// Rejects malformed, unknown-version and internally inconsistent locations.
  /// Actual document bounds are applied by [pageFor] at navigation time.
  static PdfReaderLocation? tryParse(String value) {
    final number = int.tryParse(value.trim());
    if (number != null) {
      return number > 0 ? PdfReaderLocation.page(number) : null;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> || decoded['pdf'] != 1) return null;
      final page = decoded['p'];
      final rawSelections = decoded['s'];
      if (page is! int || page < 1 || rawSelections is! List) return null;
      if (rawSelections.isEmpty) return PdfReaderLocation.page(page);
      final selections = <PdfPageSelection>[];
      for (final raw in rawSelections) {
        if (raw is! Map<String, dynamic>) return null;
        final selectionPage = raw['p'];
        final rawRanges = raw['r'];
        final rawRects = raw['q'];
        if (selectionPage is! int || rawRanges is! List || rawRects is! List) {
          return null;
        }
        final ranges = <PdfTextRange>[];
        for (final range in rawRanges) {
          if (range is! List ||
              range.length != 2 ||
              range[0] is! int ||
              range[1] is! int) {
            return null;
          }
          ranges.add(PdfTextRange(start: range[0], end: range[1]));
        }
        final rects = <PdfRect>[];
        for (final rect in rawRects) {
          if (rect is! List ||
              rect.length != 4 ||
              !rect.every((coordinate) => coordinate is num)) {
            return null;
          }
          rects.add(
            PdfRect(
              (rect[0] as num).toDouble(),
              (rect[1] as num).toDouble(),
              (rect[2] as num).toDouble(),
              (rect[3] as num).toDouble(),
            ),
          );
        }
        selections.add(
          PdfPageSelection(
            pageNumber: selectionPage,
            ranges: ranges,
            rects: rects,
          ),
        );
      }
      for (var i = 1; i < selections.length; i++) {
        if (selections[i - 1].pageNumber >= selections[i].pageNumber) {
          return null;
        }
      }
      if (page != selections.first.pageNumber) return null;
      return PdfReaderLocation._(page, List.unmodifiable(selections));
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  int pageFor(int pageCount) {
    if (pageCount < 1) throw ArgumentError.value(pageCount, 'pageCount');
    return pageNumber.clamp(1, pageCount).toInt();
  }

  PdfRect? get targetRect => isSelection ? selections.first.bounds : null;

  Iterable<PdfRect> rectsForPage(int page) sync* {
    for (final selection in selections) {
      if (selection.pageNumber == page) yield* selection.rects;
    }
  }

  String encode() {
    if (!isSelection) return pageNumber.toString();
    return jsonEncode({
      'pdf': 1,
      'p': pageNumber,
      's': [for (final selection in selections) selection._toJson()],
    });
  }
}

/// Geometry and extracted-text ranges belonging to one selected PDF page.
class PdfPageSelection {
  PdfPageSelection({
    required this.pageNumber,
    required Iterable<PdfTextRange> ranges,
    required Iterable<PdfRect> rects,
  }) : ranges = List.unmodifiable(ranges),
       rects = List.unmodifiable(rects) {
    if (pageNumber < 1 || this.ranges.isEmpty || this.rects.isEmpty) {
      throw ArgumentError('A PDF selection needs a page, ranges and geometry');
    }
    var previousEnd = -1;
    for (final range in this.ranges) {
      if (range.start < 0 ||
          range.end <= range.start ||
          range.start < previousEnd) {
        throw ArgumentError('Invalid or overlapping PDF text ranges');
      }
      previousEnd = range.end;
    }
    for (final rect in this.rects) {
      if (rect.isEmpty ||
          !rect.left.isFinite ||
          !rect.top.isFinite ||
          !rect.right.isFinite ||
          !rect.bottom.isFinite) {
        throw ArgumentError('Invalid PDF selection geometry');
      }
    }
  }

  final int pageNumber;
  final List<PdfTextRange> ranges;
  final List<PdfRect> rects;

  PdfRect get bounds => rects.reduce((a, b) => a.merge(b));

  Map<String, dynamic> _toJson() => {
    'p': pageNumber,
    'r': [
      for (final range in ranges) [range.start, range.end],
    ],
    'q': [
      for (final rect in rects) [rect.left, rect.top, rect.right, rect.bottom],
    ],
  };
}

/// Converts pdfrx's real selection into text and durable page geometry.
class PdfReaderSelection {
  PdfReaderSelection._(this.text, this.location);

  final String text;
  final PdfReaderLocation location;

  static PdfReaderSelection? fromTextSelections(
    List<PdfTextRanges> selections,
  ) {
    final ordered =
        selections.where((selection) => selection.isNotEmpty).toList()
          ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    final pages = <PdfPageSelection>[];
    final texts = <String>[];
    for (final selection in ordered) {
      if (selection.pageNumber < 1 ||
          (pages.isNotEmpty && pages.last.pageNumber == selection.pageNumber)) {
        return null;
      }
      final ranges = [...selection.ranges]
        ..sort((a, b) => a.start.compareTo(b.start));
      final rects = <PdfRect>[];
      final text = StringBuffer();
      var previousEnd = -1;
      for (final range in ranges) {
        if (range.start < 0 ||
            range.end > selection.pageText.fullText.length ||
            range.end <= range.start ||
            range.start < previousEnd) {
          return null;
        }
        previousEnd = range.end;
        final fragments = range.toTextRangeWithFragments(selection.pageText);
        if (fragments == null) return null;
        rects.addAll(
          fragments.enumerateRectsForRange().where((rect) => rect.isNotEmpty),
        );
        text.write(
          selection.pageText.fullText.substring(range.start, range.end),
        );
      }
      if (rects.isEmpty) continue;
      pages.add(
        PdfPageSelection(
          pageNumber: selection.pageNumber,
          ranges: ranges,
          rects: rects,
        ),
      );
      texts.add(text.toString());
    }
    final selectedText = texts.join('\n');
    if (pages.isEmpty || selectedText.trim().isEmpty) return null;
    return PdfReaderSelection._(
      selectedText,
      PdfReaderLocation._(pages.first.pageNumber, List.unmodifiable(pages)),
    );
  }
}
