import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader_settings.freezed.dart';
part 'reader_settings.g.dart';

/// Reading mode: vertical scroll or horizontal pagination
enum ReadingMode { vertical, horizontal }

@freezed
abstract class ReaderSettings with _$ReaderSettings {
  const factory ReaderSettings({
    @Default('sans-serif') String fontFamily,
    @Default(16.0) double fontSize,
    @Default(0xFF121212) int backgroundColor,
    @Default(1.5) double lineHeight,
    @Default(20.0) double horizontalPadding,
    @Default(ReadingMode.vertical) ReadingMode readingMode,
    @Default(1.0) double brightness,
  }) = _ReaderSettings;

  factory ReaderSettings.fromJson(Map<String, dynamic> json) =>
      _$ReaderSettingsFromJson(json);
}
