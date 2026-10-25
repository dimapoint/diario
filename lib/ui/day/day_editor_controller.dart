import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entry_repository.dart';
import '../../models/activity.dart';
import '../../models/entry.dart';
import '../../models/song.dart';
import '../../providers.dart';

enum SaveStatus {
  /// Todavía no hay nada guardado para este día.
  empty,

  /// Hay cambios esperando el autosave.
  pending,

  /// Guardado en el dispositivo, falta sincronizar (por ejemplo, sin red).
  savedLocally,

  /// Guardado y sincronizado.
  synced,

  error,
}

enum ConflictChoice { keepMine, useTheirs, combine }

@immutable
class DayEditorState {
  const DayEditorState({
    required this.entry,
    this.loaded = false,
    this.status = SaveStatus.empty,
    this.conflictText,
    this.remoteRevision = 0,
  });

  final DiaryEntry entry;
  final bool loaded;
  final SaveStatus status;

  /// Texto libre que llegó de otro dispositivo mientras lo estabas editando.
  final String? conflictText;

  /// Aumenta cada vez que un cambio remoto modifica lo que se ve, para que la
  /// UI actualice los campos de texto.
  final int remoteRevision;

  DayEditorState copyWith({
    DiaryEntry? entry,
    bool? loaded,
    SaveStatus? status,
    Object? conflictText = _keep,
    int? remoteRevision,
  }) =>
      DayEditorState(
        entry: entry ?? this.entry,
        loaded: loaded ?? this.loaded,
        status: status ?? this.status,
        conflictText: identical(conflictText, _keep) ? this.conflictText : conflictText as String?,
        remoteRevision: remoteRevision ?? this.remoteRevision,
      );
}

const _keep = Object();

final dayEditorProvider =
    NotifierProvider.autoDispose.family<DayEditorController, DayEditorState, String>(DayEditorController.new);

/// Estado local de un día con autosave y merge por campo de los cambios
/// remotos.
///
/// - Un campo que cambió en otro dispositivo y que acá no tocaste se aplica.
/// - Si cambió el texto libre mientras lo editabas, se expone en
///   [DayEditorState.conflictText] para que elijas qué hacer.
/// - En los demás campos con cambios de los dos lados, gana el local (se
///   guarda en el próximo autosave).
class DayEditorController extends Notifier<DayEditorState> {
  DayEditorController(this.dayId);

  final String dayId;

  static const typingDelay = Duration(milliseconds: 1500);
  static const tapDelay = Duration(milliseconds: 300);

  late EntryRepository _repo;
  late DiaryEntry _entry;

  /// Último valor conocido del almacenamiento, por campo.
  Map<String, Object?> _base = const {};

  /// Último valor que escribimos, por campo (para reconocer nuestros ecos).
  Map<String, Object?> _lastSaved = const {};
  bool _exists = false;
  bool _pendingWrites = false;
  Timer? _timer;

  @override
  DayEditorState build() {
    _repo = ref.watch(entryRepositoryProvider);
    _entry = DiaryEntry(id: dayId);
    _base = _entry.toFields();
    _lastSaved = _base;
    _exists = false;
    final sub = _repo.watchDay(dayId).listen(
          _onSnapshot,
          onError: (Object _) => _setState(status: SaveStatus.error),
        );
    ref.onDispose(() {
      sub.cancel();
      _save(disposing: true);
    });
    return DayEditorState(entry: _entry);
  }

  void _setState({
    DiaryEntry? entry,
    bool? loaded,
    SaveStatus? status,
    Object? conflictText = _keep,
    bool remoteChange = false,
  }) {
    if (entry != null) _entry = entry;
    state = state.copyWith(
      entry: entry,
      loaded: loaded,
      status: status,
      conflictText: conflictText,
      remoteRevision: remoteChange ? state.remoteRevision + 1 : null,
    );
  }

  SaveStatus get _settledStatus {
    if (_timer != null) return SaveStatus.pending;
    if (!_exists) return SaveStatus.empty;
    return _pendingWrites ? SaveStatus.savedLocally : SaveStatus.synced;
  }

  void _onSnapshot(DaySnapshot snap) {
    _exists = snap.entry != null;
    _pendingWrites = snap.hasPendingWrites;
    final remote = (snap.entry ?? DiaryEntry(id: dayId)).toFields();

    if (!state.loaded) {
      _base = remote;
      _lastSaved = remote;
      _setState(
        entry: snap.entry ?? DiaryEntry(id: dayId),
        loaded: true,
        status: _settledStatus,
        remoteChange: true,
      );
      return;
    }

    final local = _entry.toFields();
    final merged = Map.of(local);
    final lastSaved = Map.of(_lastSaved);
    var takenRemote = false;
    var conflict = state.conflictText;
    for (final f in EntryField.all) {
      final r = remote[f];
      if (DiaryEntry.fieldEquals(r, _base[f])) continue; // no cambió afuera
      if (DiaryEntry.fieldEquals(r, local[f])) continue; // ya coincide
      if (DiaryEntry.fieldEquals(r, _lastSaved[f])) continue; // eco de lo nuestro
      if (DiaryEntry.fieldEquals(local[f], _base[f])) {
        merged[f] = r;
        lastSaved[f] = r;
        takenRemote = true;
      } else if (f == EntryField.freeText) {
        conflict = r as String?;
      }
    }
    _base = remote;
    _lastSaved = lastSaved;
    _setState(
      entry: takenRemote ? DiaryEntry.fromFields(dayId, merged) : null,
      status: _settledStatus,
      conflictText: conflict,
      remoteChange: takenRemote,
    );
  }

  void _edit(DiaryEntry Function(DiaryEntry e) change, {Duration delay = typingDelay}) {
    final next = change(_entry);
    if (next == _entry) return;
    _timer?.cancel();
    _timer = Timer(delay, _save);
    _setState(entry: next, status: SaveStatus.pending);
  }

  /// Guarda ya lo pendiente (al salir de la pantalla, perder foco, etc.).
  void flush() {
    if (_timer != null) _save();
  }

  void _save({bool disposing = false}) {
    _timer?.cancel();
    _timer = null;
    final local = _entry.toFields();
    final changed = DiaryEntry.changedFields(_lastSaved, local);
    if (changed.isEmpty) {
      if (!disposing) _setState(status: _settledStatus);
      return;
    }
    _lastSaved = local;
    final Future<void> write;
    if (_entry.isEmpty) {
      if (!_exists) {
        if (!disposing) _setState(status: _settledStatus);
        return;
      }
      _exists = false;
      write = _repo.delete(dayId);
    } else {
      write = _repo.saveFields(dayId, {for (final f in changed) f: local[f]}, create: !_exists);
      _exists = true;
      _pendingWrites = true;
    }
    write.catchError((Object e) {
      if (ref.mounted) _setState(status: SaveStatus.error);
    });
    if (!disposing) _setState(status: _settledStatus);
  }

  // --- Edición ---

  void setFreeText(String text) => _edit((e) => e.copyWith(freeText: text));

  void setHighlight(String text) => _edit((e) => e.copyWith(highlight: text.isEmpty ? null : text));

  void setMood(int? mood) => _edit((e) => e.copyWith(mood: mood), delay: tapDelay);

  void addActivity(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _edit((e) => e.copyWith(activities: [...e.activities, Activity.manual(t)]), delay: tapDelay);
  }

  void insertActivity(int index, Activity activity) => _edit(
        (e) => e.copyWith(activities: [...e.activities]..insert(index.clamp(0, e.activities.length), activity)),
        delay: tapDelay,
      );

  void removeActivity(String id) =>
      _edit((e) => e.copyWith(activities: [...e.activities]..removeWhere((a) => a.id == id)), delay: tapDelay);

  void addTag(String tag) {
    final t = tag.trim().replaceFirst(RegExp(r'^#+'), '');
    if (t.isEmpty) return;
    if (_entry.tags.any((x) => x.toLowerCase() == t.toLowerCase())) return;
    _edit((e) => e.copyWith(tags: [...e.tags, t]), delay: tapDelay);
  }

  void insertTag(int index, String tag) =>
      _edit((e) => e.copyWith(tags: [...e.tags]..insert(index.clamp(0, e.tags.length), tag)), delay: tapDelay);

  void removeTag(String tag) => _edit((e) => e.copyWith(tags: [...e.tags]..remove(tag)), delay: tapDelay);

  void setSongOfDay(Song? song) =>
      _edit((e) => e.copyWith(songOfDay: (song == null || song.isEmpty) ? null : song), delay: tapDelay);

  void addListened(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final song = Song.parse(t);
    if (_entry.listened.any((s) => s.label.toLowerCase() == song.label.toLowerCase())) return;
    _edit((e) => e.copyWith(listened: [...e.listened, song]), delay: tapDelay);
  }

  void insertListened(int index, Song song) => _edit(
        (e) => e.copyWith(listened: [...e.listened]..insert(index.clamp(0, e.listened.length), song)),
        delay: tapDelay,
      );

  void removeListened(Song song) =>
      _edit((e) => e.copyWith(listened: [...e.listened]..remove(song)), delay: tapDelay);

  void clearDay() {
    _edit((e) => DiaryEntry(id: e.id), delay: Duration.zero);
    flush();
    _setState(conflictText: null, remoteChange: true);
  }

  void resolveConflict(ConflictChoice choice) {
    final theirs = state.conflictText;
    if (theirs == null) return;
    switch (choice) {
      case ConflictChoice.keepMine:
        // Forzar que se vuelva a escribir el texto local.
        _lastSaved = {..._lastSaved, EntryField.freeText: theirs};
        _timer?.cancel();
        _timer = Timer(tapDelay, _save);
        _setState(conflictText: null, status: SaveStatus.pending);
      case ConflictChoice.useTheirs:
        _edit((e) => e.copyWith(freeText: theirs), delay: tapDelay);
        _setState(conflictText: null, remoteChange: true);
      case ConflictChoice.combine:
        final mine = _entry.freeText.trimRight();
        _edit((e) => e.copyWith(freeText: '$mine\n\n— — —\n\n$theirs'), delay: tapDelay);
        _setState(conflictText: null, remoteChange: true);
    }
  }
}
