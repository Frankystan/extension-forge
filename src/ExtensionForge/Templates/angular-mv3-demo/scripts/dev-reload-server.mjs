// Servidor de recarga en desarrollo de ExtensionForge.
// Vigila dist/extension/.build-complete (lo escribe Build-ExtensionForgeProject al
// terminar cada build) y envía { type: 'RELOAD_EXTENSION' } a los backgrounds
// conectados (src/dev/dev-reload.ts). Solo escucha en 127.0.0.1.
//
// Uso: node scripts/dev-reload-server.mjs [puerto]   (por defecto 35729 o EXTFORGE_DEV_RELOAD_PORT)
import { WebSocketServer } from 'ws';
import { existsSync, mkdirSync, watch } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const port = Number(process.argv[2] ?? process.env.EXTFORGE_DEV_RELOAD_PORT ?? 35729);
const distDir = path.join(root, 'dist', 'extension');
const stampName = '.build-complete';

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error(`[ExtensionForge][dev-reload] Puerto no válido: ${process.argv[2]}`);
  process.exit(1);
}

const wss = new WebSocketServer({ host: '127.0.0.1', port });
wss.on('listening', () => console.log(`[ExtensionForge][dev-reload] ws://127.0.0.1:${port} — vigilando ${path.join(distDir, stampName)}`));
wss.on('connection', (socket, req) => {
  console.log(`[ExtensionForge][dev-reload] Cliente conectado (${req.socket.remoteAddress}). Total: ${wss.clients.size}`);
  socket.on('close', () => console.log(`[ExtensionForge][dev-reload] Cliente desconectado. Total: ${wss.clients.size}`));
});
wss.on('error', (err) => {
  console.error(`[ExtensionForge][dev-reload] ${err.message}`);
  process.exit(1);
});

function broadcastReload() {
  const message = JSON.stringify({ type: 'RELOAD_EXTENSION', at: new Date().toISOString() });
  let sent = 0;
  for (const client of wss.clients) {
    if (client.readyState === 1) {
      client.send(message);
      sent++;
    }
  }
  console.log(`[ExtensionForge][dev-reload] Build completado → RELOAD_EXTENSION a ${sent} cliente(s).`);
}

// Se vigila el directorio (no el archivo) porque el build lo reescribe.
mkdirSync(distDir, { recursive: true });
let timer;
watch(distDir, (_event, filename) => {
  if (filename !== stampName || !existsSync(path.join(distDir, stampName))) return;
  clearTimeout(timer);
  timer = setTimeout(broadcastReload, 150); // agrupa escrituras consecutivas
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    wss.close();
    process.exit(0);
  });
}
