// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReaderSettingsImpl _$$ReaderSettingsImplFromJson(Map<String, dynamic> json) =>
    _$ReaderSettingsImpl(
      fontFamily: json['fontFamily'] as String? ?? 'sans-serif',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0xFF121212,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      horizontalPadding:
          (json['horizontalPadding'] as num?)?.toDouble() ?? 20.0,
    );

Map<String, dynamic> _$$ReaderSettingsImplToJson(
  _$ReaderSettingsImpl instance,
) => <String, dynamic>{
  'fontFamily': instance.fontFamily,
  'fontSize': instance.fontSize,
  'backgroundColor': instance.backgroundColor,
  'lineHeight': instance.lineHeight,
  'horizontalPadding': instance.horizontalPadding,
};
