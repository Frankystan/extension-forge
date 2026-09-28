// Compila background.ts y content.ts como bundles independientes (IIFE).
// Uso: node scripts/build-extension.mjs [outdir]
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const outdir = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(root, 'dist', 'extension-forge-app', 'browser');

await build({
  entryPoints: [
    path.join(root, 'src', 'background.ts'),
    path.join(root, 'src', 'content.ts')
  ],
  bundle: true,
  format: 'iife',
  target: 'es2020',
  outdir,
  logLevel: 'info'
});

console.log(`[ExtensionForge] background.js y content.js generados en ${outdir}`);
