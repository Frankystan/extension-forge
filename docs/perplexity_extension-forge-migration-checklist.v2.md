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

- [x] **`.github/workflows/extension-forge-ci.yml`**: Flujo GitHub Actions (Ubuntu + Windows, Node 22.x/24.x, PowerShell 7.6.6+) con job `e2e` real.
- [x] **`Invoke-SemVerRelease.ps1`**: v2.2.0 — incremento explícito `patch/minor/major` (`auto` obsoleto = `patch`), validación estricta, rollback y 12 pruebas en `tests/Unit/Tools/Invoke-SemVerRelease.Tests.ps1`.
- [x] **`Invoke-LocalCD.ps1`**: Despliegue seguro manual (Git limpio → Pester → SemVer → Build/Validate/Package Production).
- [x] **`Add-ContentAdapter.ps1`**: Inyector Shadow DOM (Sidebar, Overlay, Inline). Limitaciones A-01…A-06 en `docs/adapters.md`.
- [x] **`Start-ExtensionForgeWizard.ps1`**: Menú Interactivo (Generador de comandos y Cheat Sheet).
- [x] **`Install-ExtensionForge.ps1`**: Script que instala este módulo en el `$env:PSModulePath` del sistema o del usuario para que esté siempre disponible.
- [x] **`Invoke-LocalCI.ps1`**: Script que corre localmente los mismos pasos que GitHub Actions antes del push.

---

## 🧪 6. Testing y Calidad (`tests/`)
Pruebas Pester.

- [x] **Tests Pester (Base)**: Validación de CLI antigua y Logging. *(Creado en fase 1, listo para dividir)*.
- [x] **`tests/Unit/Public/*.tests.ps1`**: Tests base para validar los Cmdlets exportados.
- [x] **`tests/Unit/Private/*.tests.ps1`**: Tests del Deep Merge (`Get-ExtensionForgeConfiguration`): 18 pruebas en `tests/Unit/Private/Get-ExtensionForgeConfiguration.Tests.ps1` (Config real + fixtures aislados).
- [x] **`tests/Integration/*.tests.ps1`**: Pipeline Initialize → Build → Validate → Package: `ExtensionForge-Pipeline.Tests.ps1` (15 pruebas; simula solo Angular CLI y esbuild) y `ExtensionForge-Pipeline.E2E.Tests.ps1` (4 pruebas con toolchain real; job `e2e` del CI).

---

## 📝 7. Documentación (`docs/`)
- [x] **`ExtensionForge-CheatSheet.md`**: Hoja de referencia de comandos (Markdown).
- [x] **`README.md`**: Fachada principal del repositorio y arquitectura.
- [x] **`development.md`**: Guía de uso en caliente (requisitos, ciclo, pruebas, problemas frecuentes).
- [x] **`production.md`**: Puertas de salida, CSP, permisos, artefactos y publicación en tiendas.
- [x] **`adapters.md`**: Uso e integración del inyector Shadow DOM.
- [x] **`release-process.md`**: Pasos para publicar una nueva versión con SemVer.
- [x] **`CHANGELOG.md`**: Historial unificado (raíz del repositorio).

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

---

## 🔭 9. Siguientes mejoras (fuera del alcance de la migración)
Detectadas en la auditoría del 2026-09-28; detalle en `docs/production.md` y `docs/adapters.md`.

- [ ] **P-01**: `content_scripts.matches` configurable (hoy siempre `<all_urls>`).
- [ ] **P-02**: ID gecko por proyecto y validación que rechace el marcador `ficticio`.
- [ ] **P-03**: `Publish-ExtensionForgeStore.ps1` con paquete/versión explícitos (hoy elige el ZIP más reciente).
- [ ] **P-04**: Validación CSP también sobre los bundles JS de Production.
- [ ] **A-01/A-03**: Ruta de import del adaptador y compilación Angular (AOT/JIT) dentro del content script.
- [ ] **CD-01**: `Invoke-LocalCD.ps1` debe abortar (no solo avisar) si no hay Git o no existe `tests/`.

