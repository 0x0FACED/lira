import 'package:freezed_annotation/freezed_annotation.dart';

part 'highlight_dto.freezed.dart';
part 'highlight_dto.g.dart';

@freezed
abstract class HighlightDto with _$HighlightDto {
  const factory HighlightDto({
    required String id,
    required String bookId,
    required String text,
    @Default('#BB86FC') String color,
    required String location,
    String? note,
    required DateTime createdAt,
  }) = _HighlightDto;

  factory HighlightDto.fromJson(Map<String, dynamic> json) =>
      _$HighlightDtoFromJson(json);
}
