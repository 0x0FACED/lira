// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_progress_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReadingProgressDto _$ReadingProgressDtoFromJson(Map<String, dynamic> json) {
  return _ReadingProgressDto.fromJson(json);
}

/// @nodoc
mixin _$ReadingProgressDto {
  String get bookId => throw _privateConstructorUsedError;
  double get percentage => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ReadingProgressDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReadingProgressDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReadingProgressDtoCopyWith<ReadingProgressDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadingProgressDtoCopyWith<$Res> {
  factory $ReadingProgressDtoCopyWith(
    ReadingProgressDto value,
    $Res Function(ReadingProgressDto) then,
  ) = _$ReadingProgressDtoCopyWithImpl<$Res, ReadingProgressDto>;
  @useResult
  $Res call({
    String bookId,
    double percentage,
    String location,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$ReadingProgressDtoCopyWithImpl<$Res, $Val extends ReadingProgressDto>
    implements $ReadingProgressDtoCopyWith<$Res> {
  _$ReadingProgressDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReadingProgressDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookId = null,
    Object? percentage = null,
    Object? location = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            bookId: null == bookId
                ? _value.bookId
                : bookId // ignore: cast_nullable_to_non_nullable
                      as String,
            percentage: null == percentage
                ? _value.percentage
                : percentage // ignore: cast_nullable_to_non_nullable
                      as double,
            location: null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReadingProgressDtoImplCopyWith<$Res>
    implements $ReadingProgressDtoCopyWith<$Res> {
  factory _$$ReadingProgressDtoImplCopyWith(
    _$ReadingProgressDtoImpl value,
    $Res Function(_$ReadingProgressDtoImpl) then,
  ) = __$$ReadingProgressDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String bookId,
    double percentage,
    String location,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$ReadingProgressDtoImplCopyWithImpl<$Res>
    extends _$ReadingProgressDtoCopyWithImpl<$Res, _$ReadingProgressDtoImpl>
    implements _$$ReadingProgressDtoImplCopyWith<$Res> {
  __$$ReadingProgressDtoImplCopyWithImpl(
    _$ReadingProgressDtoImpl _value,
    $Res Function(_$ReadingProgressDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReadingProgressDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookId = null,
    Object? percentage = null,
    Object? location = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$ReadingProgressDtoImpl(
        bookId: null == bookId
            ? _value.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as String,
        percentage: null == percentage
            ? _value.percentage
            : percentage // ignore: cast_nullable_to_non_nullable
                  as double,
        location: null == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadingProgressDtoImpl implements _ReadingProgressDto {
  const _$ReadingProgressDtoImpl({
    required this.bookId,
    required this.percentage,
    required this.location,
    required this.updatedAt,
  });

  factory _$ReadingProgressDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadingProgressDtoImplFromJson(json);

  @override
  final String bookId;
  @override
  final double percentage;
  @override
  final String location;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'ReadingProgressDto(bookId: $bookId, percentage: $percentage, location: $location, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadingProgressDtoImpl &&
            (identical(other.bookId, bookId) || other.bookId == bookId) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, bookId, percentage, location, updatedAt);

  /// Create a copy of ReadingProgressDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadingProgressDtoImplCopyWith<_$ReadingProgressDtoImpl> get copyWith =>
      __$$ReadingProgressDtoImplCopyWithImpl<_$ReadingProgressDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadingProgressDtoImplToJson(this);
  }
}

abstract class _ReadingProgressDto implements ReadingProgressDto {
  const factory _ReadingProgressDto({
    required final String bookId,
    required final double percentage,
    required final String location,
    required final DateTime updatedAt,
  }) = _$ReadingProgressDtoImpl;

  factory _ReadingProgressDto.fromJson(Map<String, dynamic> json) =
      _$ReadingProgressDtoImpl.fromJson;

  @override
  String get bookId;
  @override
  double get percentage;
  @override
  String get location;
  @override
  DateTime get updatedAt;

  /// Create a copy of ReadingProgressDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReadingProgressDtoImplCopyWith<_$ReadingProgressDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
