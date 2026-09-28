// Compila background.ts y content.ts (IIFE) y, a partir del index.html generado
// por ng build, crea sidepanel.html y options.html (un único bundle Angular
// sirve las 3 vistas según el atributo data-view del <body>).
import { build } from 'esbuild';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const outdir = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(root, 'dist', 'extension-forge-demo-app', 'browser');

// 1. Compilar background y content script
await build({
  entryPoints: [
    path.join(root, 'src', 'background.ts'),
    path.join(root, 'src', 'content.ts'),
  ],
  bundle: true,
  format: 'iife',
  target: 'es2020',
  outdir,
  logLevel: 'info',
});

// 2. Generar sidepanel.html y options.html desde index.html
const indexPath = path.join(outdir, 'index.html');
try {
  const indexHtml = readFileSync(indexPath, 'utf8');
  for (const view of ['sidepanel', 'options']) {
    const html = indexHtml
      .replace('data-view="popup"', `data-view="${view}"`)
      .replace(/<title>.*?<\/title>/, `<title>ForgeNotes — ${view}</title>`);
    writeFileSync(path.join(outdir, `${view}.html`), html);
    console.log(`[ExtensionForge] ${view}.html generado.`);
  }
} catch (err) {
  console.warn(`[ExtensionForge] No se pudieron generar sidepanel/options HTML: ${err.message}`);
}

console.log(`[ExtensionForge] background.js, content.js, sidepanel.html y options.html generados en ${outdir}`);
