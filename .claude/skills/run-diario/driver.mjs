#!/usr/bin/env node
// Driver REPL para la app web de Diario (Flutter web).
//
// Sirve build/web con fallback SPA, abre Chromium headless con Playwright y
// lee comandos de stdin, uno por línea (pipe o tmux). `help` los lista.
//
//   node .claude/skills/run-diario/driver.mjs [--root build/web] [--port 8787]
//   node .claude/skills/run-diario/driver.mjs --url http://localhost:8788
//
// Las capturas van a $SHOTS_DIR (por defecto /tmp/diario-shots).

import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';

// Playwright está instalado globalmente (NODE_PATH), que los imports ESM ignoran.
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : def;
};
const root = path.resolve(opt('root', 'build/web'));
const port = Number(opt('port', '8787'));
// --url apunta a un servidor que ya está corriendo (p.ej. `flutter run -d web-server`)
// y desactiva el servidor estático propio.
const external = opt('url');
const base = external ? external.replace(/\/$/, '') : `http://localhost:${port}`;
const shotsDir = process.env.SHOTS_DIR || '/tmp/diario-shots';
fs.mkdirSync(shotsDir, { recursive: true });

if (!external && !fs.existsSync(path.join(root, 'index.html'))) {
  console.error(`No existe ${root}/index.html. Corré: flutter build web --dart-define=DEMO=true`);
  process.exit(1);
}

// --- Servidor estático con fallback a index.html (la app usa path URLs) ---
const types = {
  '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.txt': 'text/plain', '.css': 'text/css',
};
const server = http.createServer((req, res) => {
  let p = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!p.startsWith(root) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) {
    p = path.join(root, 'index.html');
  }
  res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
if (!external) await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(port, resolve);
}).catch((e) => {
  console.error(`No pude escuchar en :${port} (${e.code}). Liberalo: lsof -ti:${port} -sTCP:LISTEN | xargs -r kill`);
  process.exit(1);
});

// --- Navegador ---
const browser = await chromium.launch();
let viewport = { width: 412, height: 915 }; // Pixel en CSS px
let colorScheme = 'light';
let context, page;
const errors = [];

async function newPage() {
  await context?.close();
  context = await browser.newContext({ viewport, colorScheme });
  page = await context.newPage();
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
}

async function waitForFlutter() {
  await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 30000 });
  // Habilitar la semántica crea nodos <flt-semantics> con texto y aria-label,
  // que es lo que usan `click` y `labels`.
  await page.waitForFunction(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (ph) ph.click();
    return document.querySelectorAll('flt-semantics').length > 3;
  }, null, { timeout: 30000, polling: 250 });
  await page.waitForTimeout(500);
}

// Nodos de semántica y campos de texto que contienen el texto, del más chico
// al más grande: el más chico es el widget más específico.
//
// Los campos de texto son <textarea>/<input> reales. Vacíos tienen el hint en
// aria-label; con contenido y sin foco no exponen ni hint ni valor, así que se
// nombran `campo-N` (orden en el DOM) para poder hacer `click campo-2`.
async function findTargets(text) {
  return page.evaluate((needle) => {
    const n = needle.toLowerCase();
    const out = [];
    let field = 0;
    for (const el of document.querySelectorAll('flt-semantics, textarea, input')) {
      const isField = el.tagName !== 'FLT-SEMANTICS';
      const name = isField ? `campo-${++field} ` : '';
      const label = name + (el.getAttribute('aria-label') || '') + ' ' + (isField ? el.value : el.textContent || '');
      if (!label.toLowerCase().includes(n)) continue;
      const r = el.getBoundingClientRect();
      if (r.width < 1 || r.height < 1) continue;
      out.push({ x: r.x + r.width / 2, y: r.y + r.height / 2, area: r.width * r.height,
        role: el.getAttribute('role') || (isField ? 'textbox' : ''),
        label: label.replace(/\s+/g, ' ').trim().slice(0, 70) });
    }
    return out.sort((a, b) => a.area - b.area);
  }, text);
}

const commands = {
  help: 'lista los comandos',
  nav: '<ruta>  abre base+ruta (p.ej. /, /diario, /buscar, /day/2026-10-24) y espera a Flutter',
  ss: '[nombre]  captura a $SHOTS_DIR/<nombre>.png',
  click: '<texto>  clic en el elemento más chico cuyo texto/aria-label contiene <texto> (campos: campo-N)',
  clickxy: '<x> <y>  clic en coordenadas CSS',
  type: '<texto>  tipea en el foco actual',
  press: '<tecla>  p.ej. Enter, Escape, Alt+ArrowLeft, Control+k',
  labels: '[filtro]  lista nodos de semántica (rol, centro, texto)',
  viewport: '<ancho> <alto>  cambia el tamaño (nueva página; hacé nav después)',
  scheme: 'light|dark  tema del sistema (nueva página; hacé nav después)',
  wait: '<ms>',
  eval: '<js>  evalúa en la página e imprime el resultado',
  errors: 'errores de consola acumulados',
  quit: 'cierra todo',
};

async function run(line) {
  const [cmd, ...rest] = line.trim().split(/\s+/);
  const arg = line.trim().slice(cmd.length).trim();
  switch (cmd) {
    case '': case '#': return;
    case 'help':
      for (const [k, v] of Object.entries(commands)) console.log(`  ${k} ${v}`);
      return;
    case 'nav':
      await page.goto(base + (arg || '/'), { waitUntil: 'load' });
      await waitForFlutter();
      return console.log(`ok nav ${page.url()}`);
    case 'ss': {
      const file = path.join(shotsDir, `${arg || 'shot-' + Date.now()}.png`);
      await page.screenshot({ path: file });
      return console.log(`ok ss ${file}`);
    }
    case 'click': {
      const targets = await findTargets(arg);
      if (!targets.length) return console.log(`ERR click: nada contiene "${arg}" (probá labels)`);
      const t = targets[0];
      await page.mouse.click(t.x, t.y);
      await page.waitForTimeout(400);
      return console.log(`ok click ${t.role || 'node'} "${t.label}" @${Math.round(t.x)},${Math.round(t.y)}`);
    }
    case 'clickxy':
      await page.mouse.click(Number(rest[0]), Number(rest[1]));
      await page.waitForTimeout(400);
      return console.log('ok clickxy');
    case 'type':
      await page.keyboard.type(arg, { delay: 20 });
      await page.waitForTimeout(300);
      return console.log('ok type');
    case 'press':
      await page.keyboard.press(arg);
      await page.waitForTimeout(400);
      return console.log(`ok press ${arg}`);
    case 'labels': {
      const all = await findTargets(arg || '');
      const seen = new Set();
      for (const t of all.reverse()) {
        const key = `${t.label}@${Math.round(t.x)},${Math.round(t.y)}`;
        if (!t.label || seen.has(key)) continue;
        seen.add(key);
        console.log(`  ${t.role.padEnd(8)} @${Math.round(t.x)},${Math.round(t.y)}  ${t.label}`);
      }
      return;
    }
    case 'viewport':
      viewport = { width: Number(rest[0]), height: Number(rest[1]) };
      await newPage();
      return console.log(`ok viewport ${rest[0]}x${rest[1]} (hacé nav)`);
    case 'scheme':
      colorScheme = arg === 'dark' ? 'dark' : 'light';
      await newPage();
      return console.log(`ok scheme ${colorScheme} (hacé nav)`);
    case 'wait':
      await page.waitForTimeout(Number(arg || 500));
      return console.log('ok wait');
    case 'eval':
      return console.log(JSON.stringify(await page.evaluate(arg)));
    case 'errors':
      console.log(errors.length ? errors.join('\n') : 'sin errores');
      return;
    case 'quit':
      await shutdown();
      return;
    default:
      console.log(`ERR comando desconocido: ${cmd} (help)`);
  }
}

async function shutdown() {
  await browser.close().catch(() => {});
  server.close();
  process.exit(0);
}

await newPage();
console.log(`listo: ${base}${external ? '' : ` sirviendo ${root}`}; capturas en ${shotsDir}`);
const rl = readline.createInterface({ input: process.stdin, terminal: false });
let queue = Promise.resolve();
rl.on('line', (line) => {
  queue = queue.then(() => run(line)).catch((e) => console.log(`ERR ${e.message.split('\n')[0]}`));
});
rl.on('close', () => queue.then(shutdown));
