import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/formatting.dart';
import '../theme.dart';
import 'day_editor_controller.dart';
import 'save_status_label.dart';

/// El texto libre a pantalla completa, sin el resto de los campos.
///
/// Usa el mismo [TextEditingController] que la pantalla del día, así lo que
/// escribís acá se guarda igual.
class FocusModePage extends ConsumerWidget {
  const FocusModePage({super.key, required this.dayId, required this.controller});

  final String dayId;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dayEditorProvider(dayId).select((s) => s.status));
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context)},
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Salir del modo foco (Esc)',
            icon: const Icon(Icons.close_fullscreen),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(longDayTitle(dayId), style: Theme.of(context).textTheme.titleMedium),
              SaveStatusLabel(status: status),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  textAlignVertical: TextAlignVertical.top,
                  style: context.diaryBody.copyWith(fontSize: 19, height: 1.6),
                  decoration: const InputDecoration.collapsed(hintText: 'Escribí lo que quieras…'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
