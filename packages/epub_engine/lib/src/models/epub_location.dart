import 'dart:convert';

/// Represents a precise reading location in an EPUB
/// 
/// Position is stored as:
/// - chapterIndex: which chapter we're in
/// - pixelOffset: absolute pixel offset from top of document (most accurate)
/// - offsetInChapter: relative position within chapter (0.0 to 1.0)
/// - textAnchor: first ~100 chars of visible text (for fuzzy matching)
class EpubLocation {
  final int chapterIndex;
  final double offsetInChapter; // 0.0 to 1.0 within the chapter
  final double? pixelOffset; // Absolute pixel offset from document start
  final String? textAnchor; // Optional text anchor for fuzzy matching
  final String? anchorId; // Optional anchor ID within chapter

  const EpubLocation({
    required this.chapterIndex,
    this.offsetInChapter = 0.0,
    this.pixelOffset,
    this.textAnchor,
    this.anchorId,
  });

  /// Serialize to string for storage
  String toJson() {
    return jsonEncode({
      'chapter': chapterIndex,
      'offset': offsetInChapter,
      'pixel': pixelOffset,
      'anchor': textAnchor,
      'anchorId': anchorId,
    });
  }

  /// Deserialize from string
  static EpubLocation? fromJson(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return EpubLocation(
        chapterIndex: map['chapter'] as int? ?? 0,
        offsetInChapter: (map['offset'] as num?)?.toDouble() ?? 0.0,
        pixelOffset: (map['pixel'] as num?)?.toDouble(),
        textAnchor: map['anchor'] as String?,
        anchorId: map['anchorId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => toJson();
}
