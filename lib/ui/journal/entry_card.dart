import 'package:flutter/material.dart';

import '../../data/text_search.dart';
import '../../models/entry.dart';
import '../../models/mood.dart';
import '../common/formatting.dart';
import '../navigation.dart';
import '../theme.dart';

/// Resumen de un día para el historial y la búsqueda.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, this.selected = false, this.query = ''});

  final DiaryEntry entry;
  final bool selected;

  /// Término buscado, para mostrar el fragmento que coincide resaltado.
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = entry.date;
    final mood = Mood.of(entry.mood);
    final preview = _preview(context);

    final meta = <Widget>[
      if (entry.songOfDay != null) _Meta(icon: Icons.music_note, text: entry.songOfDay!.title),
      if (entry.activities.isNotEmpty) _Meta(icon: Icons.check, text: '${entry.activities.length}'),
      for (final t in entry.tags.take(3)) _Meta(text: '#$t'),
      if (entry.tags.length > 3) _Meta(text: '+${entry.tags.length - 3}'),
    ];

    return Card(
      color: selected ? scheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => goToDay(context, entry.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Text('${date.day}', style: theme.textTheme.headlineSmall!.copyWith(height: 1.1)),
                    Text(
                      weekdayShort(date),
                      style: theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (mood != null) ...[
                      const SizedBox(height: 6),
                      Text(mood.emoji, style: const TextStyle(fontSize: 20), semanticsLabel: mood.label),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 4, children: meta),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyStyle = context.diaryBody.copyWith(fontSize: 15, height: 1.4, color: scheme.onSurface);
    final highlightStyle = context.diaryHighlight.copyWith(fontSize: 16);

    if (query.trim().isNotEmpty) {
      for (final text in searchableTexts(entry)) {
        final snippet = snippetFor(text, query);
        if (snippet != null) {
          return Text.rich(
            _highlightSpans(snippet.text, snippet.matches, bodyStyle, scheme),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          );
        }
      }
    }

    final highlight = entry.highlight?.trim();
    final text = entry.freeText.trim();
    final children = <Widget>[
      if (highlight != null && highlight.isNotEmpty)
        Text(highlight, style: highlightStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (text.isNotEmpty)
        Text(
          text.replaceAll(RegExp(r'\s*\n\s*'), ' '),
          style: bodyStyle.copyWith(color: scheme.onSurfaceVariant),
          maxLines: highlight == null ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
    ];
    if (children.isEmpty) {
      final fallback = [
        ...entry.activities.map((a) => a.text),
        ...entry.listened.map((s) => s.label),
      ].join(' · ');
      children.add(Text(
        fallback.isEmpty ? 'Sin texto' : fallback,
        style: bodyStyle.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: children);
  }

  static TextSpan _highlightSpans(String text, List<(int, int)> matches, TextStyle style, ColorScheme scheme) {
    final spans = <TextSpan>[];
    var i = 0;
    for (final (start, end) in matches) {
      if (start > i) spans.add(TextSpan(text: text.substring(i, start)));
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: TextStyle(
          backgroundColor: scheme.tertiaryContainer,
          color: scheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ));
      i = end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return TextSpan(style: style, children: spans);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: scheme.primary), const SizedBox(width: 3)],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
