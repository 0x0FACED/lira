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

 String get fontFamily; double get fontSize; int get backgroundColor; double get lineHeight; double get paragraphIndent; double get paragraphSpacing; bool get hyphenation; int get fontWeight; ReaderTextAlign get textAlign; int? get textColor; int? get linkColor; int? get selectionColor; double get textContrast; double get horizontalPadding; ReadingMode get readingMode; bool get enableDualPageSpread; double get brightness;
/// Create a copy of ReaderSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSettingsCopyWith<ReaderSettings> get copyWith => _$ReaderSettingsCopyWithImpl<ReaderSettings>(this as ReaderSettings, _$identity);

  /// Serializes this ReaderSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSettings&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.lineHeight, lineHeight) || other.lineHeight == lineHeight)&&(identical(other.paragraphIndent, paragraphIndent) || other.paragraphIndent == paragraphIndent)&&(identical(other.paragraphSpacing, paragraphSpacing) || other.paragraphSpacing == paragraphSpacing)&&(identical(other.hyphenation, hyphenation) || other.hyphenation == hyphenation)&&(identical(other.fontWeight, fontWeight) || other.fontWeight == fontWeight)&&(identical(other.textAlign, textAlign) || other.textAlign == textAlign)&&(identical(other.textColor, textColor) || other.textColor == textColor)&&(identical(other.linkColor, linkColor) || other.linkColor == linkColor)&&(identical(other.selectionColor, selectionColor) || other.selectionColor == selectionColor)&&(identical(other.textContrast, textContrast) || other.textContrast == textContrast)&&(identical(other.horizontalPadding, horizontalPadding) || other.horizontalPadding == horizontalPadding)&&(identical(other.readingMode, readingMode) || other.readingMode == readingMode)&&(identical(other.enableDualPageSpread, enableDualPageSpread) || other.enableDualPageSpread == enableDualPageSpread)&&(identical(other.brightness, brightness) || other.brightness == brightness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fontFamily,fontSize,backgroundColor,lineHeight,paragraphIndent,paragraphSpacing,hyphenation,fontWeight,textAlign,textColor,linkColor,selectionColor,textContrast,horizontalPadding,readingMode,enableDualPageSpread,brightness);

@override
String toString() {
  return 'ReaderSettings(fontFamily: $fontFamily, fontSize: $fontSize, backgroundColor: $backgroundColor, lineHeight: $lineHeight, paragraphIndent: $paragraphIndent, paragraphSpacing: $paragraphSpacing, hyphenation: $hyphenation, fontWeight: $fontWeight, textAlign: $textAlign, textColor: $textColor, linkColor: $linkColor, selectionColor: $selectionColor, textContrast: $textContrast, horizontalPadding: $horizontalPadding, readingMode: $readingMode, enableDualPageSpread: $enableDualPageSpread, brightness: $brightness)';
}


}

/// @nodoc
abstract mixin class $ReaderSettingsCopyWith<$Res>  {
  factory $ReaderSettingsCopyWith(ReaderSettings value, $Res Function(ReaderSettings) _then) = _$ReaderSettingsCopyWithImpl;
@useResult
$Res call({
 String fontFamily, double fontSize, int backgroundColor, double lineHeight, double paragraphIndent, double paragraphSpacing, bool hyphenation, int fontWeight, ReaderTextAlign textAlign, int? textColor, int? linkColor, int? selectionColor, double textContrast, double horizontalPadding, ReadingMode readingMode, bool enableDualPageSpread, double brightness
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
@pragma('vm:prefer-inline') @override $Res call({Object? fontFamily = null,Object? fontSize = null,Object? backgroundColor = null,Object? lineHeight = null,Object? paragraphIndent = null,Object? paragraphSpacing = null,Object? hyphenation = null,Object? fontWeight = null,Object? textAlign = null,Object? textColor = freezed,Object? linkColor = freezed,Object? selectionColor = freezed,Object? textContrast = null,Object? horizontalPadding = null,Object? readingMode = null,Object? enableDualPageSpread = null,Object? brightness = null,}) {
  return _then(_self.copyWith(
fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,lineHeight: null == lineHeight ? _self.lineHeight : lineHeight // ignore: cast_nullable_to_non_nullable
as double,paragraphIndent: null == paragraphIndent ? _self.paragraphIndent : paragraphIndent // ignore: cast_nullable_to_non_nullable
as double,paragraphSpacing: null == paragraphSpacing ? _self.paragraphSpacing : paragraphSpacing // ignore: cast_nullable_to_non_nullable
as double,hyphenation: null == hyphenation ? _self.hyphenation : hyphenation // ignore: cast_nullable_to_non_nullable
as bool,fontWeight: null == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as int,textAlign: null == textAlign ? _self.textAlign : textAlign // ignore: cast_nullable_to_non_nullable
as ReaderTextAlign,textColor: freezed == textColor ? _self.textColor : textColor // ignore: cast_nullable_to_non_nullable
as int?,linkColor: freezed == linkColor ? _self.linkColor : linkColor // ignore: cast_nullable_to_non_nullable
as int?,selectionColor: freezed == selectionColor ? _self.selectionColor : selectionColor // ignore: cast_nullable_to_non_nullable
as int?,textContrast: null == textContrast ? _self.textContrast : textContrast // ignore: cast_nullable_to_non_nullable
as double,horizontalPadding: null == horizontalPadding ? _self.horizontalPadding : horizontalPadding // ignore: cast_nullable_to_non_nullable
as double,readingMode: null == readingMode ? _self.readingMode : readingMode // ignore: cast_nullable_to_non_nullable
as ReadingMode,enableDualPageSpread: null == enableDualPageSpread ? _self.enableDualPageSpread : enableDualPageSpread // ignore: cast_nullable_to_non_nullable
as bool,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fontFamily,  double fontSize,  int backgroundColor,  double lineHeight,  double paragraphIndent,  double paragraphSpacing,  bool hyphenation,  int fontWeight,  ReaderTextAlign textAlign,  int? textColor,  int? linkColor,  int? selectionColor,  double textContrast,  double horizontalPadding,  ReadingMode readingMode,  bool enableDualPageSpread,  double brightness)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSettings() when $default != null:
return $default(_that.fontFamily,_that.fontSize,_that.backgroundColor,_that.lineHeight,_that.paragraphIndent,_that.paragraphSpacing,_that.hyphenation,_that.fontWeight,_that.textAlign,_that.textColor,_that.linkColor,_that.selectionColor,_that.textContrast,_that.horizontalPadding,_that.readingMode,_that.enableDualPageSpread,_that.brightness);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fontFamily,  double fontSize,  int backgroundColor,  double lineHeight,  double paragraphIndent,  double paragraphSpacing,  bool hyphenation,  int fontWeight,  ReaderTextAlign textAlign,  int? textColor,  int? linkColor,  int? selectionColor,  double textContrast,  double horizontalPadding,  ReadingMode readingMode,  bool enableDualPageSpread,  double brightness)  $default,) {final _that = this;
switch (_that) {
case _ReaderSettings():
return $default(_that.fontFamily,_that.fontSize,_that.backgroundColor,_that.lineHeight,_that.paragraphIndent,_that.paragraphSpacing,_that.hyphenation,_that.fontWeight,_that.textAlign,_that.textColor,_that.linkColor,_that.selectionColor,_that.textContrast,_that.horizontalPadding,_that.readingMode,_that.enableDualPageSpread,_that.brightness);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fontFamily,  double fontSize,  int backgroundColor,  double lineHeight,  double paragraphIndent,  double paragraphSpacing,  bool hyphenation,  int fontWeight,  ReaderTextAlign textAlign,  int? textColor,  int? linkColor,  int? selectionColor,  double textContrast,  double horizontalPadding,  ReadingMode readingMode,  bool enableDualPageSpread,  double brightness)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSettings() when $default != null:
return $default(_that.fontFamily,_that.fontSize,_that.backgroundColor,_that.lineHeight,_that.paragraphIndent,_that.paragraphSpacing,_that.hyphenation,_that.fontWeight,_that.textAlign,_that.textColor,_that.linkColor,_that.selectionColor,_that.textContrast,_that.horizontalPadding,_that.readingMode,_that.enableDualPageSpread,_that.brightness);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReaderSettings extends ReaderSettings {
  const _ReaderSettings({this.fontFamily = 'sans-serif', this.fontSize = 16.0, this.backgroundColor = 0xFF121212, this.lineHeight = 1.5, this.paragraphIndent = 1.5, this.paragraphSpacing = 0.5, this.hyphenation = false, this.fontWeight = 400, this.textAlign = ReaderTextAlign.original, this.textColor, this.linkColor, this.selectionColor, this.textContrast = 1.0, this.horizontalPadding = 20.0, this.readingMode = ReadingMode.vertical, this.enableDualPageSpread = true, this.brightness = 1.0}): super._();
  factory _ReaderSettings.fromJson(Map<String, dynamic> json) => _$ReaderSettingsFromJson(json);

@override@JsonKey() final  String fontFamily;
@override@JsonKey() final  double fontSize;
@override@JsonKey() final  int backgroundColor;
@override@JsonKey() final  double lineHeight;
@override@JsonKey() final  double paragraphIndent;
@override@JsonKey() final  double paragraphSpacing;
@override@JsonKey() final  bool hyphenation;
@override@JsonKey() final  int fontWeight;
@override@JsonKey() final  ReaderTextAlign textAlign;
@override final  int? textColor;
@override final  int? linkColor;
@override final  int? selectionColor;
@override@JsonKey() final  double textContrast;
@override@JsonKey() final  double horizontalPadding;
@override@JsonKey() final  ReadingMode readingMode;
@override@JsonKey() final  bool enableDualPageSpread;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSettings&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.lineHeight, lineHeight) || other.lineHeight == lineHeight)&&(identical(other.paragraphIndent, paragraphIndent) || other.paragraphIndent == paragraphIndent)&&(identical(other.paragraphSpacing, paragraphSpacing) || other.paragraphSpacing == paragraphSpacing)&&(identical(other.hyphenation, hyphenation) || other.hyphenation == hyphenation)&&(identical(other.fontWeight, fontWeight) || other.fontWeight == fontWeight)&&(identical(other.textAlign, textAlign) || other.textAlign == textAlign)&&(identical(other.textColor, textColor) || other.textColor == textColor)&&(identical(other.linkColor, linkColor) || other.linkColor == linkColor)&&(identical(other.selectionColor, selectionColor) || other.selectionColor == selectionColor)&&(identical(other.textContrast, textContrast) || other.textContrast == textContrast)&&(identical(other.horizontalPadding, horizontalPadding) || other.horizontalPadding == horizontalPadding)&&(identical(other.readingMode, readingMode) || other.readingMode == readingMode)&&(identical(other.enableDualPageSpread, enableDualPageSpread) || other.enableDualPageSpread == enableDualPageSpread)&&(identical(other.brightness, brightness) || other.brightness == brightness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fontFamily,fontSize,backgroundColor,lineHeight,paragraphIndent,paragraphSpacing,hyphenation,fontWeight,textAlign,textColor,linkColor,selectionColor,textContrast,horizontalPadding,readingMode,enableDualPageSpread,brightness);

@override
String toString() {
  return 'ReaderSettings(fontFamily: $fontFamily, fontSize: $fontSize, backgroundColor: $backgroundColor, lineHeight: $lineHeight, paragraphIndent: $paragraphIndent, paragraphSpacing: $paragraphSpacing, hyphenation: $hyphenation, fontWeight: $fontWeight, textAlign: $textAlign, textColor: $textColor, linkColor: $linkColor, selectionColor: $selectionColor, textContrast: $textContrast, horizontalPadding: $horizontalPadding, readingMode: $readingMode, enableDualPageSpread: $enableDualPageSpread, brightness: $brightness)';
}


}

/// @nodoc
abstract mixin class _$ReaderSettingsCopyWith<$Res> implements $ReaderSettingsCopyWith<$Res> {
  factory _$ReaderSettingsCopyWith(_ReaderSettings value, $Res Function(_ReaderSettings) _then) = __$ReaderSettingsCopyWithImpl;
@override @useResult
$Res call({
 String fontFamily, double fontSize, int backgroundColor, double lineHeight, double paragraphIndent, double paragraphSpacing, bool hyphenation, int fontWeight, ReaderTextAlign textAlign, int? textColor, int? linkColor, int? selectionColor, double textContrast, double horizontalPadding, ReadingMode readingMode, bool enableDualPageSpread, double brightness
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
@override @pragma('vm:prefer-inline') $Res call({Object? fontFamily = null,Object? fontSize = null,Object? backgroundColor = null,Object? lineHeight = null,Object? paragraphIndent = null,Object? paragraphSpacing = null,Object? hyphenation = null,Object? fontWeight = null,Object? textAlign = null,Object? textColor = freezed,Object? linkColor = freezed,Object? selectionColor = freezed,Object? textContrast = null,Object? horizontalPadding = null,Object? readingMode = null,Object? enableDualPageSpread = null,Object? brightness = null,}) {
  return _then(_ReaderSettings(
fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,lineHeight: null == lineHeight ? _self.lineHeight : lineHeight // ignore: cast_nullable_to_non_nullable
as double,paragraphIndent: null == paragraphIndent ? _self.paragraphIndent : paragraphIndent // ignore: cast_nullable_to_non_nullable
as double,paragraphSpacing: null == paragraphSpacing ? _self.paragraphSpacing : paragraphSpacing // ignore: cast_nullable_to_non_nullable
as double,hyphenation: null == hyphenation ? _self.hyphenation : hyphenation // ignore: cast_nullable_to_non_nullable
as bool,fontWeight: null == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as int,textAlign: null == textAlign ? _self.textAlign : textAlign // ignore: cast_nullable_to_non_nullable
as ReaderTextAlign,textColor: freezed == textColor ? _self.textColor : textColor // ignore: cast_nullable_to_non_nullable
as int?,linkColor: freezed == linkColor ? _self.linkColor : linkColor // ignore: cast_nullable_to_non_nullable
as int?,selectionColor: freezed == selectionColor ? _self.selectionColor : selectionColor // ignore: cast_nullable_to_non_nullable
as int?,textContrast: null == textContrast ? _self.textContrast : textContrast // ignore: cast_nullable_to_non_nullable
as double,horizontalPadding: null == horizontalPadding ? _self.horizontalPadding : horizontalPadding // ignore: cast_nullable_to_non_nullable
as double,readingMode: null == readingMode ? _self.readingMode : readingMode // ignore: cast_nullable_to_non_nullable
as ReadingMode,enableDualPageSpread: null == enableDualPageSpread ? _self.enableDualPageSpread : enableDualPageSpread // ignore: cast_nullable_to_non_nullable
as bool,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
