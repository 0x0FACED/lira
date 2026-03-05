import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_progress_dto.freezed.dart';
part 'reading_progress_dto.g.dart';

@freezed
abstract class ReadingProgressDto with _$ReadingProgressDto {
  const factory ReadingProgressDto({
    required String bookId,
    required double percentage,
    required String location,
    required DateTime updatedAt,
  }) = _ReadingProgressDto;

  factory ReadingProgressDto.fromJson(Map<String, dynamic> json) =>
      _$ReadingProgressDtoFromJson(json);
}
