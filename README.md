# 🚀 ExtensionForge

**ExtensionForge** es un módulo de **PowerShell 7.6.6+** que automatiza la creación, el desarrollo, el empaquetado y el despliegue de **extensiones de navegador (Manifest V3)** construidas con **Angular + Angular Material**, compatibles con **Google Chrome** y **Mozilla Firefox**.

Incluye un **Wizard interactivo** que te guía desde el inicio hasta el scaffolding completo, para que te centres en el código y el diseño sin preocuparte por la compatibilidad ni los requisitos de cada tienda.

---

## ✨ Qué hace por ti

- ✅ **Doctor** — verifica que tu entorno cumple los requisitos (PowerShell 7.6.6+, Node 22+, Angular CLI 22+).
- 🏗️ **Initialize** — genera el proyecto Angular + Angular Material con `popup`, `background` (Service Worker / Background Script), `content script`, `manifest.json` y scripts de build. **Nunca sobrescribe tu código** (regla de oro).
- 🔨 **Build** — compila Angular y los scripts de fondo/contenido, separando la salida por navegador (`dist/extension/chrome` y `dist/extension/firefox`).
- ✅ **Validate** — valida `manifest_version: 3` y CSP (rechaza `unsafe-eval`/`unsafe-inline`).
- 📦 **Package** — genera `.zip` listos para las tiendas (y `.xpi` para Firefox).
- 🧪 **InstallDev** — instrucciones de sideload en caliente (Chrome) y `web-ext run` (Firefox).
- 🌍 **Publicación** — script para publicar en **Chrome Web Store** y **Mozilla Add-ons** con credenciales por variables de entorno.

---

## 📋 Requisitos

| Herramienta | Versión mínima |
|---|---|
| PowerShell | **7.6.6+** (Core) |
| Node.js | 22+ (≥22.22.3 recomendado; también 24/26) |
| Angular CLI | 22+ (se usa vía `npx`, no hace falta instalarlo global) |

> Nota: el proyecto histórico citaba PowerShell 6.6+/7.6+. ExtensionForge se ha normalizado a **7.6.6+**; usa solo sintaxis compatible con PowerShell Core 7.6.6 y posteriores, garantizado por `scripts/Test-ExtensionForgePowerShellCompatibility.ps1`.

---

## ⚙️ Instalación del módulo

Desde la carpeta del repositorio:

```powershell
# Instalación limpia (copia al PSModulePath del usuario)
./scripts/Install-ExtensionForge.ps1 -Force

# O instalación de desarrollo (Junction: edita src/ y recarga al instante)
./scripts/Install-ExtensionForge.ps1 -Symlink
```

Después, en cualquier sesión nueva:

```powershell
Import-Module ExtensionForge
Get-Command -Module ExtensionForge   # lista los 7 cmdlets
```

---

## 🔤 Alias del perfil (accesos rápidos)

Para invocar ExtensionForge desde cualquier directorio, añade estos atajos a tu perfil de PowerShell (`notepad $PROFILE`) y recarga con `. $PROFILE`:

```powershell
# === ExtensionForge — accesos rápidos ===
function ef-wizard  { & 'C:\Dev\extension-forge\scripts\Start-ExtensionForgeWizard.ps1' }
Set-Alias -Name ef -Value Invoke-ExtensionForge

# Acciones frecuentes (argumentos ya incluidos)
function ef-init    { Invoke-ExtensionForge -Action Initialize -Browser All -Environment Development }
function ef-init-demo { Invoke-ExtensionForge -Action Initialize -Template angular-mv3-demo -Browser All -Environment Development }
function ef-build   { Invoke-ExtensionForge -Action Build      -Browser All -Environment Development }
function ef-package { Invoke-ExtensionForge -Action Package    -Browser All -Environment Production }

# Scripts auxiliares (archivos .ps1)
function ef-localci { & 'C:\Dev\extension-forge\scripts\Invoke-LocalCI.ps1' }
function ef-semver  { & 'C:\Dev\extension-forge\scripts\Invoke-SemVerRelease.ps1' }
```

> **Regla:** usa `Set-Alias` para renombrar un comando (sin argumentos) y `function` cuando necesitas argumentos fijos (como `ef-init`). Los scripts `.ps1` se invocan con `& 'ruta\script.ps1'`. Ajusta `C:\Dev\extension-forge` a la ruta real de tu checkout.

---

## 🌟 Empezar con el Wizard (recomendado)

Desde la carpeta del repositorio:

```powershell
./scripts/Start-ExtensionForgeWizard.ps1
```

Desde tu directorio de proyecto (o con el alias `ef-wizard`):

```powershell
C:\Dev\extension-forge\scripts\Start-ExtensionForgeWizard.ps1
```

El asistente te pregunta qué quieres hacer (Doctor, Initialize, Build, Validate, Package, InstallDev), el navegador destino y el entorno. **Genera el comando exacto** y te pregunta si quieres ejecutarlo. Incluye un **Glosario / Cheat Sheet** embebido (opción "📖 Ver Glosario / Cheat Sheet").

---

## 🚀 Uso rápido manual

```powershell
# 1. Verifica tu entorno
Invoke-ExtensionForge -Action Doctor

# 2. Crea el scaffolding (Angular + Angular Material + MV3) en la carpeta actual
Invoke-ExtensionForge -Action Initialize -Browser All -Environment Development -FirefoxExtensionId 'mi-extension@mi-dominio.dev'

# 3. Instala dependencias del proyecto generado
npm install
#    (npm 12 puede bloquear scripts nativos → ver "Solución de problemas", allowScripts)

# 4. Compila
Invoke-ExtensionForge -Action Build -Browser All -Environment Development
#    o, mientras desarrollas, recompila al guardar y recarga la extensión sola:
#    <ruta-a-extension-forge>/scripts/Start-ExtensionForgeDev.ps1 -Browser Chrome

# 5. Valida antes de publicar
Invoke-ExtensionForge -Action Validate -Environment Production

# 6. Empaqueta (ZIP + XPI) para las tiendas
Invoke-ExtensionForge -Action Package -Browser All -Environment Production

# 7. Carga en desarrollo (sideload)
Invoke-ExtensionForge -Action InstallDev -Browser All
```

## 🧭 Cargar la extensión en el navegador

- **Manual (recomendado):** `chrome://extensions` → "Modo de desarrollador" → "Cargar descomprimida" → selecciona `dist/extension/chrome`.
- **Por línea de comandos** (Chrome estable 137+ ignora `--load-extension`; usa Chrome for Testing, Canary o Dev):
  ```powershell
  & "C:\chromeDriver\chrome.exe" --user-data-dir="$env:TEMP\forge-chrome" --load-extension="C:\<tu-proyecto>\dist\extension\chrome"
  ```

### En un proyecto Angular ya existente

`Initialize` detecta tu `angular.json` y **solo añade lo que falta** (background.ts, content.ts, manifest.json, scripts de build) y parchea `angular.json`/`package.json` sin tocar tu código.

---

## 📦 Estructura del repositorio

```text
extension-forge/
├─ src/ExtensionForge/          # Módulo de PowerShell
│  ├─ ExtensionForge.psd1       # Manifiesto
│  ├─ ExtensionForge.psm1       # Loader
│  ├─ Public/                   # 7 cmdlets exportados
│  ├─ Private/                  # 7 helpers internos
│  ├─ Config/                   # defaults + environments/ + browsers/ (deep merge)
│  └─ Templates/                # Plantillas Angular + Angular Material MV3
│     ├─ angular-mv3/           # Base (popup + background + content script)
│     └─ angular-mv3-demo/      # Demo ForgeNotes (popup + sidepanel + options)
├─ scripts/                     # Wizard, instalación, CI/CD, SemVer, adaptadores, publicación, compatibilidad
├─ examples/                    # Proyectos de ejemplo ya generados (base + demo)
├─ tests/                       # Pester (Unit/Public, Unit/Tools)
├─ docs/                        # Cheat sheet, carga en navegador, checklist migración
├─ .private/                    # Backup local + legado Perplexity (perx/)
├─ .github/workflows/           # CI multiplataforma
└─ README.md
```

## 📚 Ejemplos

El repositorio incluye dos proyectos de ejemplo ya generados (listos para `npm install` + `Build`):

- `examples/extension-forge-demo/` — plantilla **base** (popup + background + content script).
- `examples/forgenotes-demo/` — plantilla **demo ForgeNotes** (popup + sidepanel + options + content script), para aprender cómo se comunican las superficies.

Para probar la demo ForgeNotes en Chrome:

```powershell
cd examples/forgenotes-demo
npm install
Invoke-ExtensionForge -Action Build -Browser Chrome -Environment Development
Invoke-ExtensionForge -Action InstallDev -Browser Chrome   # instrucciones de carga
```

---

## 🌍 Publicación en las tiendas

1. Empaqueta: `Invoke-ExtensionForge -Action Package -Browser All -Environment Production`.
2. Define las credenciales como **variables de entorno** (nunca se incrustan secretos):
   - **Chrome Web Store:** `CHROME_EXTENSION_ID`, `CHROME_CLIENT_ID`, `CHROME_CLIENT_SECRET`, `CHROME_REFRESH_TOKEN`.
   - **Mozilla AMO:** `AMO_JWT_ISSUER`, `AMO_JWT_SECRET`.
3. Publica:

```powershell
./scripts/Publish-ExtensionForgeStore.ps1 -Browser All -Version 1.4.0 -WhatIf  # qué se publicaría
./scripts/Publish-ExtensionForgeStore.ps1 -Browser All -Version 1.4.0          # ambas tiendas
./scripts/Publish-ExtensionForgeStore.ps1 -Browser Firefox -FirefoxChannel unlisted  # solo AMO, distribución propia
```

---

## 🔧 Configuración por capas

La configuración se compone por *deep merge* de tres capas (`Config/`):

- `defaults.psd1` — rutas, Angular, scaffold, manifest base.
- `environments/{development,staging,production}.psd1` — optimización, source maps, hot reload.
- `browsers/{chrome,firefox}.psd1` — `service_worker` vs `scripts`, `action` en ambos (MV3), `gecko.id`.

---

## 🧪 Calidad y CI/CD

- **Compatibilidad PowerShell:** `./scripts/Test-ExtensionForgePowerShellCompatibility.ps1` valida todos los scripts contra el piso 7.6.6 (`-Normalize` autocorrige declaraciones de versión).
- **CI local:** `./scripts/Invoke-LocalCI.ps1` (Pester + Doctor + dry-run de scaffold).
- **Desarrollo:** `Start-ExtensionForgeDev.ps1` recompila al guardar y recarga extensión y pestañas; la plantilla trae `MessageService` con contrato de mensajes tipado y `SettingsService` con preferencias en `chrome.storage.local`. Ver [docs/dev-reload-messaging.md](docs/dev-reload-messaging.md) y [docs/storage.md](docs/storage.md).
- **CD local:** `./scripts/Invoke-LocalCD.ps1` desde el proyecto de la extensión (Git limpio → Pester → SemVer → Build Prod → Validate → Package). Aborta sin Git o sin `tests/` y revierte la versión si el build falla.
- **Versionado:** `./scripts/Invoke-SemVerRelease.ps1 -BumpType patch -DryRun` (previsualiza; el tipo `patch`/`minor`/`major` es explícito). Ver [docs/release-process.md](docs/release-process.md).
- **CI remota:** `.github/workflows/extension-forge-ci.yml` (Ubuntu + Windows, Node 22/24).

---

## ❓ Solución de problemas

- **"npx ng build" no encuentra ng** → ejecuta `npm install` dentro del proyecto generado.
- **Doctor marca Angular CLI** → no es bloqueante: `npx` lo resolverá en cada build.
- **Build no encuentra `index.html`** → revisa el `outputPath` de tu `angular.json`.
- **Publicación Chrome** → revisa que `CHROME_*` estén definidas y el `CHROME_EXTENSION_ID` coincida con el ítem en el Developer Dashboard.
- **`npm install` falla por `allowScripts`** (npm 12 bloquea los scripts postinstall de las dependencias nativas del toolchain Angular) → aprueba y reinstala:

  ```powershell
  npm install-scripts approve esbuild lmdb @parcel/watcher msgpackr-extract
  npm install
  ```

  Como alternativa, aprueba todo de golpe: 
  ```powershell
  npm install-scripts approve --all
  npm install
  ```
  
  O .. manualmente en `package.json` (por nombre, para cubrir futuras versiones):

  ```json
  "allowScripts": {
    "esbuild": true,
    "lmdb": true,
    "@parcel/watcher": true,
    "msgpackr-extract": true
  }
  ```

  > Nota de seguridad: aprueba solo paquetes de confianza. Estos 4 son parte estándar del toolchain de Angular/Vite.

---

*Principio de robustez: "No sobrescribir código nativo del desarrollador salvo orden explícita."*
