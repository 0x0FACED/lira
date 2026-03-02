// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookDtoImpl _$$BookDtoImplFromJson(Map<String, dynamic> json) =>
    _$BookDtoImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String? ?? 'Unknown Author',
      format: json['format'] as String,
      coverUrl: json['coverUrl'] as String?,
      fileUrl: json['fileUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$BookDtoImplToJson(_$BookDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'author': instance.author,
      'format': instance.format,
      'coverUrl': instance.coverUrl,
      'fileUrl': instance.fileUrl,
      'createdAt': instance.createdAt.toIso8601String(),
    };
