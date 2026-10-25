import 'package:flutter/foundation.dart';

/// Una canción, álbum o artista.
///
/// En "Escuché" se puede cargar solo un artista o un álbum: en ese caso queda
/// todo en [title] y [artist] es null.
@immutable
class Song {
  const Song({required this.title, this.artist, this.url});

  final String title;
  final String? artist;
  final String? url;

  static final _separator = RegExp(r'\s+[-–—]\s+');

  /// Interpreta `Título – Artista` (acepta guion, en dash o em dash).
  /// Sin separador, todo el texto queda como título.
  factory Song.parse(String input) {
    final text = input.trim();
    final match = _separator.firstMatch(text);
    if (match == null) return Song(title: text);
    final title = text.substring(0, match.start).trim();
    final artist = text.substring(match.end).trim();
    if (artist.isEmpty) return Song(title: title);
    if (title.isEmpty) return Song(title: artist);
    return Song(title: title, artist: artist);
  }

  String get label => artist == null ? title : '$title — $artist';

  bool get isEmpty => title.trim().isEmpty && (artist?.trim().isEmpty ?? true);

  Song copyWith({String? title, String? artist, String? url}) =>
      Song(title: title ?? this.title, artist: artist ?? this.artist, url: url ?? this.url);

  /// Siempre incluye todas las claves para que un merge en Firestore
  /// reemplace los valores anteriores.
  Map<String, Object?> toMap() => {'title': title, 'artist': artist, 'url': url};

  factory Song.fromMap(Map<String, Object?> map) => Song(
        title: (map['title'] as String?) ?? '',
        artist: _nonEmpty(map['artist'] as String?),
        url: _nonEmpty(map['url'] as String?),
      );

  static String? _nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  @override
  bool operator ==(Object other) =>
      other is Song && other.title == title && other.artist == artist && other.url == url;

  @override
  int get hashCode => Object.hash(title, artist, url);

  @override
  String toString() => 'Song($label)';
}
