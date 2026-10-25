import 'package:intl/intl.dart';

import '../../models/day_id.dart';

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Sábado 25 de octubre" (con el año si no es el actual).
String longDayTitle(String dayId) {
  final d = parseDayId(dayId);
  final sameYear = d.year == DateTime.now().year;
  final pattern = sameYear ? "EEEE d 'de' MMMM" : "EEEE d 'de' MMMM 'de' y";
  return _capitalize(DateFormat(pattern, 'es').format(d));
}

/// "Octubre 2026"
String monthTitle(DateTime month) => _capitalize(DateFormat('MMMM y', 'es').format(month));

/// "SÁB"
String weekdayShort(DateTime d) => DateFormat('EEE', 'es').format(d).replaceAll('.', '').toUpperCase();

/// Etiqueta relativa: "Hoy", "Ayer" o null.
String? relativeDayLabel(String dayId) {
  final t = todayId();
  if (dayId == t) return 'Hoy';
  if (dayId == shiftDayId(t, -1)) return 'Ayer';
  return null;
}
