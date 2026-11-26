import 'package:pdf_engine/pdf_engine.dart';

import '../domain/models/book_dto.dart';

/// Library page coordinates, not the reader's viewport-dependent pagination.
typedef BookPageProgress = ({int? current, int total, bool approximate});

BookPageProgress? bookPageProgress({
  required BookDto book,
  double? percentage,
  String? location,
}) {
  final total = book.pageCount;
  if (total <= 0) return null;
  final format = book.format.toLowerCase();
  if (format == 'pdf') {
    final page = location == null
        ? null
        : PdfReaderLocation.tryParse(location)?.pageNumber;
    return (
      current: page != null && page <= total ? page : null,
      total: total,
      approximate: false,
    );
  }
  // EPUB's imported page count is itself an estimate. Its locator stores content
  // offsets, not stable page numbers; only actual reading progress may estimate
  // the corresponding page. A manual completion marker never enters this API.
  final current = format == 'epub' && percentage?.isFinite == true
      ? (percentage!.clamp(0.0, 100.0) * total / 100).ceil().clamp(1, total)
      : null;
  return (current: current, total: total, approximate: format == 'epub');
}
