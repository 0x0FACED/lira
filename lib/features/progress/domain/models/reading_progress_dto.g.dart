// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReadingProgressDto _$ReadingProgressDtoFromJson(Map<String, dynamic> json) =>
    _ReadingProgressDto(
      bookId: json['bookId'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      location: json['location'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ReadingProgressDtoToJson(_ReadingProgressDto instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'percentage': instance.percentage,
      'location': instance.location,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
