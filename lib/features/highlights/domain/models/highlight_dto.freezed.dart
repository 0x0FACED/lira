// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'highlight_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

HighlightDto _$HighlightDtoFromJson(Map<String, dynamic> json) {
  return _HighlightDto.fromJson(json);
}

/// @nodoc
mixin _$HighlightDto {
  String get id => throw _privateConstructorUsedError;
  String get bookId => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this HighlightDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HighlightDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HighlightDtoCopyWith<HighlightDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HighlightDtoCopyWith<$Res> {
  factory $HighlightDtoCopyWith(
    HighlightDto value,
    $Res Function(HighlightDto) then,
  ) = _$HighlightDtoCopyWithImpl<$Res, HighlightDto>;
  @useResult
  $Res call({
    String id,
    String bookId,
    String text,
    String color,
    String location,
    String? note,
    DateTime createdAt,
  });
}

/// @nodoc
class _$HighlightDtoCopyWithImpl<$Res, $Val extends HighlightDto>
    implements $HighlightDtoCopyWith<$Res> {
  _$HighlightDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HighlightDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bookId = null,
    Object? text = null,
    Object? color = null,
    Object? location = null,
    Object? note = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            bookId: null == bookId
                ? _value.bookId
                : bookId // ignore: cast_nullable_to_non_nullable
                      as String,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as String,
            location: null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HighlightDtoImplCopyWith<$Res>
    implements $HighlightDtoCopyWith<$Res> {
  factory _$$HighlightDtoImplCopyWith(
    _$HighlightDtoImpl value,
    $Res Function(_$HighlightDtoImpl) then,
  ) = __$$HighlightDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String bookId,
    String text,
    String color,
    String location,
    String? note,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$HighlightDtoImplCopyWithImpl<$Res>
    extends _$HighlightDtoCopyWithImpl<$Res, _$HighlightDtoImpl>
    implements _$$HighlightDtoImplCopyWith<$Res> {
  __$$HighlightDtoImplCopyWithImpl(
    _$HighlightDtoImpl _value,
    $Res Function(_$HighlightDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HighlightDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bookId = null,
    Object? text = null,
    Object? color = null,
    Object? location = null,
    Object? note = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$HighlightDtoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        bookId: null == bookId
            ? _value.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as String,
        location: null == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HighlightDtoImpl implements _HighlightDto {
  const _$HighlightDtoImpl({
    required this.id,
    required this.bookId,
    required this.text,
    this.color = '#BB86FC',
    required this.location,
    this.note,
    required this.createdAt,
  });

  factory _$HighlightDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$HighlightDtoImplFromJson(json);

  @override
  final String id;
  @override
  final String bookId;
  @override
  final String text;
  @override
  @JsonKey()
  final String color;
  @override
  final String location;
  @override
  final String? note;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'HighlightDto(id: $id, bookId: $bookId, text: $text, color: $color, location: $location, note: $note, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HighlightDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.bookId, bookId) || other.bookId == bookId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    bookId,
    text,
    color,
    location,
    note,
    createdAt,
  );

  /// Create a copy of HighlightDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HighlightDtoImplCopyWith<_$HighlightDtoImpl> get copyWith =>
      __$$HighlightDtoImplCopyWithImpl<_$HighlightDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HighlightDtoImplToJson(this);
  }
}

abstract class _HighlightDto implements HighlightDto {
  const factory _HighlightDto({
    required final String id,
    required final String bookId,
    required final String text,
    final String color,
    required final String location,
    final String? note,
    required final DateTime createdAt,
  }) = _$HighlightDtoImpl;

  factory _HighlightDto.fromJson(Map<String, dynamic> json) =
      _$HighlightDtoImpl.fromJson;

  @override
  String get id;
  @override
  String get bookId;
  @override
  String get text;
  @override
  String get color;
  @override
  String get location;
  @override
  String? get note;
  @override
  DateTime get createdAt;

  /// Create a copy of HighlightDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HighlightDtoImplCopyWith<_$HighlightDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
