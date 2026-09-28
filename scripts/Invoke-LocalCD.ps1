<#
.SYNOPSIS
    Despliegue continuo local (CD) protegido de ExtensionForge.
.DESCRIPTION
    Asegura que Git no tenga cambios pendientes, ejecuta los tests, incrementa la
    versión (SemVer), compila en Producción, valida y genera los ZIPs para las
    tiendas. No solicita ni incrusta secretos reales.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateSet('patch', 'minor', 'major', 'auto')]
    [string]$BumpType = 'patch'
)

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '  🚀 ExtensionForge — Despliegue Continuo Local (CD)' -ForegroundColor Cyan

# 1. Gatekeeper de Git: repositorio limpio
Write-Host '  [1/5] Verificando árbol Git limpio...' -ForegroundColor Yellow
$gitStatus = & git -C $WorkspacePath status --porcelain 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning '  No se detectó un repositorio Git; se omite la comprobación de limpieza.'
}
elseif ($gitStatus) {
    Write-Error '  El repositorio tiene cambios sin commitear. Haz commit (o stash) antes del CD.'
    exit 1
}
else {
    Write-Host '  ✅ Árbol Git limpio.' -ForegroundColor Green
}

# 2. Tests Pester
Write-Host '  [2/5] Ejecutando tests Pester...' -ForegroundColor Yellow
$TestsPath = Join-Path $WorkspacePath 'tests'
if (Test-Path $TestsPath) {
    $results = Invoke-Pester -Path $TestsPath -PassThru -Quiet
    if ($results.FailedCount -gt 0) {
        Write-Error "  ❌ $($results.FailedCount) test(s) fallaron. Se aborta el empaquetado."
        exit 1
    }
    Write-Host '  ✅ Tests superados.' -ForegroundColor Green
}
else {
    Write-Warning '  No se encontró la carpeta tests/. Se omite Pester.'
}

# 3. Incremento de versión (SemVer + Changelog)
Write-Host "  [3/5] Incrementando versión ($BumpType)... " -ForegroundColor Yellow
& (Join-Path $PSScriptRoot 'Invoke-SemVerRelease.ps1') -WorkspacePath $WorkspacePath -BumpType $BumpType
if ($LASTEXITCODE -ne 0) {
    Write-Error '  ❌ Falló el versionado SemVer.'
    exit 1
}

# 4. Importar el módulo y ejecutar Build → Validate → Package en Producción
$ModuleManifest = Join-Path $WorkspacePath 'src\ExtensionForge\ExtensionForge.psd1'
Import-Module $ModuleManifest -Force

Write-Host '  [4/5] Compilando (Build) en Producción para todos los navegadores...' -ForegroundColor Yellow
Invoke-ExtensionForge -Action Build -Environment Production -Browser All -WorkspacePath $WorkspacePath

Write-Host '  [4/5] Validando (Validate) en Producción...' -ForegroundColor Yellow
Invoke-ExtensionForge -Action Validate -Environment Production -WorkspacePath $WorkspacePath

Write-Host '  [5/5] Empaquetando (Package) en Producción...' -ForegroundColor Yellow
Invoke-ExtensionForge -Action Package -Environment Production -Browser All -WorkspacePath $WorkspacePath

Write-Host ''
Write-Host "  ✅ CD local completado. Paquetes en: $(Join-Path $WorkspacePath 'dist\packages')" -ForegroundColor Green
