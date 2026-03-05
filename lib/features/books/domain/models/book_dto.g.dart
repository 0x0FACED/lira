// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookDto _$BookDtoFromJson(Map<String, dynamic> json) => _BookDto(
  id: json['id'] as String,
  title: json['title'] as String,
  author: json['author'] as String? ?? 'Unknown Author',
  format: json['format'] as String,
  coverUrl: json['coverUrl'] as String?,
  fileUrl: json['fileUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
  fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$BookDtoToJson(_BookDto instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'author': instance.author,
  'format': instance.format,
  'coverUrl': instance.coverUrl,
  'fileUrl': instance.fileUrl,
  'createdAt': instance.createdAt.toIso8601String(),
  'pageCount': instance.pageCount,
  'fileSizeBytes': instance.fileSizeBytes,
};
