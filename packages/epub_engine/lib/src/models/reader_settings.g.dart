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
      'horizontalPadding': instance.horizontalPadding,
      'readingMode': _$ReadingModeEnumMap[instance.readingMode]!,
      'enableDualPageSpread': instance.enableDualPageSpread,
      'brightness': instance.brightness,
    };

const _$ReadingModeEnumMap = {
  ReadingMode.vertical: 'vertical',
  ReadingMode.horizontal: 'horizontal',
};
