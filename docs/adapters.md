# ExtensionForge — Adaptadores de content script (Shadow DOM)

> Cómo usar `scripts/Add-ContentAdapter.ps1` para montar un componente Angular + Angular Material dentro de páginas de terceros sin fugas de CSS.
> Verificado el 2026-09-28: pruebas Pester del generador (`tests/Unit/Tools/Add-ContentAdapter.Tests.ps1`), E2E real (Angular CLI + ngc + esbuild) y prueba manual en Chromium con la extensión cargada.

## Índice

- [Cuándo usar cada tipo](#cuándo-usar-cada-tipo)
- [Generar un adaptador](#generar-un-adaptador)
- [Integrarlo en el content script](#integrarlo-en-el-content-script)
- [Cómo se compila (AOT)](#cómo-se-compila-aot)
- [Estilos y tema Material](#estilos-y-tema-material)
- [Probarlo en Chrome y Firefox](#probarlo-en-chrome-y-firefox)
- [Proyectos existentes](#proyectos-existentes)
- [Historial de limitaciones](#historial-de-limitaciones)

## Cuándo usar cada tipo

| Tipo | Anclaje | Host | Uso típico |
|---|---|---|---|
| `Sidebar` | `document.body` | `fixed`, derecha, alto `100vh`, ancho `-Width` (360px), z-index máximo | Panel lateral sobre cualquier web |
| `Overlay` | `document.body` | `fixed` a pantalla completa con `pointer-events: none`; el panel (ancho `-Width`) centrado sí recibe clics | Modal o tarjeta flotante que no bloquea la página |
| `Inline` | `-TargetSelector` (`main`) o `body` | `relative`, bloque al principio del contenedor | Widget integrado en el contenido |

Todos los hosts llevan `all: initial` para que los estilos de la página no se hereden.

Si solo necesitas un panel propio del navegador (no dentro de la página), usa la API `side_panel` como en la plantilla `angular-mv3-demo` (ForgeNotes): no requiere content script ni Shadow DOM.

## Generar un adaptador

Desde el directorio del proyecto de la extensión (o con `-WorkspacePath`):

```powershell
./ruta/a/extension-forge/scripts/Add-ContentAdapter.ps1 -AdapterType Sidebar -ComponentName MiPanel -Width 24rem
./ruta/a/extension-forge/scripts/Add-ContentAdapter.ps1 -AdapterType Inline -TargetSelector '#content'
```

El Wizard (Herramientas Extra → AddAdapter) pide el tipo, el nombre del componente, el ancho (Sidebar/Overlay) y el selector (Inline).

| Archivo | Contenido | Si existe |
|---|---|---|
| `src/app/components/<kebab>/<kebab>.component.ts` | Componente standalone con `ViewEncapsulation.ShadowDom`, plantilla y estilos inline, botón Material de ejemplo | No se toca |
| `src/content-scripts/adapters/<tipo>-adapter.ts` | `bootstrap<Tipo>Adapter()`: crea el host, el Shadow Root y el tema, y arranca el componente con `createApplication()` (zoneless) | El script termina con aviso |
| `src/content-scripts/adapters/adapter-theme.scss` | Tema Material 3 en `:host` | No se toca |
| `src/content-scripts/scss.d.ts` | Tipos para importar `.scss` como texto | No se toca |

`-ComponentName` debe ir en PascalCase; el archivo y el selector usan kebab-case (`MiPanel` → `mi-panel.component.ts`, `app-mi-panel`). El script valida `-Width` (px, rem, em, vw, %) y rechaza selectores con comillas.

## Integrarlo en el content script

El script no modifica tu código; al terminar te indica las dos líneas que hay que añadir a `src/content.ts`:

```ts
import { bootstrapSidebarAdapter } from './content-scripts/adapters/sidebar-adapter';
void bootstrapSidebarAdapter();
```

No hace falta tocar `angular.json`. `content_scripts.matches` de `src/manifest.json` decide en qué páginas aparece (el build lo respeta, ver [production.md](production.md)). `bootstrap<Tipo>Adapter()` no monta dos veces si el host ya existe.

## Cómo se compila (AOT)

MV3 bloquea `eval` y `new Function`, que el compilador JIT de Angular necesita. Por eso `scripts/build-extension.mjs` (plantillas `angular-mv3` y `angular-mv3-demo`) compila el content script así cuando existe `tsconfig.content.json`:

1. `ngc -p tsconfig.content.json` compila `src/content.ts` y los componentes que importa en modo AOT completo a `out-tsc/content/`.
2. esbuild empaqueta `out-tsc/content/content.js` con dos plugins:
   - el linker de Angular (`@angular/compiler-cli/linker/babel` + `@babel/core`) completa las declaraciones parciales de Angular Material/CDK, igual que `ng build`;
   - los `.scss` importados se compilan con `sass` y se incrustan como texto.
3. En Production (`EXTFORGE_ENVIRONMENT=Production`, lo fija `Build-ExtensionForgeProject`) minifica y define `ngDevMode=false`.

Sin `tsconfig.content.json`, `content.ts` se empaqueta directamente con esbuild, como antes (válido para content scripts sin Angular). `Validate` en Production comprueba además que ningún bundle use `eval`/`new Function` (P-04).

Tamaño orientativo: el content script con el adaptador de ejemplo pesa unos 400 KB minificado (Angular + botón Material), frente a unos cientos de bytes sin adaptador.

## Estilos y tema Material

- Los estilos del componente y de Angular Material se insertan dentro del Shadow Root del componente (`ViewEncapsulation.ShadowDom`), no en el `<head>` de la página.
- El tema global de `src/styles.scss` se aplica sobre `html` y no atraviesa el Shadow DOM. `adapter-theme.scss` aplica `mat.theme` en `:host` del Shadow Root exterior; las variables `--mat-sys-*` se heredan hacia el componente. Ajusta ahí paletas y tipografía.
- La fuente Roboto no se descarga: se usa si la página o el sistema la tienen. MV3 no permite cargar fuentes remotas desde el content script sin declararlas; si la necesitas, empaquétala y declárala en `web_accessible_resources`.
- Las plantillas y estilos del componente deben ser inline (`template`, `styles`): `ngc` no procesa `templateUrl`/`styleUrl` con SCSS.

## Probarlo en Chrome y Firefox

1. `Invoke-ExtensionForge -Action Build -Browser All -Environment Development`.
2. Carga `dist/extension/chrome` y `dist/extension/firefox` (ver [development.md](development.md)).
3. En una web incluida en `matches`, comprueba en DevTools que existe `<ext-forge-<tipo>-host>` con `#shadow-root (open)` y, dentro, el componente con su propio Shadow Root.
4. Revisa la consola **de la página** (no la del popup): los errores del content script aparecen ahí.
5. Repite en Production.

Verificación realizada el 2026-09-28 en Chromium (Playwright, extensión cargada, Production), en páginas en modo estándar y en modo quirks:

| Comprobación | Resultado |
|---|---|
| Arranque del componente (sin «JIT compiler unavailable») | OK en Sidebar, Overlay e Inline |
| Sidebar | 360 × alto de ventana, pegado a la derecha |
| Overlay | Panel de 300 px centrado; un botón de la página fuera del panel sigue recibiendo clics |
| Inline | Primer hijo de `main`, ancho del contenedor |
| Botón Material | Color primario del tema (`#005cbb`), forma de píldora |
| Aislamiento | Un botón de la página con la misma clase `.ef-card` no cambia de estilo |
| Interacción | El contador del componente se actualiza al pulsar (señales, zoneless) |

Firefox no se ha probado en runtime en esta verificación; el E2E comprueba que su bundle también sale compilado con AOT.

Shadow DOM aísla estilos, **no** es una barrera de seguridad: la página anfitriona puede acceder a un Shadow Root `open`. No muestres ni guardes ahí datos sensibles.

## Proyectos existentes

`Initialize` sobre un proyecto con `angular.json` añade `tsconfig.content.json` si falta, pero **no sustituye** tu `scripts/build-extension.mjs` (regla de oro). Para usar adaptadores en un proyecto creado antes de este cambio:

1. Copia `tsconfig.content.json` y `scripts/build-extension.mjs` de `src/ExtensionForge/Templates/angular-mv3/` (fusiona a mano si personalizaste el script).
2. Añade `sass` y `@babel/core` a `devDependencies` (versiones de la plantilla) y ejecuta `npm install`.

## Historial de limitaciones

| Ref. | Limitación (hasta 2026-09-28) | Estado |
|---|---|---|
| A-01 | Importaba un componente en una ruta que no existía | ✅ El script genera el componente en la ruta que importa |
| A-02 | Nombre de archivo en minúsculas, no kebab-case | ✅ kebab-case (`extension-forge-widget`) |
| A-03 | esbuild compilaba `content.ts` sin AOT; el componente habría requerido JIT | ✅ ngc (AOT) + linker; verificado en Chromium |
| A-04 | El host solo fijaba `top`/`left` | ✅ Tamaño, posición y `pointer-events` por tipo; `-Width` y `-TargetSelector` |
| A-05 | Los estilos de Material no llegaban al Shadow Root | ✅ `ViewEncapsulation.ShadowDom` + tema en `:host` |
| A-06 | El Wizard no exponía los parámetros | ✅ Pide nombre, ancho y selector |
| DOC-01 | El aviso remitía a `entryPoints` de `angular.json` | ✅ Indica el import en `content.ts` |
