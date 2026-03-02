// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BookLocation _$BookLocationFromJson(Map<String, dynamic> json) {
  return _BookLocation.fromJson(json);
}

/// @nodoc
mixin _$BookLocation {
  /// An opaque string location identifier (e.g. CFI for EPUB, page number for PDF)
  String get locator => throw _privateConstructorUsedError;

  /// Serializes this BookLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BookLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BookLocationCopyWith<BookLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookLocationCopyWith<$Res> {
  factory $BookLocationCopyWith(
    BookLocation value,
    $Res Function(BookLocation) then,
  ) = _$BookLocationCopyWithImpl<$Res, BookLocation>;
  @useResult
  $Res call({String locator});
}

/// @nodoc
class _$BookLocationCopyWithImpl<$Res, $Val extends BookLocation>
    implements $BookLocationCopyWith<$Res> {
  _$BookLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BookLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? locator = null}) {
    return _then(
      _value.copyWith(
            locator: null == locator
                ? _value.locator
                : locator // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BookLocationImplCopyWith<$Res>
    implements $BookLocationCopyWith<$Res> {
  factory _$$BookLocationImplCopyWith(
    _$BookLocationImpl value,
    $Res Function(_$BookLocationImpl) then,
  ) = __$$BookLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String locator});
}

/// @nodoc
class __$$BookLocationImplCopyWithImpl<$Res>
    extends _$BookLocationCopyWithImpl<$Res, _$BookLocationImpl>
    implements _$$BookLocationImplCopyWith<$Res> {
  __$$BookLocationImplCopyWithImpl(
    _$BookLocationImpl _value,
    $Res Function(_$BookLocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BookLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? locator = null}) {
    return _then(
      _$BookLocationImpl(
        locator: null == locator
            ? _value.locator
            : locator // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BookLocationImpl implements _BookLocation {
  const _$BookLocationImpl({required this.locator});

  factory _$BookLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookLocationImplFromJson(json);

  /// An opaque string location identifier (e.g. CFI for EPUB, page number for PDF)
  @override
  final String locator;

  @override
  String toString() {
    return 'BookLocation(locator: $locator)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookLocationImpl &&
            (identical(other.locator, locator) || other.locator == locator));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, locator);

  /// Create a copy of BookLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BookLocationImplCopyWith<_$BookLocationImpl> get copyWith =>
      __$$BookLocationImplCopyWithImpl<_$BookLocationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookLocationImplToJson(this);
  }
}

abstract class _BookLocation implements BookLocation {
  const factory _BookLocation({required final String locator}) =
      _$BookLocationImpl;

  factory _BookLocation.fromJson(Map<String, dynamic> json) =
      _$BookLocationImpl.fromJson;

  /// An opaque string location identifier (e.g. CFI for EPUB, page number for PDF)
  @override
  String get locator;

  /// Create a copy of BookLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BookLocationImplCopyWith<_$BookLocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
