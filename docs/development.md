# ExtensionForge — Desarrollo local

> Guía de uso en caliente del módulo y de las extensiones que genera.
> Verificada contra el código del repositorio (commit `78bbe06`, módulo v2.1.0) y ejecutada el 2026-09-28 en Linux con PowerShell 7.6.6, Pester 6.2.0 y Node 22.23.3.

## Índice

- [Requisitos](#requisitos)
- [Preparar el módulo](#preparar-el-módulo)
- [Ciclo de trabajo de una extensión](#ciclo-de-trabajo-de-una-extensión)
- [Cargar la extensión en el navegador](#cargar-la-extensión-en-el-navegador)
- [Pruebas](#pruebas)
- [Problemas frecuentes](#problemas-frecuentes)

## Requisitos

| Herramienta | Versión | Comprobada por |
|---|---|---|
| PowerShell | 7.6.6+ | `ExtensionForge.psd1` (`PowerShellVersion`), Doctor y CI |
| Node.js | `^22.22.3`, `^24.15.0` o `>=26` | `engines` de la plantilla; Angular CLI 22 rechaza Node 20 |
| Angular CLI | 22.x | Doctor; plantillas con Angular / Material `^22.2.0` |
| Pester | 5+ | Suites de `tests/` |

> Con Node 20 la build falla con *"The Angular CLI requires a minimum Node.js version of v22.22.3…"*. Es la causa más habitual de un E2E rojo en local.

## Preparar el módulo

Trabaja siempre contra el módulo del repositorio, no contra una copia antigua de `PSModulePath`:

```powershell
Import-Module ./src/ExtensionForge/ExtensionForge.psd1 -Force
Invoke-ExtensionForge -Action Doctor
```

Para tenerlo disponible en cualquier consola mientras lo editas:

```powershell
./scripts/Install-ExtensionForge.ps1 -Symlink   # enlace: los cambios se ven al reimportar
./scripts/Install-ExtensionForge.ps1 -Force     # copia estable
```

El Wizard (`./scripts/Start-ExtensionForgeWizard.ps1`) importa siempre el módulo local con `-Force` y muestra el comando completo antes de ejecutarlo.

## Ciclo de trabajo de una extensión

Ejecuta los comandos **en el directorio del proyecto de la extensión**, nunca dentro del repositorio de ExtensionForge (`Initialize` lo impide con un guard).

```powershell
# 1. Scaffold (plantilla base o demo ForgeNotes)
Invoke-ExtensionForge -Action Initialize -Browser All -Environment Development -FirefoxExtensionId 'mi-extension@mi-dominio.dev'
Invoke-ExtensionForge -Action Initialize -Template angular-mv3-demo -Browser All -Environment Development

# 2. Dependencias (npm 12 puede exigir aprobar scripts nativos; ver problemas frecuentes)
npm install

# 3. Build por navegador → dist/extension/chrome y dist/extension/firefox
Invoke-ExtensionForge -Action Build -Browser All -Environment Development

# 4. Instrucciones de sideload (Chrome manual; Firefox con web-ext run)
Invoke-ExtensionForge -Action InstallDev -Browser All

# 5. Desarrollo con recarga automática: recompila al guardar y recarga la extensión
../extension-forge/scripts/Start-ExtensionForgeDev.ps1 -Browser Chrome
```

Detalle de la recarga y del `MessageService` tipado: [dev-reload-messaging.md](dev-reload-messaging.md).

Qué hace `Build` (según `Build-ExtensionForgeProject` e `Invoke-ExtensionForgeRuntimeBuild`):

1. `npx ng build --configuration <env> --output-hashing none --source-map=<bool> --optimization=<bool>`, con los valores de la configuración por capas.
2. `node scripts/build-extension.mjs <salida>`: compila `background.ts` y `content.ts` con esbuild (formato IIFE).
3. Por navegador: copia la salida a `dist/extension/<browser>`, genera el `manifest.json` específico y fusiona claves extra del `src/manifest.json` (por ejemplo `side_panel`, `options_ui`, `host_permissions`).
4. Escribe `dist/extension/.build-complete`, la señal del servidor de recarga. En Development con `Runtime.EnableHotReload`, `background.js` y `content.js` incluyen el cliente de recarga.

| Entorno | Configuración Angular | Optimización | SourceMaps | Log |
|---|---|---|---|---|
| Development | development | no | sí | `logs/dev.log` (Debug) |
| Staging | production | sí | sí | `logs/dev.log` (Info) |
| Production | production | sí | no | `logs/production.log` (Error) |

`npm run build:ext` (script de la plantilla) es un camino alternativo: genera la salida de Angular + bundles, pero **no** crea los directorios por navegador ni los manifests específicos. Para probar en navegadores usa `Invoke-ExtensionForge -Action Build`.

## Cargar la extensión en el navegador

- **Chrome:** `chrome://extensions` → Modo de desarrollador → *Cargar descomprimida* → `dist/extension/chrome`. Tras cada build, *↻ Recargar* (o usa `Start-ExtensionForgeDev.ps1`, que recarga sola). Chrome estable 137+ ignora `--load-extension`; para línea de comandos usa Chrome for Testing, Canary o Dev. Detalle: [carga-extension-navegador.md](carga-extension-navegador.md).
- **Firefox:** `about:debugging#/runtime/this-firefox` → *Cargar complemento temporal* → `dist/extension/firefox/manifest.json`, o `npx web-ext run --source-dir dist/extension/firefox` para recarga en vivo.

## Pruebas

```powershell
# CI local: compatibilidad 7.6.6 + Pester + Doctor + scaffold efímero
./scripts/Invoke-LocalCI.ps1

# Solo Pester (unitarias + integración simulada; el E2E se omite)
Invoke-Pester -Path ./tests -Output Detailed

# E2E real: Initialize → npm install → Build → Validate → Package (descarga dependencias; minutos)
$env:EXTFORGE_E2E = '1'; Invoke-Pester -Path ./tests/Integration -Tag E2E -Output Detailed
```

| Suite | Contenido | Resultado 2026-09-28 |
|---|---|---|
| `tests/Unit/Public` | Cmdlets exportados | ✅ |
| `tests/Unit/Private` | Deep merge de `Get-ExtensionForgeConfiguration` (18) | ✅ |
| `tests/Unit/Private` | `content_scripts` del manifest base en el build (7) | ✅ |
| `tests/Unit/Private` | ID de Firefox: formato, build, Validate e Initialize (22) | ✅ |
| `tests/Unit/Private` | Código dinámico/remoto y restos del cliente de recarga en bundles, `Validate` Production (16) | ✅ |
| `tests/Unit/Tools` | `Publish-ExtensionForgeStore` con `-WhatIf` (6), `Invoke-LocalCD` (5), `Add-ContentAdapter` (12) | ✅ |
| `tests/Unit/Tools` | Compatibilidad PowerShell 7.6.6 + `Invoke-SemVerRelease` (12) | ✅ |
| `tests/Integration` (simulada) | Pipeline con Angular CLI y esbuild simulados (15) | ✅ |
| `tests/Integration` (simulada) | Recarga en desarrollo y contrato de mensajes (9) | ✅ |
| `tests/Integration` E2E | Toolchain real, Node 22, incluido un adaptador Sidebar compilado con AOT | ✅ 5/5 |

Total sin E2E: 131 superadas, 0 fallidas, 5 omitidas (las E2E, que requieren `EXTFORGE_E2E=1`).

El E2E valida la build y los ZIP, **no** carga la extensión en un navegador real (el adaptador se verificó a mano en Chromium, ver [adapters.md](adapters.md)): prueba manualmente popup, background, content script, almacenamiento y mensajería en ambos navegadores.

## Problemas frecuentes

| Síntoma | Causa / solución |
|---|---|
| `Angular CLI requires a minimum Node.js version` | Actualiza a Node 22.22.3+ / 24.15+ |
| `npm install` bloquea postinstall (npm 12) | `npm install-scripts approve esbuild lmdb @parcel/watcher msgpackr-extract` |
| `Initialize` aborta dentro del repo | Guard anti-scaffold: usa un directorio de proyecto aparte |
| `$env:TEMP` vacío en Linux/macOS | Defínelo (`$env:TEMP = [IO.Path]::GetTempPath()`); el CI lo hace con `GITHUB_ENV` |
| Cambios del módulo no se reflejan | `Import-Module ./src/ExtensionForge/ExtensionForge.psd1 -Force` |
