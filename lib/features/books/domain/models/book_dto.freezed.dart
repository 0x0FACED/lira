// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BookDto _$BookDtoFromJson(Map<String, dynamic> json) {
  return _BookDto.fromJson(json);
}

/// @nodoc
mixin _$BookDto {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get format => throw _privateConstructorUsedError; // epub, pdf
  String? get coverUrl => throw _privateConstructorUsedError;
  String? get fileUrl => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this BookDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BookDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BookDtoCopyWith<BookDto> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookDtoCopyWith<$Res> {
  factory $BookDtoCopyWith(BookDto value, $Res Function(BookDto) then) =
      _$BookDtoCopyWithImpl<$Res, BookDto>;
  @useResult
  $Res call({
    String id,
    String title,
    String author,
    String format,
    String? coverUrl,
    String? fileUrl,
    DateTime createdAt,
  });
}

/// @nodoc
class _$BookDtoCopyWithImpl<$Res, $Val extends BookDto>
    implements $BookDtoCopyWith<$Res> {
  _$BookDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BookDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? author = null,
    Object? format = null,
    Object? coverUrl = freezed,
    Object? fileUrl = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            author: null == author
                ? _value.author
                : author // ignore: cast_nullable_to_non_nullable
                      as String,
            format: null == format
                ? _value.format
                : format // ignore: cast_nullable_to_non_nullable
                      as String,
            coverUrl: freezed == coverUrl
                ? _value.coverUrl
                : coverUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            fileUrl: freezed == fileUrl
                ? _value.fileUrl
                : fileUrl // ignore: cast_nullable_to_non_nullable
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
abstract class _$$BookDtoImplCopyWith<$Res> implements $BookDtoCopyWith<$Res> {
  factory _$$BookDtoImplCopyWith(
    _$BookDtoImpl value,
    $Res Function(_$BookDtoImpl) then,
  ) = __$$BookDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String author,
    String format,
    String? coverUrl,
    String? fileUrl,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$BookDtoImplCopyWithImpl<$Res>
    extends _$BookDtoCopyWithImpl<$Res, _$BookDtoImpl>
    implements _$$BookDtoImplCopyWith<$Res> {
  __$$BookDtoImplCopyWithImpl(
    _$BookDtoImpl _value,
    $Res Function(_$BookDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BookDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? author = null,
    Object? format = null,
    Object? coverUrl = freezed,
    Object? fileUrl = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$BookDtoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _value.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        format: null == format
            ? _value.format
            : format // ignore: cast_nullable_to_non_nullable
                  as String,
        coverUrl: freezed == coverUrl
            ? _value.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        fileUrl: freezed == fileUrl
            ? _value.fileUrl
            : fileUrl // ignore: cast_nullable_to_non_nullable
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
class _$BookDtoImpl implements _BookDto {
  const _$BookDtoImpl({
    required this.id,
    required this.title,
    this.author = 'Unknown Author',
    required this.format,
    this.coverUrl,
    this.fileUrl,
    required this.createdAt,
  });

  factory _$BookDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookDtoImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final String author;
  @override
  final String format;
  // epub, pdf
  @override
  final String? coverUrl;
  @override
  final String? fileUrl;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'BookDto(id: $id, title: $title, author: $author, format: $format, coverUrl: $coverUrl, fileUrl: $fileUrl, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.format, format) || other.format == format) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    author,
    format,
    coverUrl,
    fileUrl,
    createdAt,
  );

  /// Create a copy of BookDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BookDtoImplCopyWith<_$BookDtoImpl> get copyWith =>
      __$$BookDtoImplCopyWithImpl<_$BookDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookDtoImplToJson(this);
  }
}

abstract class _BookDto implements BookDto {
  const factory _BookDto({
    required final String id,
    required final String title,
    final String author,
    required final String format,
    final String? coverUrl,
    final String? fileUrl,
    required final DateTime createdAt,
  }) = _$BookDtoImpl;

  factory _BookDto.fromJson(Map<String, dynamic> json) = _$BookDtoImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get author;
  @override
  String get format; // epub, pdf
  @override
  String? get coverUrl;
  @override
  String? get fileUrl;
  @override
  DateTime get createdAt;

  /// Create a copy of BookDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BookDtoImplCopyWith<_$BookDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
