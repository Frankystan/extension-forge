# ExtensionForge — Proceso de publicación (SemVer)

> Pasos para publicar una nueva versión de una extensión generada con ExtensionForge.
> Basado en `scripts/Invoke-SemVerRelease.ps1` v2.2.0, `scripts/Invoke-LocalCD.ps1` y `scripts/Publish-ExtensionForgeStore.ps1`.

## Índice

- [Reglas de versionado](#reglas-de-versionado)
- [Secuencia recomendada](#secuencia-recomendada)
- [Qué hace Invoke-SemVerRelease](#qué-hace-invoke-semverrelease)
- [Qué hace Invoke-LocalCD](#qué-hace-invoke-localcd)
- [Después de publicar](#después-de-publicar)

## Reglas de versionado

| Tipo | Cuándo | Ejemplo |
|---|---|---|
| `patch` | Correcciones sin cambios visibles de permisos o API | 1.4.2 → 1.4.3 |
| `minor` | Funcionalidad nueva compatible | 1.4.2 → 1.5.0 |
| `major` | Cambios incompatibles, permisos nuevos relevantes o migración de datos | 1.4.2 → 2.0.0 |

- El tipo se elige **explícitamente**. `auto` se acepta por compatibilidad, avisa y equivale a `patch`; ya no se deduce de `logs/dev.log`.
- `src/manifest.json` y `package.json` deben tener la misma versión `X.Y.Z` (sin sufijos: las tiendas no aceptan `-beta` en `version`).
- La versión de ExtensionForge (`ModuleVersion` en `ExtensionForge.psd1`) es independiente de la de las extensiones.

## Secuencia recomendada

```powershell
git status --short                                           # 1. Debe estar vacío
./scripts/Invoke-LocalCI.ps1                                 # 2. CI local en verde
./scripts/Invoke-SemVerRelease.ps1 -WorkspacePath <proyecto> -BumpType minor -DryRun   # 3. Previsualizar
./scripts/Invoke-LocalCD.ps1 -WorkspacePath <proyecto> -BumpType minor                 # 4. Tests → versión → Build/Validate/Package
# 5. Editar CHANGELOG.md: sustituir «Pendiente: describir…» por los cambios reales
# 6. Probar a mano dist/extension/chrome y dist/extension/firefox
git add -A; git commit -m "release: vX.Y.Z"; git tag vX.Y.Z                            # 7. Commit + tag
# 8. Publicar (acción externa e irreversible; ver production.md)
./scripts/Publish-ExtensionForgeStore.ps1 -WorkspacePath <proyecto> -Browser All -Version X.Y.Z -WhatIf   # comprobar
./scripts/Publish-ExtensionForgeStore.ps1 -WorkspacePath <proyecto> -Browser All -Version X.Y.Z
```

## Qué hace Invoke-SemVerRelease

1. Valida que existan `src/manifest.json` y `package.json`, que la versión sea `X.Y.Z` y que coincidan.
2. Rechaza el incremento si `CHANGELOG.md` ya contiene la versión destino.
3. Con `-DryRun` o `-WhatIf` solo informa; devuelve `Current`, `Next`, `BumpType`, `Applied`.
4. Escribe manifest, package y changelog en UTF-8 sin BOM; si falla una escritura, restaura lo ya escrito.
5. Inserta la entrada debajo de `## [Unreleased]` (si existe) con el texto «Pendiente: describir los cambios verificados antes de publicar».

La versión 2.1.0 del script aceptaba versiones inválidas y calculaba un resultado erróneo (`2.0` → `0.0.1`) y sobrescribía un `package.json` desincronizado sin avisar. Ambos casos tienen ahora prueba Pester en `tests/Unit/Tools/Invoke-SemVerRelease.Tests.ps1`.

## Qué hace Invoke-LocalCD

| Paso | Acción | Si falla |
|---|---|---|
| 1 | Repositorio Git sin cambios pendientes | Aborta si no es un repositorio Git o si hay cambios (salvo `-AllowNoGit`) |
| 2 | `Invoke-Pester tests/` | Aborta si no existe `tests/`, si no contiene pruebas o si alguna falla (salvo `-AllowNoTests`) |
| 3 | `Invoke-SemVerRelease` | Aborta (excepción) |
| 4 | Build + Validate (Production, All) | Aborta y **restaura** `src/manifest.json`, `package.json` y `CHANGELOG.md` |
| 5 | Package (Production, All) | Igual que el paso 4; si va bien, ZIP/XPI en `dist/packages/` |

Todas las puertas abortan con una excepción (CD-01). `-AllowNoGit` y `-AllowNoTests` existen para casos excepcionales y dejan un aviso en la salida; no los uses en un release real. `WorkspacePath` es por defecto el directorio actual (el proyecto de la extensión) y el módulo se carga desde el propio ExtensionForge, no desde el proyecto.

Hasta el 2026-09-28, `Invoke-LocalCD` solo avisaba sin Git o sin `tests/`, llamaba a `Invoke-Pester -Quiet` (parámetro que Pester 6.2.0 no admite: con tests, el paso 2 fallaba siempre) y cargaba el módulo desde `<proyecto>/src/ExtensionForge`, que un proyecto de extensión no tiene.

## Después de publicar

- Confirma el estado en el panel de Chrome Web Store y de AMO (revisión, rechazo o publicación).
- Conserva el ZIP publicado y su hash junto al tag.
- Registra la versión en el `CHANGELOG.md` del proyecto de la extensión y, si cambió ExtensionForge, en el suyo.
