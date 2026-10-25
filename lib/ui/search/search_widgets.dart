import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/text_search.dart';
import '../../models/mood.dart';
import '../../providers.dart';

/// La búsqueda actual, compartida entre la pantalla Buscar y el panel lateral.
final searchQueryProvider = NotifierProvider<SearchQueryController, SearchQuery>(SearchQueryController.new);

class SearchQueryController extends Notifier<SearchQuery> {
  @override
  SearchQuery build() => const SearchQuery();

  void setText(String text) => state = state.copyWith(text: text);

  void toggleTag(String tag) {
    final tags = {...state.tags};
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(tags: tags);
  }

  void toggleMood(int mood) {
    final moods = {...state.moods};
    if (!moods.remove(mood)) moods.add(mood);
    state = state.copyWith(moods: moods);
  }

  void toggleWithSong() => state = state.copyWith(withSong: !state.withSong);

  void clear() => state = const SearchQuery();
}

final searchResultsProvider = Provider((ref) {
  final entries = ref.watch(entriesProvider).value ?? const [];
  return search(entries, ref.watch(searchQueryProvider));
});

class SearchField extends ConsumerStatefulWidget {
  const SearchField({super.key, this.focusNode, this.autofocus = false, this.hint = 'Buscar en tu diario'});

  final FocusNode? focusNode;
  final bool autofocus;
  final String hint;

  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  late final _controller = TextEditingController(text: ref.read(searchQueryProvider).text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchQueryProvider.select((q) => q.text), (_, text) {
      if (_controller.text != text) _controller.text = text;
    });
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: ref.read(searchQueryProvider.notifier).setText,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(searchQueryProvider.notifier).setText(''),
                ),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      ),
    );
  }
}

/// Filtros por ánimo, música y etiquetas.
class SearchFilters extends ConsumerWidget {
  const SearchFilters({super.key, this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchQueryProvider);
    final notifier = ref.read(searchQueryProvider.notifier);
    final tags = {...q.tags, ...ref.watch(suggestionsProvider).tags.take(20)}.toList();

    Widget row(List<Widget> children) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: Row(spacing: 8, children: children),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        row([
          for (final m in Mood.all)
            FilterChip(
              // Ancho fijo: el chip se mide antes de que cargue la fuente de
              // emojis en web y el emoji quedaba recortado.
              label: SizedBox(
                width: 22,
                child: Text(m.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              ),
              tooltip: m.label,
              selected: q.moods.contains(m.value),
              showCheckmark: false,
              onSelected: (_) => notifier.toggleMood(m.value),
            ),
          FilterChip(
            avatar: const Icon(Icons.music_note, size: 16),
            label: const Text('Con música'),
            selected: q.withSong,
            onSelected: (_) => notifier.toggleWithSong(),
          ),
        ]),
        if (tags.isNotEmpty)
          row([
            for (final t in tags)
              FilterChip(
                label: Text('#$t'),
                selected: q.tags.contains(t),
                onSelected: (_) => notifier.toggleTag(t),
              ),
          ]),
      ],
    );
  }
}
