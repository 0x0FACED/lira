import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_location.freezed.dart';
part 'book_location.g.dart';

@freezed
class BookLocation with _$BookLocation {
  const factory BookLocation({
    /// An opaque string location identifier (e.g. CFI for EPUB, page number for PDF)
    required String locator,
  }) = _BookLocation;

  factory BookLocation.fromJson(Map<String, dynamic> json) =>
      _$BookLocationFromJson(json);
}
