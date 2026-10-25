import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../navigation.dart';
import '../theme.dart';
import 'side_panel.dart';

/// Celular: barra de navegación inferior (Hoy · Diario · Buscar).
/// Pantalla ancha: panel lateral con historial y buscador + el día a la derecha.
class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key, required this.location, required this.selectedDayId, required this.child});

  final String location;
  final String selectedDayId;
  final Widget child;

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  int get _tabIndex => switch (widget.location) {
        Routes.journal => 1,
        Routes.search => 2,
        _ => 0,
      };

  void _focusSearch(bool wide) {
    if (wide) {
      _searchFocus.requestFocus();
    } else {
      context.go(Routes.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final mode = ref.watch(appModeProvider);

    final Widget content;
    if (wide) {
      content = Row(
        children: [
          SizedBox(
            width: 380,
            child: SidePanel(selectedId: widget.selectedDayId, searchFocus: _searchFocus),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      );
    } else {
      content = Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => context.go(switch (i) {
            1 => Routes.journal,
            2 => Routes.search,
            _ => Routes.today,
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Hoy'),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: 'Diario',
            ),
            NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _focusSearch(wide),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _focusSearch(wide),
      },
      child: mode.demo ? _WithDemoBanner(reason: mode.demoReason, child: content) : content,
    );
  }
}

class _WithDemoBanner extends StatelessWidget {
  const _WithDemoBanner({required this.child, this.reason});

  final Widget child;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.tertiaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, size: 16, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modo demo: los cambios no se guardan.${reason == null ? '' : ' $reason'}',
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(color: scheme.onTertiaryContainer),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
      ],
    );
  }
}
