import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/export.dart';
import '../../providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final entries = ref.read(entriesProvider).value ?? const [];
    try {
      final saved = await saveExport(entries);
      if (saved) {
        messenger.showSnackBar(SnackBar(content: Text('Exportaste ${entries.length} días')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tus entradas quedan guardadas en tu cuenta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok ?? false) await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;
    final mode = ref.watch(appModeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final count = ref.watch(entriesProvider).value?.length;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(text, style: theme.textTheme.titleSmall!.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            children: [
              header('Cuenta'),
              ListTile(
                leading: CircleAvatar(child: Text(user?.initial ?? '?')),
                title: Text(user?.name ?? 'Sin nombre'),
                subtitle: Text(mode.demo ? 'Modo demo · los cambios no se guardan' : (user?.email ?? '')),
              ),
              if (!mode.demo)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesión'),
                  onTap: () => _signOut(context, ref),
                ),
              header('Apariencia'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                ),
              ),
              header('Datos'),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Exportar todo (JSON)'),
                subtitle: Text(count == null ? 'Backup de todas tus entradas' : 'Backup de tus $count días'),
                onTap: () => _export(context, ref),
              ),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.upload_outlined),
                title: Text('Importar'),
                subtitle: Text('Próximamente: Letterboxd, Serializd y más'),
              ),
              header('Acerca de'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Diario'),
                subtitle: const Text('Licencias y créditos'),
                onTap: () => showLicensePage(context: context, applicationName: 'Diario'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
