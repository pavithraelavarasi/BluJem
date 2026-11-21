import 'package:intl/intl.dart';

/// When each puzzle goes live, in India's time (UTC+5:30 all year). Every
/// day, Sunday included, has three four-word puzzles: morning, afternoon and
/// night. The morning one opens when the admin publishes it, but not before
/// 9:00; the afternoon one opens at 15:00 and the night one at 21:00.
/// Sundays used to have one six-word Mega BluJem instead ([Slot.sunday]):
/// none are taken any more, but those stored still open and show as before. The afternoon keeps its old name,
/// evening, from when it was the second of two. The server's twin is
/// catalyst/functions/jumble_data/lib/slots.js, which is what actually
/// decides — this only says when to expect one.
enum Slot {
  morning(9, 4, 'Morning', opensOnPublish: true),
  evening(15, 4, 'Afternoon'),
  night(21, 4, 'Night'),
  sunday(6, 6, 'Mega BluJem', opensOnPublish: true);

  const Slot(this.hour, this.words, this.label, {this.opensOnPublish = false});

  /// The earliest it opens; the afternoon's and night's fixed time.
  final int hour;
  final int words;
  final String label;

  /// Whether it opens when the admin publishes it, rather than at [hour].
  final bool opensOnPublish;

  static Slot? tryParse(String? name) => Slot.values.where((s) => s.name == name).firstOrNull;

  /// The slots of the India date [isoDate]: the same three every day.
  static List<Slot> forDate(String isoDate) => const [Slot.morning, Slot.evening, Slot.night];

  /// A puzzle stored without a slot: its day's first back then — the Mega
  /// BluJem on a Sunday — so old ones keep their times.
  static Slot defaultFor(String isoDate) => isSunday(isoDate) ? Slot.sunday : Slot.morning;

  /// "4:00 PM".
  String get time => DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour));

  /// "Night · 9:00 PM"; just "Morning" for one that opens when published.
  String get heading => opensOnPublish ? label : '$label · $time';
}

const _istOffset = Duration(hours: 5, minutes: 30);

bool isSunday(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  return d != null && DateTime.utc(d.year, d.month, d.day).weekday == DateTime.sunday;
}

/// The earliest [slot] on [isoDate] goes live: the afternoon's and night's fixed time.
DateTime slotStart(String isoDate, Slot slot) {
  final d = DateTime.parse(isoDate);
  return DateTime.utc(d.year, d.month, d.day, slot.hour).subtract(_istOffset);
}

/// India's date at [now], yyyy-MM-dd — the puzzle day, wherever the phone is.
String indiaDate(DateTime now) => DateFormat('yyyy-MM-dd').format(now.toUtc().add(_istOffset));

/// Why [slot] cannot be on [isoDate], or null when it can.
String? slotProblem(String isoDate, Slot slot) {
  if (DateTime.tryParse(isoDate) == null) return 'Choose a date.';
  if (slot == Slot.sunday) return 'There is no Sunday Mega BluJem any more. Choose morning, afternoon or night.';
  return null;
}
