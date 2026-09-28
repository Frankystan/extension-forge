<#
.SYNOPSIS
    Integración continua local (pre-commit) de ExtensionForge.
.DESCRIPTION
    Red de seguridad pre-commit: importa el módulo, ejecuta los tests Pester,
    pasa el Doctor y simula un andamiaje efímero en una carpeta temporal.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '  🧪 ExtensionForge — Integración Continua Local' -ForegroundColor Cyan

$ModuleManifest = Join-Path $WorkspacePath 'src\ExtensionForge\ExtensionForge.psd1'
if (-not (Test-Path $ModuleManifest)) {
    Write-Error "No se encontró el módulo en '$ModuleManifest'."
    exit 1
}
Import-Module $ModuleManifest -Force

$Issues = 0

# Paso 1/4 — Compatibilidad PowerShell mínima (7.6.6)
Write-Host '  [1/4] Validando compatibilidad de scripts con PowerShell 7.6.6...' -ForegroundColor Yellow
$CompatScript = Join-Path $WorkspacePath 'scripts\Test-ExtensionForgePowerShellCompatibility.ps1'
if (Test-Path $CompatScript) {
    $Compatible = & $CompatScript -ReturnOnly
    if (-not $Compatible) {
        Write-Error '  ❌ Se detectaron incompatibilidades con PowerShell 7.6.6.'
        $Issues++
    }
    else {
        Write-Host '  ✅ Compatibilidad PowerShell 7.6.6 verificada.' -ForegroundColor Green
    }
}
else {
    Write-Warning "  No se encontró '$CompatScript'. Se omite la validación de compatibilidad."
}

# Paso 2/4 — Tests Pester
Write-Host '  [2/4] Ejecutando tests Pester...' -ForegroundColor Yellow
$TestsPath = Join-Path $WorkspacePath 'tests'
if (Test-Path $TestsPath) {
    $results = Invoke-Pester -Path $TestsPath -PassThru -Output None
    if ($results.FailedCount -gt 0) {
        Write-Error "  ❌ $($results.FailedCount) test(s) fallaron."
        $Issues++
    }
    else {
        Write-Host '  ✅ Tests superados.' -ForegroundColor Green
    }
}
else {
    Write-Warning '  No se encontró la carpeta tests/. Se omite la validación de Pester.'
}

# Paso 3/4 — Doctor
Write-Host '  [3/4] Verificando entorno (Doctor)...' -ForegroundColor Yellow
try {
    $DoctorOk = Test-ExtensionForgeDoctor -WorkspacePath $WorkspacePath
    if (-not $DoctorOk) {
        throw 'El Doctor devolvió $false.'
    }
    Write-Host '  ✅ Doctor superado.' -ForegroundColor Green
}
catch {
    Write-Error "  ❌ Doctor falló: $($_.Exception.Message)"
    $Issues++
}

# Paso 4/4 — Dry-run de andamiaje
Write-Host '  [4/4] Simulando andamiaje efímero (dry-run)...' -ForegroundColor Yellow
$TempWorkspace = Join-Path $env:TEMP ("ExtForge_CITest_" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $TempWorkspace -Force | Out-Null
    Set-Content -Path (Join-Path $TempWorkspace 'angular.json') -Value '{ "version": 1 }' -Encoding utf8
    Initialize-ExtensionForgeProject -WorkspacePath $TempWorkspace -Browser All -Environment Development
    Write-Host '  ✅ Andamiaje efímero superado.' -ForegroundColor Green
}
finally {
    if (Test-Path $TempWorkspace) { Remove-Item $TempWorkspace -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($Issues -eq 0) {
    Write-Host '  ✅ CI local completada sin errores.' -ForegroundColor Green
    exit 0
}
else {
    Write-Host "  ❌ CI local finalizada con $Issues error(es)." -ForegroundColor Red
    exit 1
}
