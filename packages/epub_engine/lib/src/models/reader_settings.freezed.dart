// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReaderSettings {

 String get fontFamily; double get fontSize; int get backgroundColor; double get lineHeight; double get horizontalPadding; ReadingMode get readingMode; double get brightness;
/// Create a copy of ReaderSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSettingsCopyWith<ReaderSettings> get copyWith => _$ReaderSettingsCopyWithImpl<ReaderSettings>(this as ReaderSettings, _$identity);

  /// Serializes this ReaderSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSettings&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.lineHeight, lineHeight) || other.lineHeight == lineHeight)&&(identical(other.horizontalPadding, horizontalPadding) || other.horizontalPadding == horizontalPadding)&&(identical(other.readingMode, readingMode) || other.readingMode == readingMode)&&(identical(other.brightness, brightness) || other.brightness == brightness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fontFamily,fontSize,backgroundColor,lineHeight,horizontalPadding,readingMode,brightness);

@override
String toString() {
  return 'ReaderSettings(fontFamily: $fontFamily, fontSize: $fontSize, backgroundColor: $backgroundColor, lineHeight: $lineHeight, horizontalPadding: $horizontalPadding, readingMode: $readingMode, brightness: $brightness)';
}


}

/// @nodoc
abstract mixin class $ReaderSettingsCopyWith<$Res>  {
  factory $ReaderSettingsCopyWith(ReaderSettings value, $Res Function(ReaderSettings) _then) = _$ReaderSettingsCopyWithImpl;
@useResult
$Res call({
 String fontFamily, double fontSize, int backgroundColor, double lineHeight, double horizontalPadding, ReadingMode readingMode, double brightness
});




}
/// @nodoc
class _$ReaderSettingsCopyWithImpl<$Res>
    implements $ReaderSettingsCopyWith<$Res> {
  _$ReaderSettingsCopyWithImpl(this._self, this._then);

  final ReaderSettings _self;
  final $Res Function(ReaderSettings) _then;

/// Create a copy of ReaderSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fontFamily = null,Object? fontSize = null,Object? backgroundColor = null,Object? lineHeight = null,Object? horizontalPadding = null,Object? readingMode = null,Object? brightness = null,}) {
  return _then(_self.copyWith(
fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,lineHeight: null == lineHeight ? _self.lineHeight : lineHeight // ignore: cast_nullable_to_non_nullable
as double,horizontalPadding: null == horizontalPadding ? _self.horizontalPadding : horizontalPadding // ignore: cast_nullable_to_non_nullable
as double,readingMode: null == readingMode ? _self.readingMode : readingMode // ignore: cast_nullable_to_non_nullable
as ReadingMode,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderSettings].
extension ReaderSettingsPatterns on ReaderSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderSettings value)  $default,){
final _that = this;
switch (_that) {
case _ReaderSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fontFamily,  double fontSize,  int backgroundColor,  double lineHeight,  double horizontalPadding,  ReadingMode readingMode,  double brightness)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSettings() when $default != null:
return $default(_that.fontFamily,_that.fontSize,_that.backgroundColor,_that.lineHeight,_that.horizontalPadding,_that.readingMode,_that.brightness);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fontFamily,  double fontSize,  int backgroundColor,  double lineHeight,  double horizontalPadding,  ReadingMode readingMode,  double brightness)  $default,) {final _that = this;
switch (_that) {
case _ReaderSettings():
return $default(_that.fontFamily,_that.fontSize,_that.backgroundColor,_that.lineHeight,_that.horizontalPadding,_that.readingMode,_that.brightness);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fontFamily,  double fontSize,  int backgroundColor,  double lineHeight,  double horizontalPadding,  ReadingMode readingMode,  double brightness)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSettings() when $default != null:
return $default(_that.fontFamily,_that.fontSize,_that.backgroundColor,_that.lineHeight,_that.horizontalPadding,_that.readingMode,_that.brightness);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReaderSettings implements ReaderSettings {
  const _ReaderSettings({this.fontFamily = 'sans-serif', this.fontSize = 16.0, this.backgroundColor = 0xFF121212, this.lineHeight = 1.5, this.horizontalPadding = 20.0, this.readingMode = ReadingMode.vertical, this.brightness = 1.0});
  factory _ReaderSettings.fromJson(Map<String, dynamic> json) => _$ReaderSettingsFromJson(json);

@override@JsonKey() final  String fontFamily;
@override@JsonKey() final  double fontSize;
@override@JsonKey() final  int backgroundColor;
@override@JsonKey() final  double lineHeight;
@override@JsonKey() final  double horizontalPadding;
@override@JsonKey() final  ReadingMode readingMode;
@override@JsonKey() final  double brightness;

/// Create a copy of ReaderSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderSettingsCopyWith<_ReaderSettings> get copyWith => __$ReaderSettingsCopyWithImpl<_ReaderSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReaderSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSettings&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.lineHeight, lineHeight) || other.lineHeight == lineHeight)&&(identical(other.horizontalPadding, horizontalPadding) || other.horizontalPadding == horizontalPadding)&&(identical(other.readingMode, readingMode) || other.readingMode == readingMode)&&(identical(other.brightness, brightness) || other.brightness == brightness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fontFamily,fontSize,backgroundColor,lineHeight,horizontalPadding,readingMode,brightness);

@override
String toString() {
  return 'ReaderSettings(fontFamily: $fontFamily, fontSize: $fontSize, backgroundColor: $backgroundColor, lineHeight: $lineHeight, horizontalPadding: $horizontalPadding, readingMode: $readingMode, brightness: $brightness)';
}


}

/// @nodoc
abstract mixin class _$ReaderSettingsCopyWith<$Res> implements $ReaderSettingsCopyWith<$Res> {
  factory _$ReaderSettingsCopyWith(_ReaderSettings value, $Res Function(_ReaderSettings) _then) = __$ReaderSettingsCopyWithImpl;
@override @useResult
$Res call({
 String fontFamily, double fontSize, int backgroundColor, double lineHeight, double horizontalPadding, ReadingMode readingMode, double brightness
});




}
/// @nodoc
class __$ReaderSettingsCopyWithImpl<$Res>
    implements _$ReaderSettingsCopyWith<$Res> {
  __$ReaderSettingsCopyWithImpl(this._self, this._then);

  final _ReaderSettings _self;
  final $Res Function(_ReaderSettings) _then;

/// Create a copy of ReaderSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fontFamily = null,Object? fontSize = null,Object? backgroundColor = null,Object? lineHeight = null,Object? horizontalPadding = null,Object? readingMode = null,Object? brightness = null,}) {
  return _then(_ReaderSettings(
fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,lineHeight: null == lineHeight ? _self.lineHeight : lineHeight // ignore: cast_nullable_to_non_nullable
as double,horizontalPadding: null == horizontalPadding ? _self.horizontalPadding : horizontalPadding // ignore: cast_nullable_to_non_nullable
as double,readingMode: null == readingMode ? _self.readingMode : readingMode // ignore: cast_nullable_to_non_nullable
as ReadingMode,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
