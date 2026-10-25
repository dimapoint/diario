import '../models/entry.dart';

/// Lo que se sabe de un día en el almacenamiento.
class DaySnapshot {
  const DaySnapshot({this.entry, this.hasPendingWrites = false});

  /// null si el día todavía no tiene entrada.
  final DiaryEntry? entry;

  /// true mientras hay cambios guardados en el dispositivo que todavía no
  /// llegaron al servidor (por ejemplo, sin conexión).
  final bool hasPendingWrites;
}

abstract interface class EntryRepository {
  /// Todas las entradas, de la más reciente a la más vieja.
  Stream<List<DiaryEntry>> watchAll();

  Stream<DaySnapshot> watchDay(String dayId);

  /// Escribe solo los [fields] indicados (merge por campo) y crea el día si
  /// no existía. No hace falta esperar el Future para que el cambio se vea:
  /// sin conexión puede tardar en completarse.
  Future<void> saveFields(String dayId, Map<String, Object?> fields, {bool create = false});

  Future<void> delete(String dayId);
}
