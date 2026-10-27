import 'package:epub_engine/epub_engine.dart';
import 'package:pdf_engine/pdf_engine.dart';

import '../../../bookmarks/domain/models/bookmark_dto.dart';

/// Finds the saved target for the current reading region without changing it.
///
/// EPUB v2 positions share a region within 400 UTF-16 characters in the same
/// spine document. Legacy offsets have different coordinates, so only their
/// exact serialized locations match. PDF locations share a region on one page.
/// Exact locations win; otherwise the nearest offset wins, with ID as a stable
/// tie-breaker independent of repository ordering.
BookmarkDto? bookmarkNearLocation({
  required Iterable<BookmarkDto> bookmarks,
  required String format,
  required String locator,
}) {
  if (locator.isEmpty) return null;
  for (final bookmark in bookmarks) {
    if (bookmark.location == locator) return bookmark;
  }

  final epub = format == 'epub' ? EpubCfi.fromJson(locator) : null;
  final pdf = format == 'pdf' ? PdfReaderLocation.tryParse(locator) : null;
  if (pdf == null &&
      (epub == null || !epub.hasExactCharOffset || epub.hasRange)) {
    return null;
  }

  BookmarkDto? nearest;
  var nearestDistance = 401;
  for (final bookmark in bookmarks) {
    final int distance;
    if (pdf != null) {
      final candidate = PdfReaderLocation.tryParse(bookmark.location);
      if (candidate == null || candidate.pageNumber != pdf.pageNumber) continue;
      distance = 0;
    } else {
      final candidate = EpubCfi.fromJson(bookmark.location);
      if (candidate == null ||
          !candidate.hasExactCharOffset ||
          candidate.hasRange ||
          candidate.spineIndex != epub!.spineIndex) {
        continue;
      }
      distance = (candidate.charOffset - epub.charOffset).abs();
      if (distance > 400) continue;
    }
    if (distance < nearestDistance ||
        (distance == nearestDistance &&
            bookmark.id.compareTo(nearest!.id) < 0)) {
      nearest = bookmark;
      nearestDistance = distance;
    }
  }
  return nearest;
}
