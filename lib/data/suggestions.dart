import '../models/entry.dart';
import '../models/song.dart';
import 'text_search.dart';

/// Sugerencias para cargar rápido a partir del historial: lo más frecuente
/// primero y, a igual frecuencia, lo más reciente.
class Suggestions {
  Suggestions._(this.activities, this.tags, this.listened, this.songs);

  static final empty = Suggestions._(const [], const [], const [], const []);

  /// [entries] debe venir de la más reciente a la más vieja.
  factory Suggestions.fromEntries(List<DiaryEntry> entries) {
    final activities = _Counter<String>();
    final tags = _Counter<String>();
    final listened = _Counter<String>();
    final songs = _Counter<Song>();
    for (final (i, e) in entries.indexed) {
      for (final a in e.activities) {
        if (a.isManual) activities.add(a.text, i);
      }
      for (final t in e.tags) {
        tags.add(t, i);
      }
      for (final s in e.listened) {
        listened.add(s.label, i);
      }
      final song = e.songOfDay;
      if (song != null) songs.add(Song(title: song.title, artist: song.artist, url: song.url), i);
    }
    return Suggestions._(activities.ranked(), tags.ranked(), listened.ranked(), songs.ranked());
  }

  final List<String> activities;
  final List<String> tags;
  final List<String> listened;
  final List<Song> songs;

  /// Filtra [options] por [query] (sin distinguir mayúsculas ni tildes) y
  /// saca lo que ya está cargado en [exclude].
  static List<String> filter(
    List<String> options,
    String query, {
    Iterable<String> exclude = const [],
    int limit = 12,
  }) {
    final q = normalizeForSearch(query.trim());
    final excluded = {for (final e in exclude) normalizeForSearch(e)};
    return options
        .where((o) => !excluded.contains(normalizeForSearch(o)))
        .where((o) => q.isEmpty || normalizeForSearch(o).contains(q))
        .take(limit)
        .toList();
  }
}

class _Counter<T> {
  final _count = <Object, int>{};
  final _firstSeen = <Object, int>{};
  final _value = <Object, T>{};

  void add(T value, int recency) {
    final key = value is String ? normalizeForSearch(value) : value as Object;
    _count[key] = (_count[key] ?? 0) + 1;
    // La primera vez que aparece es la más reciente: conserva esa grafía.
    _firstSeen.putIfAbsent(key, () => recency);
    _value.putIfAbsent(key, () => value);
  }

  List<T> ranked() {
    final keys = _count.keys.toList()
      ..sort((a, b) {
        final byCount = _count[b]!.compareTo(_count[a]!);
        return byCount != 0 ? byCount : _firstSeen[a]!.compareTo(_firstSeen[b]!);
      });
    return [for (final k in keys) _value[k] as T];
  }
}
