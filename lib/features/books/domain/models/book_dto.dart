import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_dto.freezed.dart';
part 'book_dto.g.dart';

@freezed
abstract class BookDto with _$BookDto {
  const factory BookDto({
    required String id,
    required String title,
    @Default('Unknown Author') String author,
    required String format, // epub, pdf
    String? coverUrl,
    String? fileUrl,
    required DateTime createdAt,
    @Default(0) int pageCount,
    @Default(0) int fileSizeBytes,
  }) = _BookDto;

  factory BookDto.fromJson(Map<String, dynamic> json) =>
      _$BookDtoFromJson(json);
}
