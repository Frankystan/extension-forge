# ExtensionForge — Adaptadores de content script (Shadow DOM)

> Cómo usar `scripts/Add-ContentAdapter.ps1` para montar una UI dentro de páginas de terceros sin fugas de CSS.
> Verificada por lectura del script en el commit `78bbe06`. **El montaje de Angular dentro del content script no está cubierto por ninguna prueba automática.**

## Índice

- [Cuándo usar cada tipo](#cuándo-usar-cada-tipo)
- [Generar un adaptador](#generar-un-adaptador)
- [Integrarlo en el build](#integrarlo-en-el-build)
- [Probarlo en Chrome y Firefox](#probarlo-en-chrome-y-firefox)
- [Limitaciones del generador](#limitaciones-del-generador)

## Cuándo usar cada tipo

| Tipo | Anclaje | Posición | z-index | Uso típico |
|---|---|---|---|---|
| `Sidebar` | `document.body` | `fixed` | `2147483647` | Panel lateral sobre cualquier web |
| `Overlay` | `document.body` | `absolute` | `999999` | Modal, tooltip o capa flotante |
| `Inline` | `main` o `body` | `absolute` | `1000` | Widget integrado en el contenido |

Si solo necesitas un panel propio del navegador (no dentro de la página), usa la API `side_panel` como en la plantilla `angular-mv3-demo` (ForgeNotes): no requiere content script ni Shadow DOM.

## Generar un adaptador

```powershell
./scripts/Add-ContentAdapter.ps1 -WorkspacePath <proyecto> -AdapterType Sidebar -ComponentName ExtensionForgeWidget
```

Crea `src/content-scripts/adapters/<tipo>-adapter.ts` con una función `bootstrap<Tipo>Adapter()` que:

1. Crea el host `<ext-forge-<tipo>-host>` y lo añade al anclaje.
2. Adjunta un Shadow Root en modo `open`.
3. Arranca el componente con `createApplication()` + `appRef.bootstrap()` dentro del Shadow Root.

Si el archivo existe, no lo sobrescribe (regla de oro) y termina con un aviso.

## Integrarlo en el build

El aviso final del script («añádelo a los `entryPoints` de `angular.json`») **no corresponde al build actual**: `Build-ExtensionForgeProject` compila `background.ts` y `content.ts` con `scripts/build-extension.mjs` (esbuild), no con `entryPoints` de Angular. La integración correcta es importar el adaptador desde `content.ts`:

```ts
// src/content.ts
import { bootstrapSidebarAdapter } from './content-scripts/adapters/sidebar-adapter';
bootstrapSidebarAdapter();
```

El manifest generado ya declara `content.js` en `content_scripts`; no hace falta otra entrada.

## Probarlo en Chrome y Firefox

1. `Invoke-ExtensionForge -Action Build -Browser All -Environment Development`.
2. Carga `dist/extension/chrome` y `dist/extension/firefox` (ver [development.md](development.md)).
3. En una web cualquiera, comprueba en DevTools que existe el host con `#shadow-root (open)` y que los estilos de la página no alteran el componente.
4. Revisa la consola **de la página** (no la del popup): los errores del content script aparecen ahí.
5. Repite en Production: la optimización puede romper código que funcionaba en Development.

Shadow DOM aísla estilos, **no** es una barrera de seguridad: la página anfitriona puede acceder a un Shadow Root `open`. No muestres ni guardes ahí datos sensibles.

## Limitaciones del generador

| Ref. | Limitación | Consecuencia / propuesta |
|---|---|---|
| A-01 | Importa `../../app/components/<nombre>/<nombre>.component`, ruta que no existe en las plantillas (`app/app.component.ts`, `app/popup/…`) | Crear el componente en esa ruta o corregir el import |
| A-02 | El nombre de archivo es el nombre en minúsculas (`extensionforgewidget`), no kebab-case | Ajustar a la convención Angular (`extension-forge-widget`) |
| A-03 | esbuild compila `content.ts` sin el compilador AOT de Angular | Un componente Angular en el content script puede requerir JIT (`@angular/compiler`) o un paso AOT específico: **pendiente de verificar** |
| A-04 | El host solo fija `top`/`left`; sin ancho/alto ni `pointer-events` | Definir tamaño y estilos del host para Sidebar/Overlay |
| A-05 | Los estilos de Angular Material no se inyectan en el Shadow Root automáticamente | Añadir el CSS del tema dentro del Shadow Root |
| A-06 | El Wizard no expone Overlay/Inline con todos sus parámetros | Usar el script directamente |

Hasta resolver A-01 y A-03, trata el adaptador como plantilla de partida, no como funcionalidad lista para producción.
