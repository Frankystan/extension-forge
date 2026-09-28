# 🚀 ExtensionForge v2.0 - Checklist de Migración Arquitectónica

Este documento interactivo te permite hacer seguimiento del progreso de migración desde los *scripts sueltos (v1.x)* hacia el **Módulo Formal de PowerShell de Nivel Corporativo (v2.0)**. 

---

## 📂 1. Core del Módulo (`src/ExtensionForge/`)
El corazón del sistema. Declaración, exportación y enrutamiento principal.

- [x] **`ExtensionForge.psd1`**: Manifiesto del módulo (Versión, dependencias de PowerShell 7.6, funciones exportadas).
- [x] **`ExtensionForge.psm1`**: Cargador principal (RootModule que inyecta `Public/` y `Private/`).

---

## ⚙️ 2. Motor de Configuración (`src/ExtensionForge/Config/`)
Variables y switches separados del código.

- [x] **`defaults.psd1`**: Base de rutas universales y configuración Angular genérica.
- [x] **`environments/development.psd1`**: Activación de SourceMaps y Hot Reload.
- [x] **`environments/production.psd1`**: Activación de minificación estricta y eliminación de SourceMaps.
- [x] **`browsers/chrome.psd1`**: Configuración de `service_worker` (MV3).
- [x] **`browsers/firefox.psd1`**: Híbrido de `background scripts` y claves exclusivas de Addons (Gecko ID).

---

## 🔒 3. Lógica Privada (`src/ExtensionForge/Private/`)
Funciones internas que no se exponen al usuario final.

- [x] **`Get-ExtensionForgeConfiguration.ps1`**: Función de Deep Merge para fusionar las dimensiones (Base + Env + Browser).
- [x] **`Write-ExtensionForgeLog.ps1`**: Estandarización de salidas por consola y logs rotativos en formato JSONL (`dev.log` / `production.log`).
- [x] **`Test-ExtensionForgeTool.ps1`**: Abstracción para verificar si comandos como `ng` o `npm` existen.
- [x] **`Invoke-ExtensionForgeRuntimeBuild.ps1`**: Extrae la manipulación bruta del manifest.json desde el script de Build.
- [x] **`Invoke-ExtensionForgeFirefoxAdapter.ps1`**: Generación específica de adaptadores Firefox.
- [x] **`Invoke-ExtensionForgeChromeAdapter.ps1`**: Generación específica de adaptadores Chrome.
- [x] **`New-ExtensionForgeManifest.ps1`**: Creador dinámico de JSON exclusivo.

---

## 🌍 4. Lógica Pública exportada (`src/ExtensionForge/Public/`)
Cmdlets oficiales disponibles en la consola del usuario.

- [x] **`Invoke-ExtensionForge.ps1`**: CLI general/Wrapper (`-Action Build -Environment Production`).
- [x] **`Test-ExtensionForgeDoctor.ps1`**: Verifica salud del entorno (PowerShell, NodeJS, Angular CLI).
- [x] **`Initialize-ExtensionForgeProject.ps1`**: Scaffolding sin sobreescribir `angular.json`.
- [x] **`Build-ExtensionForgeProject.ps1`**: Orquesta a Angular CLI y separa en carpetas por navegador.
- [x] **`Test-ExtensionForgePackage.ps1`**: Analiza el CSP y la validación estricta de MV3.
- [x] **`New-ExtensionForgePackage.ps1`**: Comprime automáticamente usando nomenclatura SemVer desde el `package.json`.
- [x] **`Install-ExtensionForgeDevelopment.ps1`**: Prepara y documenta comandos de Sideload (incluyendo `web-ext` para Firefox).

---

## 🛠️ 5. Scripts de Orquestación y CI/CD (`scripts/` y `.github/`)
Pipelines y envolturas para consumos externos.

- [x] **`.github/workflows/extension-forge-ci.yml`**: Flujo GitHub Actions (Multi-OS, Node 20.x, Dry-runs). *(Creado en la fase 1, listo para mover a `.github/workflows/`)*.
- [x] **`Invoke-SemVerRelease.ps1`**: Automatización de versión usando el log JSONL. *(Creado en la fase 1, listo para ser renombrado y movido a `scripts/`)*.
- [x] **`Invoke-LocalCD.ps1`**: Despliegue seguro manual. *(Creado en la fase 1, listo para ser renombrado y movido a `scripts/`)*.
- [x] **`Add-ContentAdapter.ps1`**: Inyector Shadow DOM (Sidebar, Overlay). *(Creado en la fase 1, listo para ser renombrado y movido a `scripts/`)*.
- [x] **`Start-ExtensionForgeWizard.ps1`**: Menú Interactivo (Generador de comandos y Cheat Sheet).
- [x] **`Install-ExtensionForge.ps1`**: Script que instala este módulo en el `$env:PSModulePath` del sistema o del usuario para que esté siempre disponible.
- [x] **`Invoke-LocalCI.ps1`**: Script que corre localmente los mismos pasos que GitHub Actions antes del push.

---

## 🧪 6. Testing y Calidad (`tests/`)
Pruebas Pester.

- [x] **Tests Pester (Base)**: Validación de CLI antigua y Logging. *(Creado en fase 1, listo para dividir)*.
- [x] **`tests/Unit/Public/*.tests.ps1`**: Tests base para validar los Cmdlets exportados.
- [x] **`tests/Unit/Private/*.tests.ps1`**: Tests del Deep Merge (`Get-ExtensionForgeConfiguration`): 18 pruebas en `tests/Unit/Private/Get-ExtensionForgeConfiguration.Tests.ps1` (Config real + fixtures aislados).
- [ ] **`tests/Integration/*.tests.ps1`**: (Pendiente) Pruebas de punta a punta (Desde Initialize hasta Package).

---

## 📝 7. Documentación (`docs/`)
- [x] **`ExtensionForge-CheatSheet.md`**: Hoja de referencia de comandos (Markdown).
- [x] **`README.md`**: Fachada principal del repositorio y arquitectura.
- [ ] **`development.md`**: (Pendiente) Guía de uso en caliente.
- [ ] **`production.md`**: (Pendiente) Reglas estrictas de stores y CSP.
- [ ] **`adapters.md`**: (Pendiente) Cómo usar el inyector Shadow DOM.
- [ ] **`release-process.md`**: (Pendiente) Pasos para publicar una nueva versión con SemVer.
- [ ] **`CHANGELOG.md`**: (Pendiente) Historial unificado.

---

## 🗑️ 8. Limpieza Histórica (Migración y Archivo)
Mover scripts viejos a `scripts/archive/` o `scripts/migrations/`.

- [x] Retirar `New-ExtensionForgeScaffold.v1.0.0.ps1`.
- [x] Retirar `Update-ExtensionForgeBuild.v1.1.0.ps1`.
- [x] Retirar `Repair-ExtensionForgeModuleRoot.v1.1.1.ps1`.
- [x] Retirar `Add-ExtensionForgeInstallDev.v1.2.0.ps1`.
- [x] Retirar `Initialize-ExtensionForgeAngularMv3.v1.3.0.ps1`.
- [x] Retirar `Repair-InitializeExtensionForgeAngularMv3.v1.3.1.ps1`.
- [x] Retirar `Invoke-ExtensionForgeUnifiedBuild.v1.4.0.ps1`.
- [x] Retirar `Upgrade-ExtensionForgeUnifiedWorkflow.v1.5.0.ps1`.
- [x] Retirar `Invoke-ExtensionForgeValidatePackage.v1.6.0.ps1`.
- [x] Retirar `extension-ci-cd-v1.0.0.yml`.
- [x] Retirar CLI monólitos intermedios (v1.7.0, v1.13.0).