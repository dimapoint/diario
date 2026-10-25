import 'package:flutter/material.dart';

import '../../models/entry.dart';
import '../common/formatting.dart';
import 'entry_card.dart';

/// Las entradas agrupadas por mes, con el nombre del mes fijo arriba
/// mientras scrolleás ese mes.
List<Widget> entrySlivers(
  List<DiaryEntry> entries, {
  String? selectedId,
  String query = '',
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
}) {
  final groups = <String, List<DiaryEntry>>{};
  for (final e in entries) {
    groups.putIfAbsent(e.id.substring(0, 7), () => []).add(e);
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      SliverMainAxisGroup(
        key: ValueKey(key),
        slivers: [
          SliverPersistentHeader(pinned: true, delegate: _MonthHeader(DateTime.parse('$key-01'), padding)),
          SliverPadding(
            padding: padding.copyWith(bottom: 8),
            sliver: SliverList.separated(
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => EntryCard(
                key: ValueKey(value[i].id),
                entry: value[i],
                selected: value[i].id == selectedId,
                query: query,
              ),
            ),
          ),
        ],
      ),
  ];
}

class _MonthHeader extends SliverPersistentHeaderDelegate {
  _MonthHeader(this.month, this.padding);

  final DateTime month;
  final EdgeInsets padding;

  static const _height = 40.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: padding.left + 4),
      child: Text(
        monthTitle(month).toUpperCase(),
        style: theme.textTheme.labelLarge!.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeader old) => old.month != month || old.padding != padding;
}

/// Mensaje centrado para listas vacías.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
