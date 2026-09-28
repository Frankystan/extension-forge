# Changelog

Todos los cambios relevantes de **ExtensionForge** (el módulo PowerShell y sus scripts) se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); versionado [SemVer](https://semver.org/lang/es/).
Las extensiones generadas llevan su propio `CHANGELOG.md`, gestionado por `scripts/Invoke-SemVerRelease.ps1`.

## [Unreleased]

### Añadido
- `docs/development.md`, `docs/production.md`, `docs/adapters.md` y `docs/release-process.md`.
- `tests/Unit/Tools/Invoke-SemVerRelease.Tests.ps1` (12 pruebas).
- Este `CHANGELOG.md`.

### Cambiado
- `scripts/Invoke-SemVerRelease.ps1` 2.2.0: valida `X.Y.Z` y la coincidencia manifest/package, rechaza versiones duplicadas en el changelog, escritura con rollback, `-WhatIf`/`-Confirm`, devuelve un objeto de resultado. `auto` queda obsoleto (equivale a `patch`).
- Wizard, Cheat Sheet y README: el versionado usa tipo explícito en lugar de `auto`.
- `DM-ExtensionForge.md` consolidado con las sesiones de Perplexity y la auditoría del 2026-09-28.
- Checklist de migración: documentación marcada como completada.

### Corregido
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
