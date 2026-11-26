import 'package:intl/intl.dart' show NumberFormat;
import 'package:pdf_engine/pdf_engine.dart';

import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/book_dto.dart';

/// Library page coordinates, not the reader's viewport-dependent pagination.
typedef BookPageProgress = ({int? current, int total, bool approximate});
typedef BookProgressLabels = ({String full, String compact});

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

String _joinBookProgressLabel(String? pages, String? percentage) {
  if (pages == null) return percentage ?? '';
  return percentage == null ? pages : '$pages · $percentage';
}

BookProgressLabels bookProgressLabels({
  required AppLocalizations l10n,
  required BookDto book,
  double? readingPercentage,
  String? readingLocation,
  NumberFormat? countFormat,
  NumberFormat? percentageFormat,
}) {
  final counts = countFormat ?? NumberFormat.decimalPattern(l10n.localeName);
  final percents = percentageFormat ?? NumberFormat('0.0', l10n.localeName);
  final percentage = readingPercentage?.isFinite == true
      ? readingPercentage!.clamp(0.0, 100.0).toDouble()
      : null;
  final displayed = percentage == null
      ? null
      : formatReadingPercentage(
          percentage,
          l10n.localeName,
          floor: true,
          numberFormat: percents,
        );
  final pages = bookPageProgress(
    book: book,
    percentage: percentage,
    location: readingLocation,
  );
  final coordinates = pages == null
      ? null
      : '${pages.approximate ? '≈' : ''}'
            '${pages.current == null ? '' : '${counts.format(pages.current)}/'}'
            '${counts.format(pages.total)}';
  return (
    full: _joinBookProgressLabel(
      coordinates == null ? null : l10n.bookPageCountCompact(coordinates),
      displayed,
    ),
    compact: _joinBookProgressLabel(coordinates, displayed),
  );
}
