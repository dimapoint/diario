import 'dart:async';

import '../models/entry.dart';
import 'entry_repository.dart';

/// Repositorio en memoria, para tests y para el modo demo.
class InMemoryEntryRepository implements EntryRepository {
  InMemoryEntryRepository([Iterable<DiaryEntry> initial = const []]) {
    for (final e in initial) {
      _entries[e.id] = e;
    }
  }

  final _entries = <String, DiaryEntry>{};
  final _changes = StreamController<void>.broadcast();

  /// Cantidad de escrituras recibidas (útil en tests).
  int saveCount = 0;

  List<DiaryEntry> get entries => _sorted();

  DiaryEntry? operator [](String dayId) => _entries[dayId];

  List<DiaryEntry> _sorted() => _entries.values.toList()..sort((a, b) => b.id.compareTo(a.id));

  @override
  Stream<List<DiaryEntry>> watchAll() async* {
    yield _sorted();
    await for (final _ in _changes.stream) {
      yield _sorted();
    }
  }

  @override
  Stream<DaySnapshot> watchDay(String dayId) async* {
    yield DaySnapshot(entry: _entries[dayId]);
    await for (final _ in _changes.stream) {
      yield DaySnapshot(entry: _entries[dayId]);
    }
  }

  @override
  Future<void> saveFields(String dayId, Map<String, Object?> fields, {bool create = false}) async {
    saveCount++;
    final now = DateTime.now();
    final current = _entries[dayId];
    final merged = {...?current?.toFields(), ...fields};
    _entries[dayId] = DiaryEntry.fromFields(
      dayId,
      merged,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
    _changes.add(null);
  }

  @override
  Future<void> delete(String dayId) async {
    if (_entries.remove(dayId) != null) _changes.add(null);
  }
}
