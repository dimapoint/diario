import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/song.dart';
import '../../providers.dart';
import '../theme.dart';

/// "Canción pegada": la canción que te quedó sonando en la cabeza.
class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.song, required this.onChanged});

  final Song? song;
  final ValueChanged<Song?> onChanged;

  Future<void> _edit(BuildContext context) async {
    final result = await showSongSheet(context, initial: song);
    if (result != null) onChanged(result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final song = this.song;
    if (song == null) {
      return Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Icon(Icons.music_note_outlined, color: scheme.onSurfaceVariant),
          title: Text(
            '¿Qué canción tuviste pegada?',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          onTap: () => _edit(context),
        ),
      );
    }
    final url = song.url;
    return Material(
      color: scheme.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: const Icon(Icons.music_note),
        ),
        title: Text(song.title, style: context.diaryHighlight, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: song.artist == null ? null : Text(song.artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _edit(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url != null)
              IconButton(
                tooltip: 'Abrir link',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => launchUrl(Uri.parse(_withScheme(url))),
              ),
            IconButton(
              tooltip: 'Quitar canción',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
          ],
        ),
      ),
    );
  }
}

String _withScheme(String url) => url.contains('://') ? url : 'https://$url';

/// Devuelve la canción editada, una vacía si se quitó, o null si se canceló.
Future<Song?> showSongSheet(BuildContext context, {Song? initial}) => showModalBottomSheet<Song>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SongSheet(initial: initial),
    );

class _SongSheet extends ConsumerStatefulWidget {
  const _SongSheet({this.initial});

  final Song? initial;

  @override
  ConsumerState<_SongSheet> createState() => _SongSheetState();
}

class _SongSheetState extends ConsumerState<_SongSheet> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _artist = TextEditingController(text: widget.initial?.artist);
  late final _url = TextEditingController(text: widget.initial?.url);

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    var title = _title.text.trim();
    var artist = _artist.text.trim();
    // Si pegaste "Título – Artista" en el título, separarlo.
    if (artist.isEmpty) {
      final parsed = Song.parse(title);
      title = parsed.title;
      artist = parsed.artist ?? '';
    }
    final url = _url.text.trim();
    Navigator.pop(
      context,
      Song(title: title, artist: artist.isEmpty ? null : artist, url: url.isEmpty ? null : url),
    );
  }

  void _fill(Song s) {
    _title.text = s.title;
    _artist.text = s.artist ?? '';
    _url.text = s.url ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = ref.watch(suggestionsProvider).songs.take(8).toList();
    InputDecoration deco(String label, {String? hint, IconData? icon}) => InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );

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
                Icon(Icons.music_note, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Canción pegada', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.initial == null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: deco('Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artist,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: deco('Artista (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: deco('Link (opcional)', hint: 'Spotify, YouTube…', icon: Icons.link),
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Recientes',
                style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in recent)
                    ActionChip(
                      avatar: const Icon(Icons.music_note, size: 16),
                      label: Text(s.label),
                      onPressed: () => _fill(s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.initial != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, const Song(title: '')),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar'),
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Guardar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
