// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReadingProgressDtoImpl _$$ReadingProgressDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ReadingProgressDtoImpl(
  bookId: json['bookId'] as String,
  percentage: (json['percentage'] as num).toDouble(),
  location: json['location'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$ReadingProgressDtoImplToJson(
  _$ReadingProgressDtoImpl instance,
) => <String, dynamic>{
  'bookId': instance.bookId,
  'percentage': instance.percentage,
  'location': instance.location,
  'updatedAt': instance.updatedAt.toIso8601String(),
};
