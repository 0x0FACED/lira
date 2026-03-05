// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookDto {

 String get id; String get title; String get author; String get format;// epub, pdf
 String? get coverUrl; String? get fileUrl; DateTime get createdAt; int get pageCount; int get fileSizeBytes;
/// Create a copy of BookDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookDtoCopyWith<BookDto> get copyWith => _$BookDtoCopyWithImpl<BookDto>(this as BookDto, _$identity);

  /// Serializes this BookDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.format, format) || other.format == format)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,author,format,coverUrl,fileUrl,createdAt,pageCount,fileSizeBytes);

@override
String toString() {
  return 'BookDto(id: $id, title: $title, author: $author, format: $format, coverUrl: $coverUrl, fileUrl: $fileUrl, createdAt: $createdAt, pageCount: $pageCount, fileSizeBytes: $fileSizeBytes)';
}


}

/// @nodoc
abstract mixin class $BookDtoCopyWith<$Res>  {
  factory $BookDtoCopyWith(BookDto value, $Res Function(BookDto) _then) = _$BookDtoCopyWithImpl;
@useResult
$Res call({
 String id, String title, String author, String format, String? coverUrl, String? fileUrl, DateTime createdAt, int pageCount, int fileSizeBytes
});




}
/// @nodoc
class _$BookDtoCopyWithImpl<$Res>
    implements $BookDtoCopyWith<$Res> {
  _$BookDtoCopyWithImpl(this._self, this._then);

  final BookDto _self;
  final $Res Function(BookDto) _then;

/// Create a copy of BookDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? author = null,Object? format = null,Object? coverUrl = freezed,Object? fileUrl = freezed,Object? createdAt = null,Object? pageCount = null,Object? fileSizeBytes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,fileUrl: freezed == fileUrl ? _self.fileUrl : fileUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BookDto].
extension BookDtoPatterns on BookDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookDto value)  $default,){
final _that = this;
switch (_that) {
case _BookDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookDto value)?  $default,){
final _that = this;
switch (_that) {
case _BookDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String author,  String format,  String? coverUrl,  String? fileUrl,  DateTime createdAt,  int pageCount,  int fileSizeBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookDto() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.format,_that.coverUrl,_that.fileUrl,_that.createdAt,_that.pageCount,_that.fileSizeBytes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String author,  String format,  String? coverUrl,  String? fileUrl,  DateTime createdAt,  int pageCount,  int fileSizeBytes)  $default,) {final _that = this;
switch (_that) {
case _BookDto():
return $default(_that.id,_that.title,_that.author,_that.format,_that.coverUrl,_that.fileUrl,_that.createdAt,_that.pageCount,_that.fileSizeBytes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String author,  String format,  String? coverUrl,  String? fileUrl,  DateTime createdAt,  int pageCount,  int fileSizeBytes)?  $default,) {final _that = this;
switch (_that) {
case _BookDto() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.format,_that.coverUrl,_that.fileUrl,_that.createdAt,_that.pageCount,_that.fileSizeBytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookDto implements BookDto {
  const _BookDto({required this.id, required this.title, this.author = 'Unknown Author', required this.format, this.coverUrl, this.fileUrl, required this.createdAt, this.pageCount = 0, this.fileSizeBytes = 0});
  factory _BookDto.fromJson(Map<String, dynamic> json) => _$BookDtoFromJson(json);

@override final  String id;
@override final  String title;
@override@JsonKey() final  String author;
@override final  String format;
// epub, pdf
@override final  String? coverUrl;
@override final  String? fileUrl;
@override final  DateTime createdAt;
@override@JsonKey() final  int pageCount;
@override@JsonKey() final  int fileSizeBytes;

/// Create a copy of BookDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookDtoCopyWith<_BookDto> get copyWith => __$BookDtoCopyWithImpl<_BookDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.format, format) || other.format == format)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,author,format,coverUrl,fileUrl,createdAt,pageCount,fileSizeBytes);

@override
String toString() {
  return 'BookDto(id: $id, title: $title, author: $author, format: $format, coverUrl: $coverUrl, fileUrl: $fileUrl, createdAt: $createdAt, pageCount: $pageCount, fileSizeBytes: $fileSizeBytes)';
}


}

/// @nodoc
abstract mixin class _$BookDtoCopyWith<$Res> implements $BookDtoCopyWith<$Res> {
  factory _$BookDtoCopyWith(_BookDto value, $Res Function(_BookDto) _then) = __$BookDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String author, String format, String? coverUrl, String? fileUrl, DateTime createdAt, int pageCount, int fileSizeBytes
});




}
/// @nodoc
class __$BookDtoCopyWithImpl<$Res>
    implements _$BookDtoCopyWith<$Res> {
  __$BookDtoCopyWithImpl(this._self, this._then);

  final _BookDto _self;
  final $Res Function(_BookDto) _then;

/// Create a copy of BookDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? author = null,Object? format = null,Object? coverUrl = freezed,Object? fileUrl = freezed,Object? createdAt = null,Object? pageCount = null,Object? fileSizeBytes = null,}) {
  return _then(_BookDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,fileUrl: freezed == fileUrl ? _self.fileUrl : fileUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
