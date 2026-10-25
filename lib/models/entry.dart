import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'activity.dart';
import 'day_id.dart';
import 'song.dart';

/// Nombres de los campos editables de un día, tal como se guardan.
abstract final class EntryField {
  static const freeText = 'freeText';
  static const mood = 'mood';
  static const highlight = 'highlight';
  static const activities = 'activities';
  static const tags = 'tags';
  static const songOfDay = 'songOfDay';
  static const listened = 'listened';

  static const all = [freeText, mood, highlight, activities, tags, songOfDay, listened];
}

const _unset = Object();
const _deepEquality = DeepCollectionEquality();

/// La entrada de un día. Hay una sola por fecha y su id es `yyyy-MM-dd`.
@immutable
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    this.freeText = '',
    this.mood,
    this.highlight,
    this.activities = const [],
    this.tags = const [],
    this.songOfDay,
    this.listened = const [],
    this.createdAt,
    this.updatedAt,
  });

  static const schemaVersion = 1;
  static const highlightMaxLength = 140;

  final String id;
  final String freeText;
  final int? mood;
  final String? highlight;
  final List<Activity> activities;
  final List<String> tags;
  final Song? songOfDay;
  final List<Song> listened;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DateTime get date => parseDayId(id);

  bool get isEmpty =>
      freeText.trim().isEmpty &&
      mood == null &&
      (highlight?.trim().isEmpty ?? true) &&
      activities.isEmpty &&
      tags.isEmpty &&
      songOfDay == null &&
      listened.isEmpty;

  DiaryEntry copyWith({
    String? freeText,
    Object? mood = _unset,
    Object? highlight = _unset,
    List<Activity>? activities,
    List<String>? tags,
    Object? songOfDay = _unset,
    List<Song>? listened,
  }) =>
      DiaryEntry(
        id: id,
        freeText: freeText ?? this.freeText,
        mood: identical(mood, _unset) ? this.mood : mood as int?,
        highlight: identical(highlight, _unset) ? this.highlight : highlight as String?,
        activities: activities ?? this.activities,
        tags: tags ?? this.tags,
        songOfDay: identical(songOfDay, _unset) ? this.songOfDay : songOfDay as Song?,
        listened: listened ?? this.listened,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Los campos editables serializados. Es lo que se escribe en Firestore
  /// (junto con `date`, `schemaVersion` y los timestamps) y lo que se compara
  /// campo por campo para detectar cambios.
  Map<String, Object?> toFields() => {
        EntryField.freeText: freeText,
        EntryField.mood: mood,
        EntryField.highlight: (highlight?.trim().isEmpty ?? true) ? null : highlight,
        EntryField.activities: [for (final a in activities) a.toMap()],
        EntryField.tags: tags,
        EntryField.songOfDay: songOfDay?.toMap(),
        EntryField.listened: [for (final s in listened) s.toMap()],
      };

  factory DiaryEntry.fromFields(
    String id,
    Map<String, Object?> data, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    List<Map<String, Object?>> maps(Object? v) => [
          for (final m in (v as List?) ?? const []) Map<String, Object?>.from(m as Map),
        ];
    final song = data[EntryField.songOfDay];
    final mood = (data[EntryField.mood] as num?)?.toInt();
    return DiaryEntry(
      id: id,
      freeText: (data[EntryField.freeText] as String?) ?? '',
      mood: (mood != null && mood >= 1 && mood <= 5) ? mood : null,
      highlight: data[EntryField.highlight] as String?,
      activities: [for (final m in maps(data[EntryField.activities])) Activity.fromMap(m)],
      tags: [for (final t in (data[EntryField.tags] as List?) ?? const []) t as String],
      songOfDay: song == null ? null : Song.fromMap(Map<String, Object?>.from(song as Map)),
      listened: [for (final m in maps(data[EntryField.listened])) Song.fromMap(m)],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Formato del export/backup JSON.
  Map<String, Object?> toJson() => {
        'date': id,
        ...toFields(),
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  factory DiaryEntry.fromJson(Map<String, Object?> json) => DiaryEntry.fromFields(
        json['date'] as String,
        json,
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? ''),
      );

  /// Los campos (por nombre) cuyo valor difiere entre [a] y [b].
  static Set<String> changedFields(Map<String, Object?> a, Map<String, Object?> b) => {
        for (final f in EntryField.all)
          if (!fieldEquals(a[f], b[f])) f,
      };

  static bool fieldEquals(Object? a, Object? b) => _deepEquality.equals(a, b);

  @override
  bool operator ==(Object other) =>
      other is DiaryEntry && other.id == id && _deepEquality.equals(other.toFields(), toFields());

  @override
  int get hashCode => Object.hash(id, _deepEquality.hash(toFields()));

  @override
  String toString() => 'DiaryEntry($id)';
}
