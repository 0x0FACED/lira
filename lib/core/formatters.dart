import 'package:intl/intl.dart';

/// One localized decimal place; floor library progress until real completion.
String formatReadingPercentage(
  double value,
  String locale, {
  bool floor = false,
}) {
  var percentage = value.clamp(0.0, 100.0).toDouble();
  if (floor) percentage = (percentage * 10).floor() / 10;
  return '${NumberFormat('0.0', locale).format(percentage)}%';
}
