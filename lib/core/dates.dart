import 'package:intl/intl.dart';

/// yyyy-MM-dd on this device's calendar.
String isoDate(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "October 21".
String monthDay(DateTime day) => DateFormat('MMMM d', 'en_US').format(day);

/// "Monday, October 5, 2026"; today when [iso] is missing or unreadable.
String longDate([String? iso]) =>
    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.tryParse(iso ?? '') ?? DateTime.now());

/// "Mon, Oct 5"; today when [iso] is missing or unreadable.
String dayLabel([String? iso]) => DateFormat('EEE, MMM d').format(DateTime.tryParse(iso ?? '') ?? DateTime.now());

/// "Oct 5".
String shortDate(DateTime day) => DateFormat('MMM d').format(day);

/// Seconds as mm:ss.
String clock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

extension DayOfYear on DateTime {
  // Rounded, so a daylight-saving hour never drops a day.
  int get dayOfYear => (dateOnly(this).difference(DateTime(year)).inHours / 24).round() + 1;
}
