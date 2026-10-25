import 'package:flutter/material.dart';

import '../../models/mood.dart';

class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final mood in Mood.all)
          Expanded(
            child: _MoodButton(
              mood: mood,
              selected: value == mood.value,
              dimmed: value != null && value != mood.value,
              onTap: () => onChanged(value == mood.value ? null : mood.value),
              scheme: scheme,
            ),
          ),
      ],
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.mood,
    required this.selected,
    required this.dimmed,
    required this.onTap,
    required this.scheme,
  });

  final Mood mood;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ánimo ${mood.value} de 5: ${mood.label}',
      excludeSemantics: true,
      child: Tooltip(
        message: mood.label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? scheme.primaryContainer : Colors.transparent,
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: dimmed ? 0.45 : 1,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: selected ? 1.12 : 1,
                      child: Text(mood.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Reserva el lugar del texto para que nada salte al elegir.
                Text(selected ? mood.label : ' ', style: labelStyle, maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
