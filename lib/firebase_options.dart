// Placeholder hasta configurar Firebase.
//
// Para generar este archivo con los datos de tu proyecto, corré:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --platforms=web,android
//
// (ver README.md). Mientras tanto la app arranca en modo demo.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Firebase todavía no está configurado: corré `flutterfire configure`.');
}
