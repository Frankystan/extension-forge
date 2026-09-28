# ExtensionForge — Producción, tiendas y CSP

> Reglas para generar un paquete publicable en Chrome Web Store y Mozilla Add-ons (AMO).
> Verificada contra el código del repositorio (commit `78bbe06`). Superar estas comprobaciones no garantiza la aprobación de las tiendas.

## Índice

- [Puertas de salida](#puertas-de-salida)
- [Build y validación de producción](#build-y-validación-de-producción)
- [Manifest, permisos y CSP](#manifest-permisos-y-csp)
- [Artefactos](#artefactos)
- [Publicación en tiendas](#publicación-en-tiendas)
- [Limitaciones conocidas](#limitaciones-conocidas)

## Puertas de salida

Un release solo es candidato si se cumplen **todas**:

1. `./scripts/Invoke-LocalCI.ps1` termina con código 0 y el CI remoto (incluido el job `e2e`) está en verde.
2. Árbol Git limpio y `src/manifest.json` y `package.json` con la misma versión (lo exige `Invoke-SemVerRelease.ps1` v2.2.0).
3. `Test-ExtensionForgePackage -Environment Production` devuelve `$true`.
4. Prueba manual en Chrome y Firefox del paquete final (no de `ng serve`).
5. Revisión humana del diff de permisos, `matches` y `host_permissions` respecto al release anterior.

## Build y validación de producción

```powershell
Invoke-ExtensionForge -Action Build    -Browser All -Environment Production
Invoke-ExtensionForge -Action Validate -Environment Production
Invoke-ExtensionForge -Action Package  -Browser All -Environment Production
```

Production aplica `Optimization`, `Aot` y `ExtractLicenses` y desactiva SourceMaps (`Config/environments/production.psd1`). El E2E comprueba que no quedan `.map` en los runtimes.

`Test-ExtensionForgePackage` falla (`$false`) si en algún `dist/extension/<browser>/manifest.json`:

- el JSON no es válido o falta el archivo;
- `manifest_version` no es 3;
- aparecen claves MV2 (`browser_action`, `page_action`);
- en Production, el manifest contiene `unsafe-eval` o `unsafe-inline`.

La comprobación de CSP es textual sobre el manifest: no analiza el código JavaScript empaquetado.

## Manifest, permisos y CSP

| Navegador | Background | Acción | Extras |
|---|---|---|---|
| Chrome | `service_worker: background.js`, `type: module` | `action` | — |
| Firefox | `scripts: [background.js]` | `action` | `browser_specific_settings.gecko` (id, `strict_min_version 109.0`), permiso `contextMenus` |

Antes de publicar:

- **ID de Firefox:** `Config/browsers/firefox.psd1` usa el marcador `extensionforge@ficticio.com`. Sustitúyelo por un ID propio y estable; AMO lo asocia a la extensión para siempre.
- **`<all_urls>`:** `New-ExtensionForgeManifest` genera siempre `content_scripts.matches = ["<all_urls>"]`, y `content_scripts` está en la lista de claves que el build **no** toma de `src/manifest.json`. Verificado el 2026-09-28: un `src/manifest.json` con `matches: ["https://example.com/*"]` produce `<all_urls>` en `dist/extension/chrome/manifest.json` (las claves extra como `side_panel` sí se conservan). No basta con cambiar `matches` en tu manifest base: hay que ajustar el generador o la configuración. Un patrón tan amplio aumenta la revisión de las tiendas.
- **Permisos:** base `storage`, `activeTab` (+ `contextMenus` en Firefox) unidos sin duplicados a los de `src/manifest.json`. Elimina los que no uses.
- **Background IIFE + `type: module`:** esbuild genera bundles IIFE; son válidos como módulo mientras no usen `import`/`export` de nivel superior. Verifica la carga del service worker en `chrome://extensions` (enlace *service worker*).
- No incluyas credenciales, endpoints internos, logs ni dependencias de desarrollo en `dist/extension/*`.

## Artefactos

```text
dist/extension/chrome/                    → carpeta cargable y fuente del ZIP Chrome
dist/extension/firefox/                   → carpeta cargable y fuente del ZIP/XPI Firefox
dist/packages/extensionforge-chrome-vX.Y.Z.zip
dist/packages/extensionforge-firefox-vX.Y.Z.zip (+ .xpi, mismo contenido)
```

La versión del nombre se lee de `package.json`. El `manifest.json` queda en la raíz del ZIP (verificado por el E2E). El `.xpi` es el ZIP renombrado: **sin firmar**, solo cargable en Developer Edition/Nightly con `xpinstall.signatures.required=false`.

## Publicación en tiendas

`scripts/Publish-ExtensionForgeStore.ps1` **publica de verdad** cuando encuentra credenciales:

| Tienda | Herramienta | Variables de entorno |
|---|---|---|
| Chrome Web Store | `npx chrome-webstore-upload upload … --auto-publish` | `CHROME_EXTENSION_ID`, `CHROME_CLIENT_ID`, `CHROME_CLIENT_SECRET`, `CHROME_REFRESH_TOKEN` |
| AMO | `npx web-ext sign --channel listed\|unlisted` | `AMO_JWT_ISSUER`, `AMO_JWT_SECRET` |

Cautelas:

- Chrome sube el `extensionforge-chrome-v*.zip` **más reciente por fecha de modificación**, no necesariamente el validado. Deja en `dist/packages/` solo el ZIP que quieres publicar.
- `--auto-publish` envía a revisión y publica sin paso intermedio; para revisión manual, sube desde el panel del desarrollador.
- Firefox firma desde `dist/extension/firefox`, no desde el ZIP.
- Si faltan credenciales solo hay advertencias: comprueba el resultado por tienda.
- Nunca guardes los valores de estas variables en el repositorio, documentación o chat; usa GitHub Secrets o el almacén de credenciales del sistema.

## Limitaciones conocidas

| Ref. | Limitación | Propuesta |
|---|---|---|
| P-01 | `matches` fijo a `<all_urls>` | Leer `content_scripts` de `src/manifest.json` o de `Manifest.ContentScripts` en la configuración |
| P-02 | ID gecko ficticio | Parametrizarlo por proyecto y validar en `Validate` que no contenga `ficticio` |
| P-03 | Publish elige el ZIP por fecha | Añadir `-Version` o `-PackagePath` explícito |
| P-04 | CSP comprobada solo en el manifest | Buscar `eval(`/`new Function` en los bundles de Production |
