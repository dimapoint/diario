import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/day_id.dart';
import '../../models/entry.dart';
import '../../providers.dart';
import '../common/formatting.dart';
import '../navigation.dart';
import '../theme.dart';
import 'chip_section.dart';
import 'day_editor_controller.dart';
import 'day_items.dart';
import 'focus_mode_page.dart';
import 'mood_picker.dart';
import 'save_status_label.dart';
import 'song_tile.dart';

/// El editor de un día: la pantalla principal de la app.
class DayPage extends ConsumerStatefulWidget {
  const DayPage({super.key, required this.dayId});

  final String dayId;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  final _text = TextEditingController();
  final _highlight = TextEditingController();
  final _textFocus = FocusNode();
  final _highlightFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  String get _id => widget.dayId;
  DayEditorController get _editor => ref.read(dayEditorProvider(_id).notifier);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(dayEditorProvider(_id));
    if (initial.loaded) _syncFields(initial.entry);
    _text.addListener(() => _editor.setFreeText(_text.text));
    _highlight.addListener(() => _editor.setHighlight(_highlight.text));
    void flushOnBlur(FocusNode node) => node.addListener(() {
      if (!node.hasFocus) _editor.flush();
    });
    flushOnBlur(_textFocus);
    flushOnBlur(_highlightFocus);
    _lifecycle = AppLifecycleListener(onInactive: () => _editor.flush(), onHide: () => _editor.flush());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _text.dispose();
    _highlight.dispose();
    _textFocus.dispose();
    _highlightFocus.dispose();
    super.dispose();
  }

  /// Copia a los campos de texto lo que llegó del almacenamiento.
  void _syncFields(DiaryEntry entry) {
    void sync(TextEditingController c, String value) {
      if (c.text == value) return;
      final offset = c.selection.baseOffset.clamp(0, value.length);
      c.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: offset),
      );
    }

    sync(_text, entry.freeText);
    sync(_highlight, entry.highlight ?? '');
  }

  void _goToDay(String id) {
    if (isFutureDayId(id)) return;
    _editor.flush();
    goToDay(context, id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDayId(_id),
      firstDate: DateTime(2000),
      lastDate: today(),
      helpText: 'Ir a un día',
    );
    if (picked != null) _goToDay(dayIdOf(picked));
  }

  void _openFocusMode() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FocusModePage(dayId: _id, controller: _text),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar este día?'),
        content: const Text('Se borra todo lo que cargaste en este día, en todos tus dispositivos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok ?? false) {
      _editor.clearDay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Día borrado')));
      }
    }
  }

  void _showUndo(String message, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Deshacer', onPressed: undo),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dayEditorProvider(_id), (prev, next) {
      if (prev?.remoteRevision != next.remoteRevision) _syncFields(next.entry);
    });
    final state = ref.watch(dayEditorProvider(_id));
    final wide = isWide(context);
    final canGoNext = !isFutureDayId(shiftDayId(_id, 1));

    final body = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () => _goToDay(shiftDayId(_id, -1)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () => _goToDay(shiftDayId(_id, 1)),
      },
      // Sin un nodo con foco dentro del día, los atajos no reciben las
      // teclas hasta que tocás un campo.
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          // Swipe horizontal para cambiar de día en el celular.
          onHorizontalDragEnd: wide
              ? null
              : (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v > 500) _goToDay(shiftDayId(_id, -1));
                  if (v < -500 && canGoNext) _goToDay(shiftDayId(_id, 1));
                },
          child: _DayForm(
            dayId: _id,
            state: state,
            wide: wide,
            text: _text,
            highlight: _highlight,
            textFocus: _textFocus,
            highlightFocus: _highlightFocus,
            onFocusMode: _openFocusMode,
            onUndo: _showUndo,
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 4,
        toolbarHeight: 64,
        title: Row(
          children: [
            IconButton(
              tooltip: 'Día anterior (Alt+←)',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _goToDay(shiftDayId(_id, -1)),
            ),
            Expanded(
              child: _DayHeader(dayId: _id, status: state.status, onTap: _pickDate),
            ),
            IconButton(
              tooltip: 'Día siguiente (Alt+→)',
              icon: const Icon(Icons.chevron_right),
              onPressed: canGoNext ? () => _goToDay(shiftDayId(_id, 1)) : null,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) => switch (value) {
              'today' => _goToDay(todayId()),
              'focus' => _openFocusMode(),
              'settings' => context.push(Routes.settings),
              'delete' => _confirmDelete(),
              _ => null,
            },
            itemBuilder: (_) => [
              if (_id != todayId())
                const PopupMenuItem(
                  value: 'today',
                  child: ListTile(leading: Icon(Icons.today), title: Text('Ir a hoy')),
                ),
              const PopupMenuItem(
                value: 'focus',
                child: ListTile(leading: Icon(Icons.open_in_full), title: Text('Modo foco')),
              ),
              if (!wide)
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Ajustes')),
                ),
              PopupMenuItem(
                value: 'delete',
                enabled: !state.entry.isEmpty,
                child: const ListTile(leading: Icon(Icons.delete_outline), title: Text('Borrar este día')),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: state.loaded
            ? null
            : const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)),
      ),
      body: body,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dayId, required this.status, required this.onTap});

  final String dayId;
  final SaveStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relative = relativeDayLabel(dayId);
    return Semantics(
      button: true,
      label: 'Cambiar de día',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(longDayTitle(dayId), style: theme.textTheme.titleMedium, maxLines: 1),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (relative != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        relative,
                        style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                    if (status != SaveStatus.empty) const SizedBox(width: 8),
                  ],
                  Flexible(child: SaveStatusLabel(status: status)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayForm extends ConsumerWidget {
  const _DayForm({
    required this.dayId,
    required this.state,
    required this.wide,
    required this.text,
    required this.highlight,
    required this.textFocus,
    required this.highlightFocus,
    required this.onFocusMode,
    required this.onUndo,
  });

  final String dayId;
  final DayEditorState state;
  final bool wide;
  final TextEditingController text;
  final TextEditingController highlight;
  final FocusNode textFocus;
  final FocusNode highlightFocus;
  final VoidCallback onFocusMode;
  final void Function(String message, VoidCallback undo) onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = state.entry;
    final editor = ref.read(dayEditorProvider(dayId).notifier);
    final enabled = state.loaded;

    Widget section(DayItems items) {
      final labels = items.labels(entry);
      return ChipSection(
        icon: items.icon,
        title: items.title,
        addLabel: items.addLabel,
        onAdd: () => showAddItemsSheet(context, dayId: dayId, items: items),
        inlineInput: wide
            ? InlineAddField(
                hint: items == DayItems.tags ? 'Agregar etiqueta' : 'Agregar…',
                optionsFor: (q) => items.suggestionsFor(ref.read(suggestionsProvider), state.entry, q, limit: 8),
                onAdd: (t) => items.add(editor, t),
              )
            : null,
        chips: [
          for (final (i, label) in labels.indexed)
            InputChip(
              avatar: items == DayItems.activities && entry.activities[i].kind != ActivityKind.manual
                  ? Text(entry.activities[i].kind.emoji)
                  : null,
              label: Text(items.chipLabel(label)),
              deleteButtonTooltipMessage: 'Quitar',
              onDeleted: () => onUndo('Quitaste “${items.chipLabel(label)}”', items.remove(editor, entry, i)),
            ),
        ],
      );
    }

    final words = RegExp(r'\S+').allMatches(entry.freeText).length;

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: 8).copyWith(bottom: 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.conflictText != null) ...[
                  _ConflictCard(dayId: dayId, theirs: state.conflictText!),
                  const SizedBox(height: 12),
                ],
                Text(
                  '¿Cómo estuvo el día?',
                  style: theme.textTheme.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: MoodPicker(value: entry.mood, onChanged: enabled ? editor.setMood : (_) {}),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: highlight,
                  focusNode: highlightFocus,
                  enabled: enabled,
                  maxLength: DiaryEntry.highlightMaxLength,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => textFocus.requestFocus(),
                  style: context.diaryHighlight,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                      currentLength > 110 ? Text('$currentLength/$maxLength') : null,
                  decoration: InputDecoration(
                    hintText: 'Lo más destacado, en una línea',
                    hintStyle: context.diaryHighlight.copyWith(
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    prefixIcon: Icon(Icons.star_outline_rounded, color: scheme.primary),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: text,
                  focusNode: textFocus,
                  enabled: enabled,
                  minLines: wide ? 9 : 7,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.diaryBody,
                  decoration: InputDecoration(
                    hintText: 'Escribí lo que quieras…',
                    hintStyle: context.diaryBody.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      words == 0 ? '' : (words == 1 ? '1 palabra' : '$words palabras'),
                      style: theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: enabled ? onFocusMode : null,
                      icon: const Icon(Icons.open_in_full, size: 18),
                      label: const Text('Modo foco'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                section(DayItems.activities),
                const SizedBox(height: 24),
                const SectionTitle(icon: Icons.music_note_outlined, title: 'Canción pegada'),
                const SizedBox(height: 8),
                SongTile(song: entry.songOfDay, onChanged: editor.setSongOfDay),
                const SizedBox(height: 24),
                section(DayItems.listened),
                const SizedBox(height: 24),
                section(DayItems.tags),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.dayId, required this.theirs});

  final String dayId;
  final String theirs;

  Future<void> _show(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<ConflictChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Versión del otro dispositivo'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: SelectableText(theirs, style: context.diaryBody)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictChoice.keepMine),
            child: const Text('Quedarme con la mía'),
          ),
          TextButton(onPressed: () => Navigator.pop(context, ConflictChoice.combine), child: const Text('Combinar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ConflictChoice.useTheirs),
            child: const Text('Usar esta'),
          ),
        ],
      ),
    );
    if (choice != null) ref.read(dayEditorProvider(dayId).notifier).resolveConflict(choice);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem, color: scheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Este día cambió en otro dispositivo mientras escribías.',
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _show(context, ref), child: const Text('Ver la otra versión')),
            ),
          ],
        ),
      ),
    );
  }
}
