import 'epub_cfi.dart';

/// Represents a reading location in an EPUB book.
///
/// Uses [EpubCfi] internally for standards-based positioning.
class EpubLocation {
  final EpubCfi cfi;

  const EpubLocation({required this.cfi});

  /// Create a location from individual parameters
  factory EpubLocation.fromPosition({
    required int chapterIndex,
    String? anchor,
    int charOffset = 0,
    double scrollFraction = 0.0,
    double? bookScrollOffset,
    double? bookScrollFraction,
    int? startOffset,
    int? endOffset,
  }) {
    return EpubLocation(
      cfi: EpubCfi(
        spineIndex: chapterIndex,
        anchor: anchor,
        charOffset: charOffset,
        scrollFraction: scrollFraction,
        bookScrollOffset: bookScrollOffset,
        bookScrollFraction: bookScrollFraction,
        startOffset: startOffset,
        endOffset: endOffset,
      ),
    );
  }

  int get chapterIndex => cfi.spineIndex;
  String? get anchor => cfi.anchor;
  int get charOffset => cfi.charOffset;
  double get scrollFraction => cfi.scrollFraction;
  double? get bookScrollOffset => cfi.bookScrollOffset;
  double? get bookScrollFraction => cfi.bookScrollFraction;
  int? get startOffset => cfi.startOffset;
  int? get endOffset => cfi.endOffset;

  /// Serialize for storage
  String toJson() => cfi.toJson();

  /// Deserialize from stored string
  static EpubLocation? fromJson(String? data) {
    final cfi = EpubCfi.fromJson(data);
    if (cfi == null) return null;
    return EpubLocation(cfi: cfi);
  }

  EpubLocation copyWith({
    int? chapterIndex,
    String? anchor,
    int? charOffset,
    double? scrollFraction,
    double? bookScrollOffset,
    double? bookScrollFraction,
    int? startOffset,
    int? endOffset,
  }) {
    return EpubLocation.fromPosition(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      anchor: anchor ?? this.anchor,
      charOffset: charOffset ?? this.charOffset,
      scrollFraction: scrollFraction ?? this.scrollFraction,
      bookScrollOffset: bookScrollOffset ?? this.bookScrollOffset,
      bookScrollFraction: bookScrollFraction ?? this.bookScrollFraction,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
    );
  }

  @override
  String toString() => 'EpubLocation(${cfi.toString()})';
}
