import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'data/demo_data.dart';
import 'data/firestore_entry_repository.dart';
import 'data/in_memory_entry_repository.dart';
import 'firebase_options.dart';
import 'providers.dart';

/// `flutter run --dart-define=DEMO=true` arranca sin Firebase, con datos de
/// ejemplo en memoria.
const _forceDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('es');
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Literata'], ofl);
  });

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    // Sin preferencias guardadas: se usa el tema del sistema.
  }

  final overrides = <Override>[
    preferencesProvider.overrideWithValue(prefs),
    ...(_forceDemo ? _demoOverrides() : await _firebaseOverrides()),
  ];
  runApp(ProviderScope(overrides: overrides, child: const DiarioApp()));
}

List<Override> _demoOverrides({String? reason}) {
  final repo = InMemoryEntryRepository(demoEntries());
  return [
    appModeProvider.overrideWithValue(AppMode.demo(demoReason: reason)),
    authServiceProvider.overrideWithValue(DemoAuthService()),
    entryRepositoryProvider.overrideWithValue(repo),
  ];
}

Future<List<Override>> _firebaseOverrides() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase no disponible, arranco en modo demo: $e');
    return _demoOverrides(reason: 'Firebase todavía no está configurado (ver README).');
  }
  final db = FirebaseFirestore.instance;
  // Caché offline: en Android viene activada; en web hay que pedirla.
  db.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    webPersistentTabManager: kIsWeb ? const WebPersistentMultipleTabManager() : null,
  );
  return [
    appModeProvider.overrideWithValue(const AppMode.firebase()),
    authServiceProvider.overrideWithValue(FirebaseAuthService(FirebaseAuth.instance)),
    entryRepositoryProvider.overrideWith((ref) {
      final uid = ref.watch(currentUserProvider.select((u) => u.value?.uid));
      return uid == null ? InMemoryEntryRepository() : FirestoreEntryRepository(db, uid);
    }),
  ];
}
