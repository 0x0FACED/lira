// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookmarkDto _$BookmarkDtoFromJson(Map<String, dynamic> json) => _BookmarkDto(
  id: json['id'] as String,
  bookId: json['bookId'] as String,
  location: json['location'] as String,
  percentage: (json['percentage'] as num).toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$BookmarkDtoToJson(_BookmarkDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bookId': instance.bookId,
      'location': instance.location,
      'percentage': instance.percentage,
      'createdAt': instance.createdAt.toIso8601String(),
    };
