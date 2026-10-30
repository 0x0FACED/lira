// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReaderSettings _$ReaderSettingsFromJson(Map<String, dynamic> json) =>
    _ReaderSettings(
      fontFamily: json['fontFamily'] as String? ?? 'sans-serif',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0xFF121212,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      paragraphIndent: (json['paragraphIndent'] as num?)?.toDouble() ?? 1.5,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 0.5,
      hyphenation: json['hyphenation'] as bool? ?? false,
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
      textAlign:
          $enumDecodeNullable(_$ReaderTextAlignEnumMap, json['textAlign']) ??
          ReaderTextAlign.original,
      textColor: (json['textColor'] as num?)?.toInt(),
      linkColor: (json['linkColor'] as num?)?.toInt(),
      selectionColor: (json['selectionColor'] as num?)?.toInt(),
      textContrast: (json['textContrast'] as num?)?.toDouble() ?? 1.0,
      horizontalPadding:
          (json['horizontalPadding'] as num?)?.toDouble() ?? 20.0,
      readingMode:
          $enumDecodeNullable(_$ReadingModeEnumMap, json['readingMode']) ??
          ReadingMode.vertical,
      enableDualPageSpread: json['enableDualPageSpread'] as bool? ?? true,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$ReaderSettingsToJson(_ReaderSettings instance) =>
    <String, dynamic>{
      'fontFamily': instance.fontFamily,
      'fontSize': instance.fontSize,
      'backgroundColor': instance.backgroundColor,
      'lineHeight': instance.lineHeight,
      'paragraphIndent': instance.paragraphIndent,
      'paragraphSpacing': instance.paragraphSpacing,
      'hyphenation': instance.hyphenation,
      'fontWeight': instance.fontWeight,
      'textAlign': _$ReaderTextAlignEnumMap[instance.textAlign]!,
      'textColor': instance.textColor,
      'linkColor': instance.linkColor,
      'selectionColor': instance.selectionColor,
      'textContrast': instance.textContrast,
      'horizontalPadding': instance.horizontalPadding,
      'readingMode': _$ReadingModeEnumMap[instance.readingMode]!,
      'enableDualPageSpread': instance.enableDualPageSpread,
      'brightness': instance.brightness,
    };

const _$ReaderTextAlignEnumMap = {
  ReaderTextAlign.original: 'original',
  ReaderTextAlign.left: 'left',
  ReaderTextAlign.justify: 'justify',
};

const _$ReadingModeEnumMap = {
  ReadingMode.vertical: 'vertical',
  ReadingMode.horizontal: 'horizontal',
};
