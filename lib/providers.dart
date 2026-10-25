import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_service.dart';
import 'data/entry_repository.dart';
import 'data/suggestions.dart';
import 'models/entry.dart';

/// Cómo arrancó la app.
class AppMode {
  const AppMode.firebase() : demo = false, demoReason = null;
  const AppMode.demo({this.demoReason}) : demo = true;

  final bool demo;

  /// Por qué está en modo demo (por ejemplo, Firebase sin configurar).
  final String? demoReason;
}

final appModeProvider = Provider<AppMode>((ref) => const AppMode.demo());

final authServiceProvider = Provider<AuthService>((ref) => DemoAuthService());

final currentUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).userChanges(),
);

/// Se reemplaza en `main.dart` según el modo (Firestore del usuario o memoria).
final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => throw UnimplementedError('entryRepositoryProvider sin configurar'),
);

final entriesProvider = StreamProvider<List<DiaryEntry>>(
  (ref) => ref.watch(entryRepositoryProvider).watchAll(),
);

final suggestionsProvider = Provider<Suggestions>((ref) {
  final entries = ref.watch(entriesProvider).value;
  return entries == null ? Suggestions.empty : Suggestions.fromEntries(entries);
});

final preferencesProvider = Provider<SharedPreferences?>((ref) => null);

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() {
    final saved = ref.watch(preferencesProvider)?.getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(preferencesProvider)?.setString(_key, mode.name);
  }
}
