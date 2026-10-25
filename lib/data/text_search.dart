import '../models/entry.dart';

const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Minúsculas y sin tildes. Conserva la longitud del texto (cada letra se
/// reemplaza por una sola), así los índices sirven para resaltar en el
/// texto original.
String normalizeForSearch(String s) {
  final lower = s.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString();
}

class SearchQuery {
  const SearchQuery({this.text = '', this.tags = const {}, this.moods = const {}, this.withSong = false});

  final String text;
  final Set<String> tags;
  final Set<int> moods;
  final bool withSong;

  bool get isEmpty => text.trim().isEmpty && tags.isEmpty && moods.isEmpty && !withSong;

  SearchQuery copyWith({String? text, Set<String>? tags, Set<int>? moods, bool? withSong}) => SearchQuery(
        text: text ?? this.text,
        tags: tags ?? this.tags,
        moods: moods ?? this.moods,
        withSong: withSong ?? this.withSong,
      );
}

/// Todo el texto buscable de un día.
Iterable<String> searchableTexts(DiaryEntry e) sync* {
  yield e.freeText;
  if (e.highlight != null) yield e.highlight!;
  for (final a in e.activities) {
    yield a.text;
  }
  if (e.songOfDay != null) yield e.songOfDay!.label;
  for (final s in e.listened) {
    yield s.label;
  }
  for (final t in e.tags) {
    yield t;
  }
}

bool matchesQuery(DiaryEntry e, SearchQuery q) {
  if (q.withSong && e.songOfDay == null && e.listened.isEmpty) return false;
  if (q.moods.isNotEmpty && !q.moods.contains(e.mood)) return false;
  if (q.tags.isNotEmpty) {
    final tags = {for (final t in e.tags) normalizeForSearch(t)};
    if (!q.tags.every((t) => tags.contains(normalizeForSearch(t)))) return false;
  }
  final term = normalizeForSearch(q.text.trim());
  if (term.isEmpty) return true;
  return searchableTexts(e).any((t) => normalizeForSearch(t).contains(term));
}

List<DiaryEntry> search(List<DiaryEntry> entries, SearchQuery q) =>
    q.isEmpty ? const [] : entries.where((e) => matchesQuery(e, q)).toList();

/// Un fragmento de [text] alrededor de la primera aparición de [term], con
/// los rangos a resaltar. null si no aparece.
({String text, List<(int, int)> matches})? snippetFor(String text, String term, {int radius = 60}) {
  final t = normalizeForSearch(term.trim());
  if (t.isEmpty) return null;
  final normalized = normalizeForSearch(text);
  // Algunas letras raras cambian de largo al pasar a minúscula.
  if (normalized.length != text.length) return null;
  final first = normalized.indexOf(t);
  if (first < 0) return null;
  var start = (first - radius).clamp(0, text.length);
  var end = (first + t.length + radius).clamp(0, text.length);
  // Cortar en espacios para no partir palabras.
  if (start > 0) {
    final space = text.indexOf(' ', start);
    if (space >= 0 && space < first) start = space + 1;
  }
  if (end < text.length) {
    final space = text.lastIndexOf(' ', end);
    if (space > first + t.length) end = space;
  }
  final prefix = start > 0 ? '…' : '';
  final suffix = end < text.length ? '…' : '';
  final slice = text.substring(start, end).replaceAll('\n', ' ');
  final normalizedSlice = normalized.substring(start, end);
  final matches = <(int, int)>[];
  var i = normalizedSlice.indexOf(t);
  while (i >= 0) {
    matches.add((prefix.length + i, prefix.length + i + t.length));
    i = normalizedSlice.indexOf(t, i + t.length);
  }
  return (text: '$prefix$slice$suffix', matches: matches);
}
