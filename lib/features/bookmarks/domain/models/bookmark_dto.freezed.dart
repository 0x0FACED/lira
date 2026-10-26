// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookmark_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookmarkDto {

 String get id; String get bookId; String get location; double get percentage; DateTime get createdAt;
/// Create a copy of BookmarkDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookmarkDtoCopyWith<BookmarkDto> get copyWith => _$BookmarkDtoCopyWithImpl<BookmarkDto>(this as BookmarkDto, _$identity);

  /// Serializes this BookmarkDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookmarkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.location, location) || other.location == location)&&(identical(other.percentage, percentage) || other.percentage == percentage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookId,location,percentage,createdAt);

@override
String toString() {
  return 'BookmarkDto(id: $id, bookId: $bookId, location: $location, percentage: $percentage, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $BookmarkDtoCopyWith<$Res>  {
  factory $BookmarkDtoCopyWith(BookmarkDto value, $Res Function(BookmarkDto) _then) = _$BookmarkDtoCopyWithImpl;
@useResult
$Res call({
 String id, String bookId, String location, double percentage, DateTime createdAt
});




}
/// @nodoc
class _$BookmarkDtoCopyWithImpl<$Res>
    implements $BookmarkDtoCopyWith<$Res> {
  _$BookmarkDtoCopyWithImpl(this._self, this._then);

  final BookmarkDto _self;
  final $Res Function(BookmarkDto) _then;

/// Create a copy of BookmarkDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? location = null,Object? percentage = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [BookmarkDto].
extension BookmarkDtoPatterns on BookmarkDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookmarkDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookmarkDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookmarkDto value)  $default,){
final _that = this;
switch (_that) {
case _BookmarkDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookmarkDto value)?  $default,){
final _that = this;
switch (_that) {
case _BookmarkDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String bookId,  String location,  double percentage,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookmarkDto() when $default != null:
return $default(_that.id,_that.bookId,_that.location,_that.percentage,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String bookId,  String location,  double percentage,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _BookmarkDto():
return $default(_that.id,_that.bookId,_that.location,_that.percentage,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String bookId,  String location,  double percentage,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _BookmarkDto() when $default != null:
return $default(_that.id,_that.bookId,_that.location,_that.percentage,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookmarkDto implements BookmarkDto {
  const _BookmarkDto({required this.id, required this.bookId, required this.location, required this.percentage, required this.createdAt});
  factory _BookmarkDto.fromJson(Map<String, dynamic> json) => _$BookmarkDtoFromJson(json);

@override final  String id;
@override final  String bookId;
@override final  String location;
@override final  double percentage;
@override final  DateTime createdAt;

/// Create a copy of BookmarkDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookmarkDtoCopyWith<_BookmarkDto> get copyWith => __$BookmarkDtoCopyWithImpl<_BookmarkDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookmarkDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookmarkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.location, location) || other.location == location)&&(identical(other.percentage, percentage) || other.percentage == percentage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookId,location,percentage,createdAt);

@override
String toString() {
  return 'BookmarkDto(id: $id, bookId: $bookId, location: $location, percentage: $percentage, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$BookmarkDtoCopyWith<$Res> implements $BookmarkDtoCopyWith<$Res> {
  factory _$BookmarkDtoCopyWith(_BookmarkDto value, $Res Function(_BookmarkDto) _then) = __$BookmarkDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String bookId, String location, double percentage, DateTime createdAt
});




}
/// @nodoc
class __$BookmarkDtoCopyWithImpl<$Res>
    implements _$BookmarkDtoCopyWith<$Res> {
  __$BookmarkDtoCopyWithImpl(this._self, this._then);

  final _BookmarkDto _self;
  final $Res Function(_BookmarkDto) _then;

/// Create a copy of BookmarkDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? location = null,Object? percentage = null,Object? createdAt = null,}) {
  return _then(_BookmarkDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
