# ADR-0002: Recordatorios diarios en Android

**Status:** Proposed
**Date:** 2026-10-25
**Deciders:** dimapoint (dueño del repo)

## Context

Querés que el celular te recuerde escribir el día, con horario y días configurables. Lo que condiciona la decisión:

- **Dispositivo**: un Google Pixel 10 con Android stock. No hay capas de fabricante que maten apps en segundo plano (los problemas típicos de Xiaomi o Huawei) ni el límite de 500 alarmas de Samsung. Sí aplican las reglas normales de Android: Doze, permiso de notificaciones (Android 13+) y la política de alarmas exactas (Android 14+).
- **Distribución**: APK instalado por vos (sideload), sin pasar por Play Store. Eso permite declarar `USE_EXACT_ALARM` sin la revisión de políticas de Play.
- **Costo US$ 0 / plan Spark** (ADR-0001): nada de Cloud Functions ni servidores.
- **Varios dispositivos**: podés escribir el día desde la PC. Lo ideal es que el celular no te recuerde si ya escribiste.
- **Web**: las notificaciones programadas del navegador no son confiables con la pestaña cerrada, así que esto queda solo para Android.

## Decision

**Notificaciones locales programadas como una ventana móvil de avisos sueltos** (`flutter_local_notifications` + `timezone`), con **alarmas exactas** gracias a `USE_EXACT_ALARM`.

- Se programan avisos individuales para los próximos **30 días** que coincidan con tu configuración. Cada aviso tiene id `yyyymmdd`, por ejemplo `20261025`.
- **"Solo si todavía no escribí"**: los días que ya tienen entrada no se programan, y al escribir el día de hoy se cancela su aviso.
- La programación se recalcula al abrir la app, al volver a ella, al cambiar la configuración y cada vez que cambian las entradas. Ese último caso incluye lo que escribiste en la PC y llegó por sync mientras la app estaba abierta.
- Después de reiniciar el teléfono, el `ScheduledNotificationBootReceiver` del plugin vuelve a armar los avisos.
- La configuración se guarda **en el dispositivo** (`shared_preferences`), porque los recordatorios son del teléfono y no de la cuenta: activado, hora (21:30 por defecto), días de la semana y "solo si no escribí".
- Al tocar la notificación se abre **Hoy**.
- Si Android no deja usar alarmas exactas (por ejemplo, si a futuro se publica en Play Store), se usa `inexactAllowWhileIdle`, que puede llegar unos minutos tarde.

## Options Considered

### Option A: Notificación diaria repetitiva (`matchDateTimeComponents`)
| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Cost | $0 |
| Scalability | No aplica (1 usuario) |
| Team familiarity | Alta: es el ejemplo de la documentación |

**Pros:** Muy simple. Una sola alarma por día de la semana que no se agota nunca.
**Cons:** No puede saltear un día puntual, así que te avisa aunque ya hayas escrito. Para eso habría que cancelar y reprogramar todo, que es lo mismo que la opción B.

### Option B: Ventana móvil de avisos sueltos (elegida)
| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium (una función pura que calcula las fechas, más la reconciliación) |
| Cost | $0 |
| Scalability | 30 alarmas como máximo, muy lejos de cualquier límite |
| Team familiarity | Alta: misma API que A |

**Pros:** Saltea los días ya escritos. Funciona offline y sin servidor. La lógica de qué días avisar es testeable sin dispositivo.
**Cons:** Si no abrís la app en 30 días, los avisos se terminan. Si escribiste en la PC y el teléfono no sincronizó desde entonces, te avisa igual.

### Option C: Tarea en segundo plano (WorkManager) que consulta Firestore antes de avisar
| Dimension | Assessment |
|-----------|------------|
| Complexity | High (isolate de fondo, Firebase y auth fuera de la UI) |
| Cost | $0 |
| Scalability | OK |
| Team familiarity | Baja |

**Pros:** Sabe lo que escribiste en la PC aunque no hayas abierto la app en el celular.
**Cons:** WorkManager no garantiza la hora exacta. Inicializar Firebase y la sesión en segundo plano es frágil. Es mucho código para el caso marginal de escribir en la PC justo antes del recordatorio.

### Option D: Push desde el servidor (FCM + Cloud Function programada)
| Dimension | Assessment |
|-----------|------------|
| Complexity | High |
| Cost | Requiere plan Blaze (con tarjeta) |
| Scalability | La mejor |
| Team familiarity | Media |

**Pros:** Es la opción más precisa entre dispositivos y funcionaría también en la web.
**Cons:** Rompe la restricción de US$ 0 y sin servidor. Agrega infraestructura que hay que mantener.

## Trade-off Analysis

B cubre el pedido (horario y días configurables, y no avisar si ya escribiste) con el mismo costo y la misma infraestructura que A. Su debilidad es que si escribiste en la PC y no abriste el celular, igual te avisa. Ese caso molesta poco: la notificación lleva a Hoy, ves el día ya escrito y listo. C y D lo resuelven, pero cuestan mucha complejidad (C) o rompen el presupuesto (D).

En la precisión, como el Pixel tiene Android stock y la app se instala por fuera de Play, `USE_EXACT_ALARM` da la hora exacta sin pedirte ningún permiso extra. Las alarmas exactas se reservan para casos como este, que son pocos avisos por día y nada de trabajo continuo en segundo plano, así que el impacto en batería es despreciable.

## Consequences

- **Más fácil**: un recordatorio confiable a la hora exacta, sin backend; la lógica de qué días avisar es una función pura con tests.
- **Más difícil**: hay que mantener sincronizada la programación con las entradas y la configuración (un `ReminderScheduler` que escucha `entriesProvider`). Además el proyecto Android necesita *core library desugaring*, receivers en el manifest y los permisos `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` y `USE_EXACT_ALARM`.
- **A revisar**:
  - Si se publica en Play Store: reemplazar `USE_EXACT_ALARM` por `SCHEDULE_EXACT_ALARM` con pedido de permiso, o quedarse con alarmas inexactas.
  - Si molestan los avisos después de escribir en la PC: evaluar la opción C.
  - Acciones en la notificación (los 5 emojis de ánimo) para registrar el día sin abrir la app. Requiere escribir a Firestore desde segundo plano, con la misma complejidad que C.

## Action Items
1. [ ] Agregar `flutter_local_notifications`, `timezone` y `flutter_timezone`; habilitar desugaring en `android/app/build.gradle.kts`.
2. [ ] Manifest: permisos `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` y `USE_EXACT_ALARM`, más los receivers `ScheduledNotificationReceiver` y `ScheduledNotificationBootReceiver`.
3. [ ] `ReminderSettings` (activado, hora, días, solo si no escribí) persistido en `shared_preferences`.
4. [ ] Función pura `reminderDates(settings, now, writtenDayIds, window: 30)` con tests unitarios.
5. [ ] `ReminderScheduler`: inicializa el plugin y la zona horaria y reconcilia (cancela y programa) ante cambios de entradas o configuración, al abrir la app y al volver a ella.
6. [ ] Sección "Recordatorio" en Ajustes (solo en Android): switch, selector de hora, chips L–D, "Solo si todavía no escribí" y "Probar notificación". Al activarlo se pide el permiso de notificaciones.
7. [ ] Documentar en el README cómo probarlo en el Pixel.
