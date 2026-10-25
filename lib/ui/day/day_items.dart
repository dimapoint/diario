import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/suggestions.dart';
import '../../models/entry.dart';
import '../../providers.dart';
import 'day_editor_controller.dart';

/// Las listas de chips de un día: qué hice, música que escuchaste y
/// etiquetas. Centraliza textos, lectura, alta, baja y sugerencias de cada una.
enum DayItems {
  activities(
    title: 'Qué hice',
    icon: Icons.check_circle_outline,
    addLabel: 'Agregar',
    hint: 'Algo que hiciste hoy',
  ),
  listened(
    title: 'Escuché',
    icon: Icons.headphones_outlined,
    addLabel: 'Agregar',
    hint: 'Artista, álbum o Título – Artista',
  ),
  tags(
    title: 'Etiquetas',
    icon: Icons.tag,
    addLabel: 'Etiqueta',
    hint: 'trabajo, familia, viaje…',
  );

  const DayItems({required this.title, required this.icon, required this.addLabel, required this.hint});

  final String title;
  final IconData icon;
  final String addLabel;
  final String hint;

  List<String> labels(DiaryEntry e) => switch (this) {
        activities => [for (final a in e.activities) a.text],
        listened => [for (final s in e.listened) s.label],
        tags => e.tags,
      };

  String chipLabel(String label) => this == tags ? '#$label' : label;

  void add(DayEditorController c, String text) => switch (this) {
        activities => c.addActivity(text),
        listened => c.addListened(text),
        tags => c.addTag(text),
      };

  /// Quita el ítem [index] y devuelve cómo deshacerlo.
  VoidCallback remove(DayEditorController c, DiaryEntry e, int index) {
    switch (this) {
      case activities:
        final a = e.activities[index];
        c.removeActivity(a.id);
        return () => c.insertActivity(index, a);
      case listened:
        final s = e.listened[index];
        c.removeListened(s);
        return () => c.insertListened(index, s);
      case tags:
        final t = e.tags[index];
        c.removeTag(t);
        return () => c.insertTag(index, t);
    }
  }

  List<String> suggestionPool(Suggestions s) => switch (this) {
        activities => s.activities,
        listened => [...s.listened, for (final song in s.songs) song.label],
        tags => s.tags,
      };

  List<String> suggestionsFor(Suggestions s, DiaryEntry e, String query, {int limit = 12}) =>
      Suggestions.filter(suggestionPool(s).toSet().toList(), query, exclude: labels(e), limit: limit);
}

/// Bottom sheet para cargar varios ítems seguidos: Enter agrega y deja el
/// teclado abierto; abajo hay sugerencias del historial a un toque.
Future<void> showAddItemsSheet(BuildContext context, {required String dayId, required DayItems items}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddItemsSheet(dayId: dayId, items: items),
  );
}

class _AddItemsSheet extends ConsumerStatefulWidget {
  const _AddItemsSheet({required this.dayId, required this.items});

  final String dayId;
  final DayItems items;

  @override
  ConsumerState<_AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends ConsumerState<_AddItemsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String text) {
    if (text.trim().isEmpty) return;
    widget.items.add(ref.read(dayEditorProvider(widget.dayId).notifier), text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final entry = ref.watch(dayEditorProvider(widget.dayId).select((s) => s.entry));
    final controller = ref.read(dayEditorProvider(widget.dayId).notifier);
    final suggestions = items.suggestionsFor(ref.watch(suggestionsProvider), entry, _controller.text);
    final current = items.labels(entry);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(items.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(items.title, style: theme.textTheme.titleLarge)),
                FilledButton.tonal(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textCapitalization: items == DayItems.tags ? TextCapitalization.none : TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              // Con onEditingComplete el teclado no se cierra al apretar Enter.
              onEditingComplete: () => _add(_controller.text),
              decoration: InputDecoration(
                hintText: items.hint,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  tooltip: 'Agregar',
                  icon: const Icon(Icons.add_circle),
                  color: theme.colorScheme.primary,
                  onPressed: () => _add(_controller.text),
                ),
              ),
            ),
            if (current.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, label) in current.indexed)
                    InputChip(
                      label: Text(items.chipLabel(label)),
                      onDeleted: () => items.remove(controller, entry, i),
                      deleteButtonTooltipMessage: 'Quitar',
                    ),
                ],
              ),
            ],
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _controller.text.isEmpty ? 'Frecuentes' : 'Sugerencias',
                style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in suggestions)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(items.chipLabel(s)),
                      onPressed: () => _add(s),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
