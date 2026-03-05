// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookLocation {

/// An opaque string location identifier (e.g. CFI for EPUB, page number for PDF)
 String get locator;
/// Create a copy of BookLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookLocationCopyWith<BookLocation> get copyWith => _$BookLocationCopyWithImpl<BookLocation>(this as BookLocation, _$identity);

  /// Serializes this BookLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookLocation&&(identical(other.locator, locator) || other.locator == locator));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locator);

@override
String toString() {
  return 'BookLocation(locator: $locator)';
}


}

/// @nodoc
abstract mixin class $BookLocationCopyWith<$Res>  {
  factory $BookLocationCopyWith(BookLocation value, $Res Function(BookLocation) _then) = _$BookLocationCopyWithImpl;
@useResult
$Res call({
 String locator
});




}
/// @nodoc
class _$BookLocationCopyWithImpl<$Res>
    implements $BookLocationCopyWith<$Res> {
  _$BookLocationCopyWithImpl(this._self, this._then);

  final BookLocation _self;
  final $Res Function(BookLocation) _then;

/// Create a copy of BookLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locator = null,}) {
  return _then(_self.copyWith(
locator: null == locator ? _self.locator : locator // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BookLocation].
extension BookLocationPatterns on BookLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookLocation value)  $default,){
final _that = this;
switch (_that) {
case _BookLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookLocation value)?  $default,){
final _that = this;
switch (_that) {
case _BookLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String locator)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookLocation() when $default != null:
return $default(_that.locator);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String locator)  $default,) {final _that = this;
switch (_that) {
case _BookLocation():
return $default(_that.locator);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String locator)?  $default,) {final _that = this;
switch (_that) {
case _BookLocation() when $default != null:
return $default(_that.locator);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookLocation implements BookLocation {
  const _BookLocation({required this.locator});
  factory _BookLocation.fromJson(Map<String, dynamic> json) => _$BookLocationFromJson(json);

/// An opaque string location identifier (e.g. CFI for EPUB, page number for PDF)
@override final  String locator;

/// Create a copy of BookLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookLocationCopyWith<_BookLocation> get copyWith => __$BookLocationCopyWithImpl<_BookLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookLocation&&(identical(other.locator, locator) || other.locator == locator));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locator);

@override
String toString() {
  return 'BookLocation(locator: $locator)';
}


}

/// @nodoc
abstract mixin class _$BookLocationCopyWith<$Res> implements $BookLocationCopyWith<$Res> {
  factory _$BookLocationCopyWith(_BookLocation value, $Res Function(_BookLocation) _then) = __$BookLocationCopyWithImpl;
@override @useResult
$Res call({
 String locator
});




}
/// @nodoc
class __$BookLocationCopyWithImpl<$Res>
    implements _$BookLocationCopyWith<$Res> {
  __$BookLocationCopyWithImpl(this._self, this._then);

  final _BookLocation _self;
  final $Res Function(_BookLocation) _then;

/// Create a copy of BookLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locator = null,}) {
  return _then(_BookLocation(
locator: null == locator ? _self.locator : locator // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
