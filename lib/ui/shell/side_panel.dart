import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/day_id.dart';
import '../../providers.dart';
import '../common/user_avatar.dart';
import '../journal/entry_slivers.dart';
import '../journal/month_calendar.dart';
import '../navigation.dart';
import '../search/search_page.dart';
import '../search/search_widgets.dart';
import '../theme.dart';

/// Panel izquierdo en pantallas anchas: buscador, calendario del mes y
/// línea de tiempo.
class SidePanel extends ConsumerStatefulWidget {
  const SidePanel({super.key, required this.selectedId, required this.searchFocus});

  final String selectedId;
  final FocusNode searchFocus;

  @override
  ConsumerState<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<SidePanel> {
  late DateTime _month = parseDayId(widget.selectedId);
  bool _showFilters = false;

  @override
  void didUpdateWidget(SidePanel old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      final d = parseDayId(widget.selectedId);
      _month = DateTime(d.year, d.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);
    final entries = ref.watch(entriesProvider).value ?? const [];
    final searching = !query.isEmpty;
    final filtersActive = query.tags.isNotEmpty || query.moods.isNotEmpty || query.withSong;

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    'Diario',
                    style: theme.textTheme.headlineSmall!.copyWith(fontFamily: diaryFontFamily),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => goToDay(context, todayId()),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Hoy'),
                  ),
                  const UserAvatarButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(child: SearchField(focusNode: widget.searchFocus, hint: 'Buscar (Ctrl+K)')),
                  IconButton(
                    tooltip: 'Filtros',
                    isSelected: _showFilters || filtersActive,
                    icon: const Icon(Icons.tune),
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                  ),
                ],
              ),
            ),
            if (_showFilters || filtersActive) ...[
              const SearchFilters(),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: searching
                  ? SearchResults(selectedId: widget.selectedId)
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          sliver: SliverToBoxAdapter(
                            child: MonthCalendar(
                              compact: true,
                              month: _month,
                              selectedId: widget.selectedId,
                              entriesById: {for (final e in entries) e.id: e},
                              onMonthChanged: (m) => setState(() => _month = m),
                              onDayTap: (id) => goToDay(context, id),
                            ),
                          ),
                        ),
                        if (entries.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.auto_stories_outlined,
                              title: 'Todavía no escribiste nada.',
                              message: 'Empezá por hoy.',
                            ),
                          ),
                        ...entrySlivers(entries, selectedId: widget.selectedId),
                        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
