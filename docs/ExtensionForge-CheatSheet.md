# 🛠️ ExtensionForge — Hoja de Referencia de Comandos

Ciclo de vida completo de una extensión Angular + Angular Material (Manifest V3).

## 📦 1. Cmdlets del módulo (`Invoke-ExtensionForge`)

| Acción | Ejemplo | Efecto |
|---|---|---|
| **Doctor** | `Invoke-ExtensionForge -Action Doctor` | Verifica PowerShell 7.6.6+, Node 22+ y Angular CLI 22+. |
| **Initialize** | `Invoke-ExtensionForge -Action Initialize -Browser All -Environment Development` | Genera el scaffolding Angular + Angular Material (popup, background, content script, manifests). No sobrescribe. |
| **Build** | `Invoke-ExtensionForge -Action Build -Browser Chrome -Environment Production` | Compila Angular + esbuild y separa `dist/extension/<browser>`. |
| **Validate** | `Invoke-ExtensionForge -Action Validate -Environment Production` | Valida `manifest_version: 3` y CSP (sin `unsafe-eval`). |
| **Package** | `Invoke-ExtensionForge -Action Package -Browser Firefox -Environment Production` | Genera `.zip` (y `.xpi` para Firefox) en `dist/packages/`. |
| **InstallDev** | `Invoke-ExtensionForge -Action InstallDev -Browser All` | Instrucciones de sideload (Chrome) y `web-ext run` (Firefox). |

Parámetros:
- `-Browser`: `Chrome` | `Firefox` | `All` (por defecto `All`).
- `-Environment`: `Development` | `Staging` | `Production` (por defecto `Development`).
- `-WorkspacePath "C:\ruta\proyecto"` si no ejecutas desde la raíz del proyecto.

## 🤖 2. Scripts (`/scripts/`)

| Tarea | Comando |
|---|---|
| Wizard interactivo | `./scripts/Start-ExtensionForgeWizard.ps1` |
| Instalar módulo | `./scripts/Install-ExtensionForge.ps1 -Force` |
| Instalar en desarrollo (symlink) | `./scripts/Install-ExtensionForge.ps1 -Symlink` |
| Adaptador Shadow DOM | `./scripts/Add-ContentAdapter.ps1 -AdapterType Sidebar -ComponentName MiPanel -Width 360px` |
| CI local | `./scripts/Invoke-LocalCI.ps1` |
| CD local (producción) | `./scripts/Invoke-LocalCD.ps1` |
| Versionado SemVer | `./scripts/Invoke-SemVerRelease.ps1 -BumpType patch -DryRun` (previsualiza; `patch`/`minor`/`major` explícito) |
| Publicar en tiendas | `./scripts/Publish-ExtensionForgeStore.ps1 -Browser All -Version X.Y.Z` (`-WhatIf` para comprobar) |

## 🎯 3. Flujo completo (de 0 a tiendas)

```powershell
# 1. Wizard (recomendado): genera y ejecuta los comandos por ti
./scripts/Start-ExtensionForgeWizard.ps1

# 2. O manualmente:
npm install                                    # dependencias del proyecto Angular
Invoke-ExtensionForge -Action Doctor           # salud del entorno
Invoke-ExtensionForge -Action Initialize -Browser All -Environment Development
Invoke-ExtensionForge -Action Build -Browser All -Environment Development
./scripts/Invoke-LocalCI.ps1                   # pruebas pre-commit
./scripts/Invoke-LocalCD.ps1                   # versiona + build prod + valida + empaqueta

# 3. Publicación (requiere credenciales en variables de entorno)
./scripts/Publish-ExtensionForgeStore.ps1 -Browser All -Version X.Y.Z -WhatIf
./scripts/Publish-ExtensionForgeStore.ps1 -Browser All -Version X.Y.Z
```

## 🔑 4. Credenciales de tiendas (variables de entorno)

- **Chrome Web Store:** `CHROME_EXTENSION_ID`, `CHROME_CLIENT_ID`, `CHROME_CLIENT_SECRET`, `CHROME_REFRESH_TOKEN`.
- **Mozilla AMO:** `AMO_JWT_ISSUER`, `AMO_JWT_SECRET`.
