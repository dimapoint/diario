import 'package:flutter/material.dart';

import '../../models/day_id.dart';
import '../../models/entry.dart';
import '../../models/mood.dart';
import '../common/formatting.dart';

/// Grilla mensual: cada día con entrada muestra su ánimo (o un punto).
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.entriesById,
    required this.onMonthChanged,
    required this.onDayTap,
    this.selectedId,
    this.compact = false,
  });

  /// Cualquier fecha del mes a mostrar.
  final DateTime month;
  final Map<String, DiaryEntry> entriesById;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<String> onDayTap;
  final String? selectedId;
  final bool compact;

  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // semana empieza el lunes
    final now = today();
    final isCurrentMonth = first.year == now.year && first.month == now.month;
    final cellHeight = compact ? 40.0 : 52.0;
    final count = entriesById.keys.where((id) => id.startsWith(dayIdOf(first).substring(0, 7))).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMonthChanged(DateTime(first.year, first.month - 1)),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(monthTitle(first), style: theme.textTheme.titleSmall),
                  Text(
                    count == 0 ? 'Sin entradas' : (count == 1 ? '1 día escrito' : '$count días escritos'),
                    style: theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrentMonth ? null : () => onMonthChanged(DateTime(first.year, first.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(w, style: theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0; week * 7 < leading + daysInMonth; week++)
          Row(
            children: [
              for (var wd = 0; wd < 7; wd++)
                Expanded(
                  child: SizedBox(
                    height: cellHeight,
                    child: _cell(context, week * 7 + wd - leading + 1, daysInMonth, first, now),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int daysInMonth, DateTime first, DateTime now) {
    if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = DateTime(first.year, first.month, day);
    final id = dayIdOf(date);
    final entry = entriesById[id];
    final mood = Mood.of(entry?.mood);
    final future = date.isAfter(now);
    final isToday = date == now;
    final selected = id == selectedId;

    final label = Text(
      '$day',
      style: theme.textTheme.labelMedium!.copyWith(
        color: future ? scheme.onSurface.withValues(alpha: 0.3) : (selected ? scheme.onPrimary : scheme.onSurface),
        fontWeight: isToday || selected ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    final Widget marker;
    if (entry == null) {
      marker = const SizedBox(height: 16);
    } else if (mood != null) {
      marker = Text(mood.emoji, style: TextStyle(fontSize: compact ? 13 : 16, height: 1));
    } else {
      marker = Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: selected ? scheme.onPrimary : scheme.primary, shape: BoxShape.circle),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: !future,
        label: '${longDayTitle(id)}${entry == null ? '' : ', con entrada'}',
        excludeSemantics: true,
        child: Material(
          color: selected ? scheme.primary : (entry != null ? scheme.surfaceContainerHigh : Colors.transparent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isToday && !selected ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: future ? null : () => onDayTap(id),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [label, if (!compact || entry != null) marker],
            ),
          ),
        ),
      ),
    );
  }
}
