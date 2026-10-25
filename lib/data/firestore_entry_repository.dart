import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/entry.dart';
import 'entry_repository.dart';

/// Guarda cada día en `users/{uid}/entries/{yyyy-MM-dd}`.
class FirestoreEntryRepository implements EntryRepository {
  FirestoreEntryRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('users').doc(uid).collection('entries');

  static DiaryEntry _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DiaryEntry.fromFields(
      doc.id,
      data,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Stream<List<DiaryEntry>> watchAll() => _entries
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) _fromDoc(d)]);

  @override
  Stream<DaySnapshot> watchDay(String dayId) => _entries
      .doc(dayId)
      .snapshots(includeMetadataChanges: true)
      .map((s) => DaySnapshot(
            entry: s.exists ? _fromDoc(s) : null,
            hasPendingWrites: s.metadata.hasPendingWrites,
          ));

  @override
  Future<void> saveFields(String dayId, Map<String, Object?> fields, {bool create = false}) =>
      _entries.doc(dayId).set({
        ...fields,
        'date': dayId,
        'schemaVersion': DiaryEntry.schemaVersion,
        'updatedAt': FieldValue.serverTimestamp(),
        if (create) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> delete(String dayId) => _entries.doc(dayId).delete();
}
