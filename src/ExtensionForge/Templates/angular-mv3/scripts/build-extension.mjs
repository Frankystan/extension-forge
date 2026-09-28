// Compila background.ts y content.ts como bundles independientes (IIFE); content.ts con AOT (ngc) si existe tsconfig.content.json.
// Uso: node scripts/build-extension.mjs [outdir]
import { build } from 'esbuild';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const outdir = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(root, 'dist', 'extension-forge-app', 'browser');

// ── Content script con Angular (AOT) ────────────────────────────────────────
// Si existe tsconfig.content.json, ngc compila src/content.ts y los componentes
// Angular que importe (adaptadores Shadow DOM) en modo AOT a out-tsc/content, y
// esbuild empaqueta ese resultado. Así el content script no necesita el
// compilador JIT, que MV3 bloquea (eval / new Function).
const contentTsconfig = path.join(root, 'tsconfig.content.json');
const contentOut = path.join(root, 'out-tsc', 'content');
let contentEntry = path.join(root, 'src', 'content.ts');
const contentPlugins = [];

if (existsSync(contentTsconfig)) {
  const require = createRequire(import.meta.url);
  const ngcBin = path.join(path.dirname(require.resolve('@angular/compiler-cli/package.json', { paths: [root] })), 'bundles', 'src', 'bin', 'ngc.js');
  rmSync(contentOut, { recursive: true, force: true });
  execFileSync(process.execPath, [ngcBin, '-p', contentTsconfig], { cwd: root, stdio: 'inherit' });
  contentEntry = path.join(contentOut, 'content.js');

  // Los .scss importados desde el content script se compilan con sass y se
  // inyectan como texto CSS (p. ej. el tema Material del Shadow Root).
  contentPlugins.push({
    name: 'extensionforge-scss-text',
    setup(b) {
      b.onResolve({ filter: /\.scss$/ }, (args) => {
        const dir = args.resolveDir.startsWith(contentOut)
          ? path.join(root, 'src', path.relative(contentOut, args.resolveDir))
          : args.resolveDir;
        return { path: path.resolve(dir, args.path), namespace: 'ef-scss' };
      });
      b.onLoad({ filter: /.*/, namespace: 'ef-scss' }, async (args) => {
        const mod = await import(pathToFileURL(require.resolve('sass', { paths: [root] })).href);
        const sass = typeof mod.compile === 'function' ? mod : mod.default;
        const out = sass.compile(args.path, { loadPaths: [path.join(root, 'node_modules')], style: 'compressed' });
        return { contents: out.css, loader: 'text', watchFiles: out.loadedUrls.filter((u) => u.protocol === 'file:').map((u) => fileURLToPath(u)) };
      });
    },
  });

  // Las librerías Angular de npm (Angular Material, CDK...) se publican en
  // compilación parcial (ɵɵngDeclare*). El linker de Angular las completa en
  // tiempo de build, igual que ng build; sin él requerirían JIT en runtime.
  contentPlugins.push({
    name: 'extensionforge-angular-linker',
    setup(b) {
      let babel, linkerPlugin;
      b.onLoad({ filter: /[\\/]node_modules[\\/].*\.m?js$/ }, async (args) => {
        const code = await readFile(args.path, 'utf8');
        if (!code.includes('ɵɵngDeclare')) return undefined;
        babel ??= await import(pathToFileURL(require.resolve('@babel/core', { paths: [root] })).href);
        linkerPlugin ??= (await import(pathToFileURL(require.resolve('@angular/compiler-cli/linker/babel', { paths: [root] })).href)).default;
        const transform = babel.transformAsync ?? babel.default.transformAsync;
        const out = await transform(code, {
          filename: args.path, babelrc: false, configFile: false, compact: false, sourceMaps: false,
          plugins: [linkerPlugin],
        });
        return { contents: out.code, loader: 'js' };
      });
    },
  });
}

// Production (EXTFORGE_ENVIRONMENT, lo fija Build-ExtensionForgeProject): minifica y
// elimina el código de desarrollo de Angular (ngDevMode), igual que ng build.
const production = (process.env.EXTFORGE_ENVIRONMENT ?? '').toLowerCase() === 'production';
const common = {
  bundle: true,
  format: 'iife',
  target: 'es2020',
  outdir,
  logLevel: 'info',
  legalComments: 'none',
  minify: production,
  define: {
    ...(production ? { ngDevMode: 'false' } : {}),
    // Puerto del servidor de recarga (Development + Runtime.EnableHotReload) o 0.
    // Con 0 el cliente de src/dev/dev-reload.ts queda como código muerto y se elimina.
    __EXTFORGE_DEV_RELOAD_PORT__: String(production ? 0 : Number(process.env.EXTFORGE_DEV_RELOAD_PORT ?? 0) || 0),
  },
};

await build({ ...common, entryPoints: [path.join(root, 'src', 'background.ts')] });
await build({ ...common, entryPoints: { content: contentEntry }, plugins: contentPlugins });

console.log(`[ExtensionForge] background.js y content.js generados en ${outdir}`);
