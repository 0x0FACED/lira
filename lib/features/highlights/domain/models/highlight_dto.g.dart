// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'highlight_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HighlightDtoImpl _$$HighlightDtoImplFromJson(Map<String, dynamic> json) =>
    _$HighlightDtoImpl(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      text: json['text'] as String,
      color: json['color'] as String? ?? '#BB86FC',
      location: json['location'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$HighlightDtoImplToJson(_$HighlightDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bookId': instance.bookId,
      'text': instance.text,
      'color': instance.color,
      'location': instance.location,
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
    };
