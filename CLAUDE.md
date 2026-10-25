# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

Diario personal en Flutter para **web** (PC) y **Android** (Google Pixel 10), sincronizado con Firebase (Auth con Google + Cloud Firestore con caché offline, plan Spark sin backend propio). Toda la UI y los comentarios del código están en español rioplatense (voseo: "Escribí", "Elegí"). Las decisiones de diseño están en `docs/adr/` (ADR-0001 sync con Firebase, aceptado; ADR-0002 recordatorios en Android, propuesto y todavía sin implementar, aunque `flutter_local_notifications`, `timezone` y `flutter_timezone` ya están en `pubspec.yaml`).

## Comandos

```bash
flutter pub get
flutter analyze                                   # debe quedar en "No issues found!"
flutter test                                      # todos los tests
flutter test test/<archivo>_test.dart             # un archivo
flutter test --plain-name "<nombre del test>"     # un test por nombre
flutter run -d chrome --dart-define=DEMO=true     # sin Firebase, datos de ejemplo en memoria
flutter run                                       # en el Pixel conectado por USB
flutter build web [--dart-define=DEMO=true]
flutter build apk --release
```

- `DEMO=true` fuerza el modo demo. Sin esa bandera, si `lib/firebase_options.dart` sigue siendo el placeholder (lanza `UnsupportedError`), `main.dart` cae solo a modo demo con un banner. El archivo real se genera con `flutterfire configure --platforms=web,android`.
- La web usa `usePathUrlStrategy()`: para servir `build/web` y abrir rutas como `/day/2026-10-24` hace falta un servidor con fallback a `index.html`.

## Arquitectura

Capas al estilo de la guía de arquitectura de Flutter (UI → ViewModel → Repository), con **Riverpod 3 como inyección de dependencias y los `Notifier` como ViewModels**. Al agregar features hay que mantener ese idioma: nada de `ChangeNotifier`, `provider`, `get_it` ni generación de código (`freezed`, `riverpod_generator`). Los modelos son inmutables y se escriben a mano.

- **Modelos** (`lib/models/`): `DiaryEntry` tiene un documento por día cuyo id es la fecha `yyyy-MM-dd` (`day_id.dart`). Además están `Activity`, `Song` y `Mood`. `DiaryEntry.toFields()` es la única serialización de los campos editables (los nombres están en `EntryField`). Se usa tanto para escribir en Firestore como para el diff campo por campo (`changedFields`). `Song.toMap()` incluye siempre todas las claves porque Firestore hace merge profundo de maps con `SetOptions(merge: true)`. `Activity` tiene `source`, `externalId` e `importId`, pensados para futuros importadores (Letterboxd, Serializd).
- **Datos** (`lib/data/`):
  - `EntryRepository` es la interfaz, con dos implementaciones: `FirestoreEntryRepository` (`users/{uid}/entries/{yyyy-MM-dd}`) e `InMemoryEntryRepository` (tests y demo).
  - Las escrituras son `saveFields(dayId, camposCambiados)`, un merge por campo con last-write-wins por campo. No se espera el `Future` porque offline no completa. El estado de sync sale de `DaySnapshot.hasPendingWrites`.
  - La búsqueda (`text_search.dart`) y las sugerencias de chips (`suggestions.dart`) se calculan en el cliente sobre todas las entradas en memoria. `normalizeForSearch` conserva el largo del string porque sus índices se usan para resaltar en el texto original.
- **Servicios**: `auth/auth_service.dart` tiene `FirebaseAuthService` (popup en web, `google_sign_in` 7 con Credential Manager en Android) y `DemoAuthService`.
- **Inyección** (`lib/providers.dart` + `lib/main.dart`): los providers declaran valores por defecto y `main.dart` los sobreescribe según el modo (demo o Firebase). `entryRepositoryProvider` depende del `uid` de `currentUserProvider`. Los tests deben sobreescribir los mismos providers (`entryRepositoryProvider`, `authServiceProvider`, `appModeProvider`).
- **Editor del día** (`ui/day/day_editor_controller.dart`): es la pieza más delicada.
  - Es un `NotifierProvider.autoDispose.family` por `dayId`. Riverpod 3 pasa el argumento por el constructor.
  - Autosave con debounce: 1.5 s al tipear y 300 ms en acciones de un toque. Además `flush()` se llama al perder foco, al pausar la app y en `onDispose`.
  - Si un día queda vacío, se borra el documento.
  - Los snapshots remotos se mezclan campo por campo usando `_base` (último valor remoto) y `_lastSaved` (último valor propio, para reconocer los ecos de nuestras escrituras). Si el texto libre cambia afuera mientras se edita, se expone en `conflictText`.
  - `remoteRevision` avisa a `DayPage` que tiene que copiar valores a sus `TextEditingController`.
- **Navegación** (`lib/router.dart`, `ui/navigation.dart`):
  - `go_router` 18. El `redirect` maneja la carga y el login preservando `?from=`.
  - Un `ShellRoute` envuelve todo en `AdaptiveShell`. Con menos de 840 px (`wideBreakpoint` en `ui/theme.dart`) muestra una `NavigationBar` con Hoy, Diario y Buscar. Con 840 px o más muestra `SidePanel` (buscador, calendario y lista) más el día a la derecha, así que en ese modo `/diario` y `/buscar` renderizan el `DayPage` de hoy.
  - `DayPage` lleva `ValueKey(dayId)` para recrear su estado al cambiar de día.
  - Para navegar a un día se usa `goToDay` / `Routes.day(id)`: hoy es `/`.
- **Tema**: Material 3 con semilla terracota. El texto escrito por el usuario usa la serif Literata (asset local) con `context.diaryBody` y `context.diaryHighlight`.

## Versiones a tener en cuenta

Las dependencias son más nuevas que lo que suele recordarse de memoria: Riverpod 3 (`Override` se importa de `package:flutter_riverpod/misc.dart`), go_router 18, google_sign_in 7 (`GoogleSignIn.instance.initialize()` / `authenticate()`), firebase_core 5, cloud_firestore 7 y flutter_local_notifications 22 (parámetros con nombre en `initialize` y `zonedSchedule`). Ante la duda, consultar el código en `~/.pub-cache/hosted/pub.dev/<paquete>-<versión>/`.

## Pendiente conocido

Ver los "Action Items" de los ADRs: `firestore.rules` y `firebase.json` (todavía no existen), los recordatorios de Android (ADR-0002), los tests (todavía no hay carpeta `test/`) y el README.
