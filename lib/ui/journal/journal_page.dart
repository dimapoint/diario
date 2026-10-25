import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/day_id.dart';
import '../../models/entry.dart';
import '../../providers.dart';
import '../common/user_avatar.dart';
import '../navigation.dart';
import 'entry_slivers.dart';
import 'month_calendar.dart';

enum JournalView { list, calendar }

final journalViewProvider = NotifierProvider<JournalViewController, JournalView>(JournalViewController.new);

class JournalViewController extends Notifier<JournalView> {
  @override
  JournalView build() => JournalView.list;

  void set(JournalView view) => state = view;
}

/// Historial de días (celular): lista agrupada por mes o calendario.
class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  DateTime _month = today();

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(journalViewProvider);
    final entries = ref.watch(entriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diario'),
        actions: [
          SegmentedButton<JournalView>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: JournalView.list, label: Text('Lista')),
              ButtonSegment(value: JournalView.calendar, label: Text('Calendario')),
            ],
            selected: {view},
            onSelectionChanged: (s) => ref.read(journalViewProvider.notifier).set(s.first),
          ),
          const UserAvatarButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'No se pudo cargar el diario', message: '$e'),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'Todavía no escribiste nada.',
              message: 'Empezá por hoy: con elegir cómo estuvo el día alcanza.',
              action: FilledButton.icon(
                onPressed: () => goToDay(context, todayId()),
                icon: const Icon(Icons.edit_note),
                label: const Text('Escribir hoy'),
              ),
            );
          }
          return switch (view) {
            JournalView.list => CustomScrollView(
                slivers: [...entrySlivers(entries), const SliverPadding(padding: EdgeInsets.only(bottom: 24))],
              ),
            JournalView.calendar => _CalendarView(
                entries: entries,
                month: _month,
                onMonthChanged: (m) => setState(() => _month = m),
              ),
          };
        },
      ),
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({required this.entries, required this.month, required this.onMonthChanged});

  final List<DiaryEntry> entries;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final prefix = dayIdOf(month).substring(0, 7);
    final ofMonth = entries.where((e) => e.id.startsWith(prefix)).toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          sliver: SliverToBoxAdapter(
            child: MonthCalendar(
              month: month,
              entriesById: {for (final e in entries) e.id: e},
              onMonthChanged: onMonthChanged,
              onDayTap: (id) => goToDay(context, id),
            ),
          ),
        ),
        ...entrySlivers(ofMonth),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}
