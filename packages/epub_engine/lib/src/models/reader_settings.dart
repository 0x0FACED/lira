import 'package:flutter/painting.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader_settings.freezed.dart';
part 'reader_settings.g.dart';

/// Reading mode: vertical scroll or horizontal pagination
enum ReadingMode { vertical, horizontal }

enum ReaderTextAlign { original, left, justify }

@freezed
abstract class ReaderSettings with _$ReaderSettings {
  const ReaderSettings._();

  const factory ReaderSettings({
    @Default('sans-serif') String fontFamily,
    @Default(16.0) double fontSize,
    @Default(0xFF121212) int backgroundColor,
    @Default(1.5) double lineHeight,
    @Default(1.5) double paragraphIndent,
    @Default(0.5) double paragraphSpacing,
    @Default(false) bool hyphenation,
    @Default(400) int fontWeight,
    @Default(ReaderTextAlign.original) ReaderTextAlign textAlign,
    int? textColor,
    int? linkColor,
    int? selectionColor,
    @Default(1.0) double textContrast,
    @Default(20.0) double horizontalPadding,
    @Default(ReadingMode.vertical) ReadingMode readingMode,
    @Default(true) bool enableDualPageSpread,
    @Default(1.0) double brightness,
  }) = _ReaderSettings;

  factory ReaderSettings.fromJson(Map<String, dynamic> json) =>
      _$ReaderSettingsFromJson(json);

  Color get resolvedTextColor {
    final background = Color(backgroundColor);
    final selected = textColor == null
        ? background.computeLuminance() > 0.5
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFE0E0E0)
        : Color(textColor!);
    return Color.lerp(background, selected, textContrast.clamp(0.0, 1.0))!;
  }

  Color get resolvedLinkColor => linkColor == null
      ? resolvedTextColor.withAlpha(200)
      : Color.lerp(
          Color(backgroundColor),
          Color(linkColor!),
          textContrast.clamp(0.0, 1.0),
        )!;

  Color get resolvedSelectionColor => Color(selectionColor ?? 0x663F80FF);
}
