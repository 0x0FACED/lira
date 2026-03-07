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
  }) {
    return EpubLocation(
      cfi: EpubCfi(
        spineIndex: chapterIndex,
        anchor: anchor,
        charOffset: charOffset,
        scrollFraction: scrollFraction,
      ),
    );
  }

  int get chapterIndex => cfi.spineIndex;
  String? get anchor => cfi.anchor;
  int get charOffset => cfi.charOffset;
  double get scrollFraction => cfi.scrollFraction;

  /// Serialize for storage
  String toJson() => cfi.toJson();

  /// Deserialize from stored string
  static EpubLocation? fromJson(String? data) {
    final cfi = EpubCfi.fromJson(data);
    if (cfi == null) return null;
    return EpubLocation(cfi: cfi);
  }

  @override
  String toString() => 'EpubLocation(${cfi.toString()})';
}
