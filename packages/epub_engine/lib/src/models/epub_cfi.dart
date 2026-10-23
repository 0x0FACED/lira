import 'dart:convert';

/// Persistent native EPUB location in Lira's JSON format.
///
/// The historical class name does not imply a standard EPUB CFI string.
/// Version 2 addresses parsed content; unversioned locations retain legacy
/// coordinate semantics.
///
/// - [spineIndex]: position in the EPUB spine (chapter order)
/// - [anchor]: HTML element id for sub-chapter navigation (from TOC `#fragment`)
/// - [charOffset]: parsed-content UTF-16 offset for v2; legacy HTML approximation otherwise
/// - [scrollFraction]: fraction of chapter scrolled (0.0 = top, 1.0 = bottom)
class EpubCfi {
  final int spineIndex;
  final String? anchor;
  final int charOffset;

  /// v2 offsets address parsed content. Unversioned saves used HTML-length
  /// approximations; selection ranges have always used their own text offsets.
  final bool hasExactCharOffset;
  final double scrollFraction;
  final double? bookScrollOffset;
  final double? bookScrollFraction;

  /// For highlights: character offsets of the selected text range within the chapter.
  final int? startOffset;
  final int? endOffset;

  const EpubCfi({
    required this.spineIndex,
    this.anchor,
    this.charOffset = 0,
    this.hasExactCharOffset = false,
    this.scrollFraction = 0.0,
    this.bookScrollOffset,
    this.bookScrollFraction,
    this.startOffset,
    this.endOffset,
  });

  /// Whether this CFI contains a text selection range (i.e. is a highlight location).
  bool get hasRange => startOffset != null && endOffset != null;

  String toJson() {
    return jsonEncode({
      if (hasExactCharOffset) 'v': 2,
      's': spineIndex,
      if (anchor != null) 'a': anchor,
      'c': charOffset,
      'f': scrollFraction,
      if (bookScrollOffset != null) 'bo': bookScrollOffset,
      if (bookScrollFraction != null) 'bf': bookScrollFraction,
      if (startOffset != null) 'so': startOffset,
      if (endOffset != null) 'eo': endOffset,
    });
  }

  static EpubCfi? fromJson(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return EpubCfi(
        spineIndex: map['s'] as int? ?? 0,
        anchor: map['a'] as String?,
        charOffset: map['c'] as int? ?? 0,
        hasExactCharOffset: map['v'] == 2,
        scrollFraction: (map['f'] as num?)?.toDouble() ?? 0.0,
        bookScrollOffset: (map['bo'] as num?)?.toDouble(),
        bookScrollFraction: (map['bf'] as num?)?.toDouble(),
        startOffset: map['so'] as int?,
        endOffset: map['eo'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'CFI(spine:$spineIndex, anchor:$anchor, char:$charOffset, '
      'frac:${scrollFraction.toStringAsFixed(3)})';
}
