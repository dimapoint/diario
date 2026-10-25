import 'package:intl/intl.dart';

/// Los días se identifican con `yyyy-MM-dd`, que también es el id del
/// documento en Firestore.
final _format = DateFormat('yyyy-MM-dd');
final _pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

String dayIdOf(DateTime date) => _format.format(date);

String todayId() => dayIdOf(today());

bool isValidDayId(String id) {
  if (!_pattern.hasMatch(id)) return false;
  final parsed = DateTime.tryParse(id);
  return parsed != null && dayIdOf(parsed) == id;
}

DateTime parseDayId(String id) => DateTime.parse(id);

String shiftDayId(String id, int days) {
  final d = parseDayId(id);
  return dayIdOf(DateTime(d.year, d.month, d.day + days));
}

bool isFutureDayId(String id) => id.compareTo(todayId()) > 0;
