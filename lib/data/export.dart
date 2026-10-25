import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import '../models/day_id.dart';
import '../models/entry.dart';

/// El backup completo en JSON.
String exportJson(List<DiaryEntry> entries) => const JsonEncoder.withIndent('  ').convert({
      'app': 'diario',
      'schemaVersion': DiaryEntry.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': [for (final e in entries) e.toJson()],
    });

/// Descarga el backup (web) o abre el diálogo para elegir dónde guardarlo
/// (Android). Devuelve false si se canceló.
Future<bool> saveExport(List<DiaryEntry> entries) async {
  final bytes = Uint8List.fromList(utf8.encode(exportJson(entries)));
  final name = 'diario-${todayId()}';
  if (kIsWeb) {
    await FileSaver.instance.saveFile(name: name, bytes: bytes, fileExtension: 'json', mimeType: MimeType.json);
    return true;
  }
  final path = await FileSaver.instance.saveAs(
    name: name,
    bytes: bytes,
    fileExtension: 'json',
    mimeType: MimeType.json,
  );
  return path != null;
}
