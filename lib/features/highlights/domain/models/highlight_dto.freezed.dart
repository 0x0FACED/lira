// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'highlight_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HighlightDto {

 String get id; String get bookId; String get text; String get color; String get location; String? get note; DateTime get createdAt;
/// Create a copy of HighlightDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HighlightDtoCopyWith<HighlightDto> get copyWith => _$HighlightDtoCopyWithImpl<HighlightDto>(this as HighlightDto, _$identity);

  /// Serializes this HighlightDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HighlightDto&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.text, text) || other.text == text)&&(identical(other.color, color) || other.color == color)&&(identical(other.location, location) || other.location == location)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookId,text,color,location,note,createdAt);

@override
String toString() {
  return 'HighlightDto(id: $id, bookId: $bookId, text: $text, color: $color, location: $location, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $HighlightDtoCopyWith<$Res>  {
  factory $HighlightDtoCopyWith(HighlightDto value, $Res Function(HighlightDto) _then) = _$HighlightDtoCopyWithImpl;
@useResult
$Res call({
 String id, String bookId, String text, String color, String location, String? note, DateTime createdAt
});




}
/// @nodoc
class _$HighlightDtoCopyWithImpl<$Res>
    implements $HighlightDtoCopyWith<$Res> {
  _$HighlightDtoCopyWithImpl(this._self, this._then);

  final HighlightDto _self;
  final $Res Function(HighlightDto) _then;

/// Create a copy of HighlightDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? text = null,Object? color = null,Object? location = null,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [HighlightDto].
extension HighlightDtoPatterns on HighlightDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HighlightDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HighlightDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HighlightDto value)  $default,){
final _that = this;
switch (_that) {
case _HighlightDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HighlightDto value)?  $default,){
final _that = this;
switch (_that) {
case _HighlightDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String bookId,  String text,  String color,  String location,  String? note,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HighlightDto() when $default != null:
return $default(_that.id,_that.bookId,_that.text,_that.color,_that.location,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String bookId,  String text,  String color,  String location,  String? note,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _HighlightDto():
return $default(_that.id,_that.bookId,_that.text,_that.color,_that.location,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String bookId,  String text,  String color,  String location,  String? note,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _HighlightDto() when $default != null:
return $default(_that.id,_that.bookId,_that.text,_that.color,_that.location,_that.note,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HighlightDto implements HighlightDto {
  const _HighlightDto({required this.id, required this.bookId, required this.text, this.color = '#BB86FC', required this.location, this.note, required this.createdAt});
  factory _HighlightDto.fromJson(Map<String, dynamic> json) => _$HighlightDtoFromJson(json);

@override final  String id;
@override final  String bookId;
@override final  String text;
@override@JsonKey() final  String color;
@override final  String location;
@override final  String? note;
@override final  DateTime createdAt;

/// Create a copy of HighlightDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HighlightDtoCopyWith<_HighlightDto> get copyWith => __$HighlightDtoCopyWithImpl<_HighlightDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HighlightDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HighlightDto&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.text, text) || other.text == text)&&(identical(other.color, color) || other.color == color)&&(identical(other.location, location) || other.location == location)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookId,text,color,location,note,createdAt);

@override
String toString() {
  return 'HighlightDto(id: $id, bookId: $bookId, text: $text, color: $color, location: $location, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$HighlightDtoCopyWith<$Res> implements $HighlightDtoCopyWith<$Res> {
  factory _$HighlightDtoCopyWith(_HighlightDto value, $Res Function(_HighlightDto) _then) = __$HighlightDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String bookId, String text, String color, String location, String? note, DateTime createdAt
});




}
/// @nodoc
class __$HighlightDtoCopyWithImpl<$Res>
    implements _$HighlightDtoCopyWith<$Res> {
  __$HighlightDtoCopyWithImpl(this._self, this._then);

  final _HighlightDto _self;
  final $Res Function(_HighlightDto) _then;

/// Create a copy of HighlightDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? text = null,Object? color = null,Object? location = null,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_HighlightDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
