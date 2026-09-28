# Changelog

Todos los cambios relevantes de **ExtensionForge** (el módulo PowerShell y sus scripts) se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); versionado [SemVer](https://semver.org/lang/es/).
Las extensiones generadas llevan su propio `CHANGELOG.md`, gestionado por `scripts/Invoke-SemVerRelease.ps1`.

## [Unreleased]

### Añadido
- Recarga en desarrollo: `scripts/Start-ExtensionForgeDev.ps1` (compila en Development, vigila `src/`/`public/` y recompila) y, en las plantillas, `scripts/dev-reload-server.mjs` (WebSocket `ws` en `127.0.0.1`, vigila `dist/extension/.build-complete`) y `src/dev/dev-reload.ts` (el background recarga la extensión con `chrome.runtime.reload()` y refresca las pestañas con content script). Nueva clave `Runtime.DevReloadPort` (35729); `Build` escribe `.build-complete` y solo incluye el cliente en Development con `EnableHotReload`. `Validate` Production rechaza restos del cliente. Verificado en Chromium.
- Plantilla `angular-mv3`: `MessageService` (`send`, `send$`, `sendWithOptions`), contrato `src/app/models/messages.model.ts` y utilidades `messaging.ts` (`sendExtensionMessage` con timeout y `ExtensionMessageError`, `registerMessageHandlers` con respuestas `{ ok, data | error }`). El popup de ejemplo usa `GET_INFO` y `PING`. `ws` pasa a `devDependencies`. `docs/dev-reload-messaging.md`. 10 pruebas nuevas.
- `docs/development.md`, `docs/production.md`, `docs/adapters.md` y `docs/release-process.md`.
- `tests/Unit/Tools/Invoke-SemVerRelease.Tests.ps1` (12 pruebas).
- Este `CHANGELOG.md`.
- Adaptadores Shadow DOM listos para usar (A-01…A-06, DOC-01): `Add-ContentAdapter.ps1` genera el componente (kebab-case, `ViewEncapsulation.ShadowDom`, plantilla inline), el adaptador con host dimensionado por tipo (`-Width`, `-TargetSelector`, `pointer-events` en Overlay), el tema Material 3 en `:host` y `scss.d.ts`; el Wizard pide sus parámetros. Las plantillas compilan el content script con AOT (`tsconfig.content.json` + ngc + linker de Angular + sass) y minifican en Production. `sass` y `@babel/core` pasan a `devDependencies`. 12 pruebas nuevas + caso E2E; verificado en Chromium.
- `Find-ExtensionForgeUnsafeCode` (privada) y `Validate` Production sobre bundles (P-04): `eval`, `new Function`, `Function('…')`, timers con cadena, `import()` y `<script>` remotos. 15 pruebas nuevas.

### Cambiado
- `scripts/Invoke-SemVerRelease.ps1` 2.2.0: valida `X.Y.Z` y la coincidencia manifest/package, rechaza versiones duplicadas en el changelog, escritura con rollback, `-WhatIf`/`-Confirm`, devuelve un objeto de resultado. `auto` queda obsoleto (equivale a `patch`).
- Wizard, Cheat Sheet y README: el versionado usa tipo explícito en lugar de `auto`.
- `DM-ExtensionForge.md` consolidado con las sesiones de Perplexity y la auditoría del 2026-09-28.
- Checklist de migración: documentación marcada como completada.

### Corregido
- El `background.ts` de la plantilla base devolvía `true` sin llamar nunca a `sendResponse`: cualquier `sendMessage` del popup se quedaba esperando.
- P-03: `Publish-ExtensionForgeStore.ps1` publica la versión de `-Version` o `package.json` (o `-PackagePath`), comprueba la versión del manifest dentro del ZIP y en `dist/extension/firefox`, y aborta antes de subir nada si no cuadra; ya no elige el ZIP más reciente por fecha. Añade `-WhatIf`. 6 pruebas nuevas.
- CD-01: `Invoke-LocalCD.ps1` aborta sin Git, con cambios, sin `tests/`, sin pruebas o con fallos (`-AllowNoGit`/`-AllowNoTests` explícitos), restaura manifest/package/CHANGELOG si Build/Validate/Package fallan, sustituye `Invoke-Pester -Quiet` (no admitido por Pester 6) por `-Output Minimal` y carga el módulo desde ExtensionForge. 5 pruebas nuevas.
- `Add-ContentAdapter.ps1`, `Publish-ExtensionForgeStore.ps1`, `Invoke-LocalCD.ps1` e `Invoke-SemVerRelease.ps1` usan el directorio actual como `WorkspacePath` por defecto (antes, la raíz de ExtensionForge, que no es un proyecto de extensión).
- P-02: ID de Firefox parametrizable. `Initialize`/`Invoke-ExtensionForge -FirefoxExtensionId` (y el Wizard) lo escriben en `src/manifest.json` sin sustituir un ID propio; el build fusiona `browser_specific_settings` del manifest base sobre la configuración; `Validate` rechaza ID ausente o inválido y, en Production, el marcador `extensionforge@ficticio.com`. Nueva función privada `Test-ExtensionForgeFirefoxId`. 22 pruebas nuevas.
- P-01: el build respeta los `content_scripts` de `src/manifest.json` (`matches`, `js`, `css`, `run_at`, varios bloques) en Chrome y Firefox, en lugar de forzar siempre `<all_urls>`. Array vacío omite la clave; un bloque sin `matches` hace fallar el build. 7 pruebas nuevas.
- SemVer calculaba `0.0.1` a partir de una versión inválida (se reutilizaba un `$Matches` obsoleto) y sobrescribía un `package.json` con versión distinta.

## [2.1.0] - 2026-09-28

Primera versión publicada en GitHub (commits `b9c036c` a `78bbe06`).

### Añadido
- Módulo `src/ExtensionForge` (7 cmdlets públicos, 7 funciones privadas, configuración PSD1 por capas con deep merge).
- Plantillas Angular 22.2 + Angular Material: `angular-mv3` y `angular-mv3-demo` (ForgeNotes).
- Scripts: Wizard, instalación, CI/CD local, SemVer, adaptadores de contenido, publicación en tiendas y validador de compatibilidad PowerShell 7.6.6.
- Tests Pester del deep merge (`9242bab`) e integración Initialize → Build → Validate → Package, simulada y E2E real (`5a96279`).
- READMEs de arquitectura lógica en `scripts/`, `src/ExtensionForge/`, `Public/` y `tests/` (`78bbe06`).

### Corregido
- Workflow CI: YAML válido y soporte Linux; `TEMP` definido mediante `GITHUB_ENV` (`91e92e5`, `940a81a`).
- Firefox: `action` en lugar de `browser_action` (MV2) en el manifest MV3 (`d4139b5`).

[Unreleased]: https://github.com/Frankystan/extension-forge/compare/78bbe06...HEAD
[2.1.0]: https://github.com/Frankystan/extension-forge/commits/78bbe06
