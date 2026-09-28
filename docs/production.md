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
- en Production, el manifest contiene `unsafe-eval` o `unsafe-inline`;
- en Firefox, falta `browser_specific_settings.gecko.id`, tiene formato inválido o, en Production, es el marcador de ejemplo.

La comprobación de CSP es textual sobre el manifest: no analiza el código JavaScript empaquetado.

## Manifest, permisos y CSP

| Navegador | Background | Acción | Extras |
|---|---|---|---|
| Chrome | `service_worker: background.js`, `type: module` | `action` | — |
| Firefox | `scripts: [background.js]` | `action` | `browser_specific_settings.gecko` (id, `strict_min_version 109.0`), permiso `contextMenus` |

Antes de publicar:

- **ID de Firefox (`gecko.id`):** obligatorio para firmar extensiones MV3; AMO no lo asigna y lo asocia a la extensión para siempre. Formatos válidos: `nombre@dominio` (≤ 80 caracteres, p. ej. `mi-extension@mi-dominio.dev`) o `{GUID}`. Defínelo de una de estas formas:
  - `Invoke-ExtensionForge -Action Initialize -FirefoxExtensionId 'mi-extension@mi-dominio.dev'` (o en el Wizard, que lo pregunta si el navegador incluye Firefox). Escribe `browser_specific_settings.gecko.id` en `src/manifest.json` y nunca sustituye un ID propio ya existente.
  - A mano en `src/manifest.json` → `browser_specific_settings.gecko.id`. El build fusiona ese bloque sobre `Config/browsers/firefox.psd1` (clave a clave), así que también puedes declarar `strict_min_version`, `gecko_android` o `data_collection_permissions`.

  `Validate` rechaza un paquete Firefox sin ID o con formato inválido, y en Production también el marcador de ejemplo `extensionforge@ficticio.com` (en Development solo avisa). Desde el 3 de noviembre de 2025, AMO exige además `gecko.data_collection_permissions` en las extensiones nuevas ([MDN](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/browser_specific_settings)).
- **`content_scripts` / `matches`:** el build copia tal cual los `content_scripts` de `src/manifest.json` (`matches`, `js`, `css`, `run_at`, varios bloques…) a los manifests de Chrome y Firefox. Si el base no define `content_scripts`, se usa el valor por defecto `<all_urls>` + `content.js`; un array vacío (`"content_scripts": []`) elimina la clave. Un bloque sin `matches` hace fallar el build. Las plantillas traen `<all_urls>`: sustitúyelo por los dominios que necesites, porque un patrón tan amplio aumenta la revisión de las tiendas.
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
| ~~P-01~~ | ~~`matches` fijo a `<all_urls>`~~ | ✅ Resuelto: se respetan los `content_scripts` de `src/manifest.json` |
| ~~P-02~~ | ~~ID gecko ficticio~~ | ✅ Resuelto: `-FirefoxExtensionId` / `src/manifest.json` + validación en `Validate` |
| P-03 | Publish elige el ZIP por fecha | Añadir `-Version` o `-PackagePath` explícito |
| P-04 | CSP comprobada solo en el manifest | Buscar `eval(`/`new Function` en los bundles de Production |
