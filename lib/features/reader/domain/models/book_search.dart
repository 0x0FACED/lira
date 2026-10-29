import 'book_location.dart';

/// A search is literal, case-insensitive, and treats runs of whitespace alike.
/// Offsets always refer to the original UTF-16 text, not a normalized copy.
class BookSearchRequest {
  BookSearchRequest(String query)
    : query = query.trim(),
      _pattern = query.trim().isEmpty
          ? null
          : RegExp(
              query
                  .trim()
                  .split(RegExp(r'\s+'))
                  .map(RegExp.escape)
                  .join(r'\s+'),
              caseSensitive: false,
              unicode: true,
            );

  final String query;
  final RegExp? _pattern;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;

  Iterable<BookTextMatch> matches(String text) sync* {
    final pattern = _pattern;
    if (pattern == null || isCancelled) return;
    for (final match in pattern.allMatches(text)) {
      if (isCancelled) return;
      yield BookTextMatch(text, match.start, match.end);
    }
  }
}

/// A short excerpt for display, with source offsets kept separate from it.
class BookTextMatch {
  BookTextMatch(String source, this.start, this.end)
    : before = _excerpt(
        source,
        _safeStart(source, start - 64),
        start,
        leading: start > 64,
      ),
      text = source.substring(start, end).replaceAll(_whitespace, ' '),
      after = _excerpt(
        source,
        end,
        _safeEnd(source, end + 96),
        trailing: end + 96 < source.length,
      );

  final int start;
  final int end;
  final String before;
  final String text;
  final String after;

  static final _whitespace = RegExp(r'\s+');

  static int _safeStart(String text, int offset) {
    var result = offset.clamp(0, text.length);
    if (result > 0 &&
        result < text.length &&
        text.codeUnitAt(result) >= 0xDC00 &&
        text.codeUnitAt(result) <= 0xDFFF) {
      result--;
    }
    return result;
  }

  static int _safeEnd(String text, int offset) {
    var result = offset.clamp(0, text.length);
    if (result > 0 &&
        result < text.length &&
        text.codeUnitAt(result) >= 0xDC00 &&
        text.codeUnitAt(result) <= 0xDFFF) {
      result++;
    }
    return result;
  }

  static String _excerpt(
    String source,
    int start,
    int end, {
    bool leading = false,
    bool trailing = false,
  }) {
    final value = source.substring(start, end).replaceAll(_whitespace, ' ');
    return '${leading ? '…' : ''}$value${trailing ? '…' : ''}';
  }
}

class BookSearchMatch {
  const BookSearchMatch({
    required this.location,
    required this.excerpt,
    required this.sectionIndex,
    this.sectionTitle,
    this.pageNumber,
  });

  final BookLocation location;
  final BookTextMatch excerpt;
  final int sectionIndex;
  final String? sectionTitle;
  final int? pageNumber;
}

class BookSearchResults {
  const BookSearchResults({required this.matches, required this.hasText});

  final List<BookSearchMatch> matches;
  final bool hasText;
}
