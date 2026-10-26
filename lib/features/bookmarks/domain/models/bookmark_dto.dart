import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark_dto.freezed.dart';
part 'bookmark_dto.g.dart';

@freezed
abstract class BookmarkDto with _$BookmarkDto {
  const factory BookmarkDto({
    required String id,
    required String bookId,
    required String location,
    required double percentage,
    required DateTime createdAt,
  }) = _BookmarkDto;

  factory BookmarkDto.fromJson(Map<String, dynamic> json) =>
      _$BookmarkDtoFromJson(json);
}
