import 'dart:convert';

/// EPUB Canonical Fragment Identifier (simplified for Flutter)
///
/// Based on the EPUB CFI specification (https://www.w3.org/TR/epub-33/#sec-epubcfi).
/// Adapted for Flutter scroll-based rendering.
///
/// - [spineIndex]: position in the EPUB spine (chapter order)
/// - [anchor]: HTML element id for sub-chapter navigation (from TOC `#fragment`)
/// - [charOffset]: approximate character offset within the chapter text
/// - [scrollFraction]: fraction of chapter scrolled (0.0 = top, 1.0 = bottom)
class EpubCfi {
  final int spineIndex;
  final String? anchor;
  final int charOffset;
  final double scrollFraction;

  /// For highlights: character offsets of the selected text range within the chapter.
  final int? startOffset;
  final int? endOffset;

  const EpubCfi({
    required this.spineIndex,
    this.anchor,
    this.charOffset = 0,
    this.scrollFraction = 0.0,
    this.startOffset,
    this.endOffset,
  });

  /// Whether this CFI contains a text selection range (i.e. is a highlight location).
  bool get hasRange => startOffset != null && endOffset != null;

  String toJson() {
    return jsonEncode({
      's': spineIndex,
      if (anchor != null) 'a': anchor,
      'c': charOffset,
      'f': scrollFraction,
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
        scrollFraction: (map['f'] as num?)?.toDouble() ?? 0.0,
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
