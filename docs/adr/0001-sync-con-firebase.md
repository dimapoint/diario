# ADR-0001: Sincronización con Firebase (Auth + Firestore)

**Status:** Accepted
**Date:** 2026-10-25
**Deciders:** dimapoint (dueño del repo)

## Context

Diario personal de un solo usuario, usado desde la web (PC) y desde Android (Pixel 10), con las mismas entradas en ambos. Tiene que funcionar offline, costar US$ 0 y no requerir un servidor propio. Volumen esperado: unas 365 entradas por año, menos de 10 MB por año.

## Decision

Firebase Auth (Google) + Cloud Firestore con caché offline, en el plan Spark. Un documento por día en `users/{uid}/entries/{yyyy-MM-dd}`. Las escrituras son merges por campo (last-write-wins por campo) y la búsqueda se hace en el cliente. El export JSON queda como backup independiente.

## Options Considered

| Opción | Complexity | Cost | Offline | Pros | Cons |
|---|---|---|---|---|---|
| **Firebase (elegida)** | Low | $0 | Incluido | SDK oficial de Flutter, sync en tiempo real, sin servidor | Dependencia de Google, sin full-text, sin cifrado end-to-end |
| Supabase | Med | $0 (pausa proyectos inactivos) | Manual | SQL y full-text | El offline-first hay que armarlo a mano |
| SQLite + carpeta sincronizada | Med | $0 | Sí | Datos 100% propios | Sync frágil en Android, conflictos de archivos |
| PocketBase propio | Med | Hosting | Manual | Control total | Un servidor que mantener |

## Trade-off Analysis

Para un solo usuario, el offline y el sync incluidos pesan más que tener SQL o control total. La falta de full-text no importa porque todas las entradas entran en memoria. El riesgo de quedar atado a Firebase se mitiga con el export JSON.

## Consequences

- **Más fácil**: sync entre dispositivos, escritura sin conexión y cero infraestructura.
- **Más difícil**: si dos dispositivos editan offline el texto libre del mismo día, gana el último. Si llega un cambio remoto mientras escribís, la app avisa y deja elegir.
- **A revisar**: paginar el historial con más de 3.000 entradas, cifrado end-to-end opcional del texto libre y pasar a Blaze si hace falta lógica en el servidor.

## Action Items
1. [x] Repositorio Firestore.
2. [ ] Reglas de Firestore con validación de esquema (`firestore.rules`).
3. [x] Modo demo en memoria mientras Firebase no está configurado.
4. [ ] Configurar el proyecto Firebase (`flutterfire configure`) y desplegar las reglas.
