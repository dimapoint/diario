import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../journal/entry_slivers.dart';
import 'search_widgets.dart';

/// Buscar (celular).
class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const SearchField(autofocus: true),
        toolbarHeight: 68,
      ),
      body: Column(
        children: [
          const SearchFilters(),
          const SizedBox(height: 8),
          const Expanded(child: SearchResults()),
        ],
      ),
    );
  }
}

class SearchResults extends ConsumerWidget {
  const SearchResults({super.key, this.selectedId, this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  final String? selectedId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    if (q.isEmpty) {
      return const EmptyState(
        icon: Icons.manage_search,
        title: 'Buscá en tu diario',
        message: 'Texto, actividades, canciones o etiquetas. También podés filtrar por ánimo.',
      );
    }
    if (results.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'Sin resultados');
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              results.length == 1 ? '1 día' : '${results.length} días',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        ...entrySlivers(results, query: q.text, selectedId: selectedId, padding: padding),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}
