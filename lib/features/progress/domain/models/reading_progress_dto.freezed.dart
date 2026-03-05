// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_progress_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReadingProgressDto {

 String get bookId; double get percentage; String get location; DateTime get updatedAt;
/// Create a copy of ReadingProgressDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingProgressDtoCopyWith<ReadingProgressDto> get copyWith => _$ReadingProgressDtoCopyWithImpl<ReadingProgressDto>(this as ReadingProgressDto, _$identity);

  /// Serializes this ReadingProgressDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingProgressDto&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.percentage, percentage) || other.percentage == percentage)&&(identical(other.location, location) || other.location == location)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bookId,percentage,location,updatedAt);

@override
String toString() {
  return 'ReadingProgressDto(bookId: $bookId, percentage: $percentage, location: $location, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ReadingProgressDtoCopyWith<$Res>  {
  factory $ReadingProgressDtoCopyWith(ReadingProgressDto value, $Res Function(ReadingProgressDto) _then) = _$ReadingProgressDtoCopyWithImpl;
@useResult
$Res call({
 String bookId, double percentage, String location, DateTime updatedAt
});




}
/// @nodoc
class _$ReadingProgressDtoCopyWithImpl<$Res>
    implements $ReadingProgressDtoCopyWith<$Res> {
  _$ReadingProgressDtoCopyWithImpl(this._self, this._then);

  final ReadingProgressDto _self;
  final $Res Function(ReadingProgressDto) _then;

/// Create a copy of ReadingProgressDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookId = null,Object? percentage = null,Object? location = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingProgressDto].
extension ReadingProgressDtoPatterns on ReadingProgressDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingProgressDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingProgressDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingProgressDto value)  $default,){
final _that = this;
switch (_that) {
case _ReadingProgressDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingProgressDto value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingProgressDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bookId,  double percentage,  String location,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingProgressDto() when $default != null:
return $default(_that.bookId,_that.percentage,_that.location,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bookId,  double percentage,  String location,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ReadingProgressDto():
return $default(_that.bookId,_that.percentage,_that.location,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bookId,  double percentage,  String location,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ReadingProgressDto() when $default != null:
return $default(_that.bookId,_that.percentage,_that.location,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReadingProgressDto implements ReadingProgressDto {
  const _ReadingProgressDto({required this.bookId, required this.percentage, required this.location, required this.updatedAt});
  factory _ReadingProgressDto.fromJson(Map<String, dynamic> json) => _$ReadingProgressDtoFromJson(json);

@override final  String bookId;
@override final  double percentage;
@override final  String location;
@override final  DateTime updatedAt;

/// Create a copy of ReadingProgressDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingProgressDtoCopyWith<_ReadingProgressDto> get copyWith => __$ReadingProgressDtoCopyWithImpl<_ReadingProgressDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadingProgressDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingProgressDto&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.percentage, percentage) || other.percentage == percentage)&&(identical(other.location, location) || other.location == location)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bookId,percentage,location,updatedAt);

@override
String toString() {
  return 'ReadingProgressDto(bookId: $bookId, percentage: $percentage, location: $location, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ReadingProgressDtoCopyWith<$Res> implements $ReadingProgressDtoCopyWith<$Res> {
  factory _$ReadingProgressDtoCopyWith(_ReadingProgressDto value, $Res Function(_ReadingProgressDto) _then) = __$ReadingProgressDtoCopyWithImpl;
@override @useResult
$Res call({
 String bookId, double percentage, String location, DateTime updatedAt
});




}
/// @nodoc
class __$ReadingProgressDtoCopyWithImpl<$Res>
    implements _$ReadingProgressDtoCopyWith<$Res> {
  __$ReadingProgressDtoCopyWithImpl(this._self, this._then);

  final _ReadingProgressDto _self;
  final $Res Function(_ReadingProgressDto) _then;

/// Create a copy of ReadingProgressDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookId = null,Object? percentage = null,Object? location = null,Object? updatedAt = null,}) {
  return _then(_ReadingProgressDto(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
