---
name: run-diario
description: Build, run, and drive the Diario Flutter app (web, demo mode) headless. Use when asked to start/run diario, build it, take a screenshot of its UI, click through it (Hoy, Diario, Buscar, Ajustes), check a UI change, or run its tests.
---

Diario es una app Flutter (web + Android). En el contenedor se maneja la versión **web en modo demo** (datos de ejemplo en memoria, sin Firebase) con el driver REPL `.claude/skills/run-diario/driver.mjs`. El driver sirve `build/web`, abre Chromium headless con Playwright y lee comandos por stdin: navegar, hacer clic por texto, tipear y sacar capturas. Todas las rutas son relativas a la raíz del repo.

## Prerequisites

Node con Playwright y Chromium ya vienen en la imagen (`require('playwright')` resuelve por `NODE_PATH`), igual que `tmux`. Lo único que hay que instalar es el Flutter SDK:

```bash
cd /root && curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.8-stable.tar.xz | tar -xJ
git config --global --add safe.directory /root/flutter
export PATH=/root/flutter/bin:$PATH
flutter --disable-analytics
```

## Build

```bash
export PATH=/root/flutter/bin:$PATH
flutter pub get
flutter build web --dart-define=DEMO=true    # ~70 s; deja todo en build/web
```

## Run (agent path)

Pasale un script por stdin. Cada comando imprime `ok …` o `ERR …`, las capturas van a `/tmp/diario-shots/` (se cambia con `SHOTS_DIR`) y al cerrar stdin se apaga todo. Este flujo completo (ánimo, destacado, texto, dos actividades desde el sheet y verlas en el historial) se corrió tal cual:

```bash
timeout 150 node .claude/skills/run-diario/driver.mjs <<'EOF'
nav /
click Ánimo 4 de 5
click Lo más destacado
type Probando el driver del diario
click Escribí lo que quieras
type Hoy armé el skill para manejar la app desde un agente.
click Agregar
wait 800
type Programé
press Enter
type Caminata
press Enter
ss sheet
click Listo
wait 2000
ss hoy-editado
click Diario
wait 800
ss diario
errors
EOF
```

Para escritorio o tema oscuro, cambiá `viewport` y `scheme` **antes** de `nav`, porque los dos crean una página nueva:

```bash
timeout 150 node .claude/skills/run-diario/driver.mjs <<'EOF'
viewport 1280 800
scheme dark
nav /day/2026-10-24
press Alt+ArrowLeft
wait 800
eval location.pathname
press Control+k
type pan
wait 800
ss desktop-dark
EOF
```

Para ir de a un comando, usalo bajo tmux:

```bash
tmux new-session -d -s diario -x 200 -y 50 -c "$PWD"
tmux send-keys -t diario 'node .claude/skills/run-diario/driver.mjs' Enter
timeout 30 bash -c 'until tmux capture-pane -t diario -p | grep -q "^listo:"; do sleep 0.2; done'
tmux send-keys -t diario 'nav /buscar' Enter
timeout 60 bash -c 'until tmux capture-pane -t diario -p | grep -q "ok nav"; do sleep 0.3; done'
tmux send-keys -t diario 'type asado' Enter 'ss buscar' Enter
tmux capture-pane -t diario -p
tmux send-keys -t diario 'quit' Enter
```

| comando | qué hace |
|---|---|
| `nav <ruta>` | abre `/`, `/diario`, `/buscar`, `/ajustes` o `/day/AAAA-MM-DD` y espera a que Flutter dibuje con la semántica activada |
| `click <texto>` | clic en el nodo **más chico** cuyo aria-label o texto contiene `<texto>`; los campos de texto también responden a `campo-N` |
| `labels [filtro]` | lista los nodos clickeables (rol, centro x,y y texto): usalo para descubrir qué clickear |
| `clickxy <x> <y>` | clic por coordenadas (las que muestra `labels`) |
| `type <texto>` / `press <tecla>` | teclado sobre el foco actual (`Enter`, `Escape`, `Alt+ArrowLeft`, `Control+k`) |
| `ss [nombre]` | captura a `/tmp/diario-shots/<nombre>.png` |
| `viewport <w> <h>` / `scheme light\|dark` | página nueva con ese tamaño o tema (por defecto 412×915, el Pixel, y claro) |
| `eval <js>` / `errors` / `wait <ms>` / `quit` | JS en la página, errores de consola, pausa, salir |

### Iterar sin recompilar todo (servidor de desarrollo)

`flutter run -d web-server` compila en unos 50 s la primera vez. Después, cada `R` recompila en menos de un segundo y el próximo `nav` del driver (que recarga la página) ya muestra el cambio:

```bash
tmux new-session -d -s flutter -x 200 -y 50 -c "$PWD"
tmux send-keys -t flutter 'export PATH=/root/flutter/bin:$PATH; flutter run -d web-server --web-port 8788 --dart-define=DEMO=true' Enter
timeout 300 bash -c 'until tmux capture-pane -t flutter -p | grep -q "is being served at"; do sleep 1; done'
timeout 200 node .claude/skills/run-diario/driver.mjs --url http://localhost:8788 <<'EOF'
nav /diario
ss dev-diario
errors
EOF
# después de editar código:
tmux send-keys -t flutter 'R'      # imprime "Recompile complete. No client connected." y está bien
# ...volver a correr el driver con nav...
tmux send-keys -t flutter 'q'; tmux kill-session -t flutter
```

## Test

```bash
flutter analyze    # "No issues found!"
flutter test       # hoy: 'Test directory "test" does not appear to contain any test files.' (todavía no hay tests)
```

## Gotchas

- **No hay `chromium-cli` en esta imagen.** Por eso existe el driver. Carga Playwright con `createRequire`, porque los `import` ESM ignoran `NODE_PATH` (y Playwright está instalado globalmente).
- **Flutter web dibuja en un canvas:** los selectores CSS de la UI no existen. El driver hace clic en `flt-semantics-placeholder` para que Flutter genere nodos `<flt-semantics>` con texto y aria-label, y `click` busca sobre esos nodos.
- **Los campos de texto son `<textarea>`/`<input>` reales, fuera de la semántica.** Vacíos, su aria-label es el hint ("Lo más destacado, en una línea", "Escribí lo que quieras…") y `click Lo más destacado` funciona. Con contenido y sin foco no exponen ni hint ni valor, así que el driver los nombra `campo-N` por orden en el DOM: `labels campo` los lista y `click campo-2` enfoca el texto libre de un día con contenido. Para agregar al final usá `press Control+End`; `End` solo va al final de la línea visual.
- **`type` recorta los espacios del principio y del final** del argumento.
- **Los textos ambiguos van al nodo más chico.** "Agregar" aparece en Qué hice y en Escuché, y `click Agregar` abre el de Qué hice. Para el otro, `labels Agregar` muestra las coordenadas de cada uno y después se usa `clickxy`.
- **`nav` recarga la app y el modo demo vuelve a los datos de ejemplo**: lo que editaste se pierde. Para seguir con el estado editado, navegá con clics (`click Diario`, `click Hoy`) en vez de `nav`.
- **Los datos demo son relativos a hoy** (ayer, anteayer, hace 3 días…). Para un día con contenido, usá `/day/<fecha de ayer>`.
- **El hover deja tooltips en las capturas.** El cursor queda donde fue el último clic: en la captura del Diario aparece el tooltip "Diario" sobre la barra inferior.
- **La app usa path URLs** (`/day/2026-10-24`): hace falta un servidor que devuelva `index.html` para cualquier ruta. Por eso el driver trae su propio servidor estático en `:8787`.
- **No mates servidores con `pkill -f <patrón>`**: matchea tu propio comando de shell y lo mata (salió exit 144). Usá `lsof -ti:8787 -sTCP:LISTEN | xargs -r kill`.
- `flutter` corriendo como root imprime "Woah! You appear to be trying to run flutter as root", y `flutter build web` avisa por `CupertinoIcons` y "Wasm dry run". Las tres cosas son inofensivas.

## Troubleshooting

- **`ERR click: nada contiene "…"`**: el texto no está en ningún nodo. Pasó al buscar `click Arranqué` (el contenido de un campo sin foco): usá `labels campo` y `click campo-N`, o `labels <parte del texto>` para lo demás.
- **`No pude escuchar en :8787 (EADDRINUSE)`**: quedó otro driver o servidor. `lsof -ti:8787 -sTCP:LISTEN | xargs -r kill`.
- **`No existe …/build/web/index.html`**: falta el build (`flutter build web --dart-define=DEMO=true`).
- **En el servidor de desarrollo, `R` dice "No clients available"**: es lo esperado con `-d web-server` sin la extensión de debug. El código se recompila igual y se ve con el próximo `nav`.
