import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum ActivityKind {
  manual(''),
  movie('🎬'),
  series('📺'),
  book('📚'),
  game('🎮'),
  music('🎵'),
  other('•');

  const ActivityKind(this.emoji);

  final String emoji;

  static ActivityKind fromName(String? name) =>
      ActivityKind.values.firstWhere((k) => k.name == name, orElse: () => ActivityKind.manual);
}

/// Algo que hiciste en el día.
///
/// Las cargadas a mano tienen `source: 'manual'`. Las que traiga un importador
/// (Letterboxd, Serializd, …) llevan su [source], un [externalId] para no
/// duplicarlas si se importa dos veces y el [importId] de la importación para
/// poder deshacerla entera.
@immutable
class Activity {
  const Activity({
    required this.id,
    required this.text,
    this.kind = ActivityKind.manual,
    this.source = manualSource,
    this.externalId,
    this.url,
    this.rating,
    this.importId,
  });

  factory Activity.manual(String text) => Activity(id: _uuid.v4(), text: text.trim());

  static const manualSource = 'manual';
  static const _uuid = Uuid();

  final String id;
  final String text;
  final ActivityKind kind;
  final String source;
  final String? externalId;
  final String? url;
  final double? rating;
  final String? importId;

  bool get isManual => source == manualSource;

  Map<String, Object?> toMap() => {
        'id': id,
        'text': text,
        'kind': kind.name,
        'source': source,
        if (externalId != null) 'externalId': externalId,
        if (url != null) 'url': url,
        if (rating != null) 'rating': rating,
        if (importId != null) 'importId': importId,
      };

  factory Activity.fromMap(Map<String, Object?> map) => Activity(
        id: (map['id'] as String?) ?? _uuid.v4(),
        text: (map['text'] as String?) ?? '',
        kind: ActivityKind.fromName(map['kind'] as String?),
        source: (map['source'] as String?) ?? manualSource,
        externalId: map['externalId'] as String?,
        url: map['url'] as String?,
        rating: (map['rating'] as num?)?.toDouble(),
        importId: map['importId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Activity &&
      other.id == id &&
      other.text == text &&
      other.kind == kind &&
      other.source == source &&
      other.externalId == externalId &&
      other.url == url &&
      other.rating == rating &&
      other.importId == importId;

  @override
  int get hashCode => Object.hash(id, text, kind, source, externalId, url, rating, importId);

  @override
  String toString() => 'Activity($text)';
}
