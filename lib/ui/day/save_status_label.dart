import 'dart:async';

import 'package:flutter/material.dart';

import 'day_editor_controller.dart';

/// "Guardando…", "Guardado" o "Sin conexión · se sincroniza después".
///
/// Online, Firestore también reporta escrituras pendientes por unos
/// milisegundos hasta que el servidor confirma; por eso el aviso de "sin
/// conexión" aparece recién si eso dura más de unos segundos.
class SaveStatusLabel extends StatefulWidget {
  const SaveStatusLabel({super.key, required this.status});

  final SaveStatus status;

  @override
  State<SaveStatusLabel> createState() => _SaveStatusLabelState();
}

class _SaveStatusLabelState extends State<SaveStatusLabel> {
  static const offlineAfter = Duration(seconds: 3);
  Timer? _timer;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didUpdateWidget(SaveStatusLabel old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _track();
  }

  void _track() {
    _timer?.cancel();
    if (widget.status == SaveStatus.savedLocally) {
      _timer = Timer(offlineAfter, () => setState(() => _offline = true));
    } else {
      _offline = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData? icon, String text, Color color) = switch (widget.status) {
      SaveStatus.empty => (null, '', scheme.onSurfaceVariant),
      SaveStatus.pending => (Icons.edit_outlined, 'Guardando…', scheme.onSurfaceVariant),
      SaveStatus.savedLocally when _offline => (
          Icons.cloud_off_outlined,
          'Sin conexión · se sincroniza después',
          scheme.tertiary,
        ),
      SaveStatus.savedLocally || SaveStatus.synced => (Icons.check, 'Guardado', scheme.onSurfaceVariant),
      SaveStatus.error => (Icons.error_outline, 'No se pudo guardar', scheme.error),
    };
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(color: color);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Row(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Flexible(child: Text(text, style: style, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
