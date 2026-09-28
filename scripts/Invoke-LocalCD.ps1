<#
.SYNOPSIS
    Despliegue continuo local (CD) protegido de ExtensionForge.
.DESCRIPTION
    Sobre el proyecto de extensión indicado en -WorkspacePath (por defecto, el
    directorio actual):
      1. Exige un repositorio Git sin cambios pendientes.
      2. Exige tests/ y que Pester los supere.
      3. Incrementa la versión (SemVer + CHANGELOG).
      4. Compila y valida en Production.
      5. Genera los ZIPs para las tiendas.
    Si Build/Validate/Package fallan, restaura src/manifest.json, package.json y
    CHANGELOG.md a su estado previo al versionado.
    Aborta ante cualquier fallo (CD-01): sin Git o sin tests/ no hay despliegue,
    salvo que se pida de forma explícita con -AllowNoGit / -AllowNoTests.
    No solicita ni incrusta secretos reales.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = "$PWD",
    [ValidateSet('patch', 'minor', 'major', 'auto')]
    [string]$BumpType = 'patch',

    # Permite continuar sin repositorio Git (desaconsejado: no hay trazabilidad).
    [switch]$AllowNoGit,

    # Permite continuar sin carpeta tests/ (desaconsejado: no hay red de seguridad).
    [switch]$AllowNoTests
)

$ErrorActionPreference = 'Stop'

function Stop-LocalCD([string]$Message) {
    Write-Host "  ❌ $Message" -ForegroundColor Red
    throw "Invoke-LocalCD abortado: $Message"
}

$WorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath).Path

Write-Host ''
Write-Host '  🚀 ExtensionForge — Despliegue Continuo Local (CD)' -ForegroundColor Cyan
Write-Host "     Proyecto: $WorkspacePath" -ForegroundColor DarkGray

# 1. Gatekeeper de Git: repositorio limpio
Write-Host '  [1/5] Verificando árbol Git limpio...' -ForegroundColor Yellow
$isGitRepo = $false
if (Get-Command git -ErrorAction SilentlyContinue) {
    $inside = & git -C $WorkspacePath rev-parse --is-inside-work-tree 2>$null
    $isGitRepo = ($LASTEXITCODE -eq 0 -and "$inside".Trim() -eq 'true')
}
if (-not $isGitRepo) {
    if (-not $AllowNoGit) {
        Stop-LocalCD "'$WorkspacePath' no es un repositorio Git (o git no está instalado). Inicializa Git o usa -AllowNoGit de forma explícita."
    }
    Write-Warning '  Sin repositorio Git: se continúa por -AllowNoGit (sin comprobación de limpieza).'
}
else {
    $gitStatus = & git -C $WorkspacePath status --porcelain
    if ($LASTEXITCODE -ne 0) { Stop-LocalCD 'git status falló.' }
    if ($gitStatus) { Stop-LocalCD 'El repositorio tiene cambios sin commitear. Haz commit (o stash) antes del CD.' }
    Write-Host '  ✅ Árbol Git limpio.' -ForegroundColor Green
}

# 2. Tests Pester
Write-Host '  [2/5] Ejecutando tests Pester...' -ForegroundColor Yellow
$TestsPath = Join-Path $WorkspacePath 'tests'
if (-not (Test-Path -LiteralPath $TestsPath -PathType Container)) {
    if (-not $AllowNoTests) {
        Stop-LocalCD "No existe '$TestsPath'. Añade tests o usa -AllowNoTests de forma explícita."
    }
    Write-Warning '  Sin carpeta tests/: se continúa por -AllowNoTests.'
}
else {
    $results = Invoke-Pester -Path $TestsPath -PassThru -Output Minimal
    if ($results.FailedCount -gt 0 -or $results.Result -eq 'Failed') {
        Stop-LocalCD "$($results.FailedCount) test(s) fallaron. Se aborta el empaquetado."
    }
    if ($results.TotalCount -eq 0) {
        Stop-LocalCD "tests/ no contiene pruebas ejecutables. Añade tests o usa -AllowNoTests."
    }
    Write-Host "  ✅ Tests superados ($($results.PassedCount))." -ForegroundColor Green
}

# 3. Incremento de versión (SemVer + Changelog)
# Copia de seguridad para revertir la versión si Build/Validate/Package fallan.
$versionFiles = @(
    (Join-Path $WorkspacePath 'src' 'manifest.json'),
    (Join-Path $WorkspacePath 'package.json'),
    (Join-Path $WorkspacePath 'CHANGELOG.md')
)
$backup = @{}
foreach ($f in $versionFiles) {
    $backup[$f] = if (Test-Path -LiteralPath $f) { [System.IO.File]::ReadAllBytes($f) } else { $null }
}
function Restore-VersionFiles {
    foreach ($f in $backup.Keys) {
        if ($null -eq $backup[$f]) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
        else { [System.IO.File]::WriteAllBytes($f, $backup[$f]) }
    }
    Write-Host '  ↩ Versión y CHANGELOG restaurados al estado anterior.' -ForegroundColor Yellow
}

Write-Host "  [3/5] Incrementando versión ($BumpType)... " -ForegroundColor Yellow
try {
    $release = & (Join-Path $PSScriptRoot 'Invoke-SemVerRelease.ps1') -WorkspacePath $WorkspacePath -BumpType $BumpType -Confirm:$false
}
catch {
    Stop-LocalCD "Falló el versionado SemVer: $($_.Exception.Message)"
}
if (-not $release -or -not $release.Applied) { Stop-LocalCD 'El versionado SemVer no se aplicó.' }

# 4. Importar el módulo de la herramienta y ejecutar Build → Validate → Package en Producción
$ModuleManifest = Join-Path $PSScriptRoot '..' 'src' 'ExtensionForge' 'ExtensionForge.psd1'
Import-Module $ModuleManifest -Force

try {
    Write-Host '  [4/5] Compilando (Build) en Producción para todos los navegadores...' -ForegroundColor Yellow
    Invoke-ExtensionForge -Action Build -Environment Production -Browser All -WorkspacePath $WorkspacePath

    Write-Host '  [4/5] Validando (Validate) en Producción...' -ForegroundColor Yellow
    Invoke-ExtensionForge -Action Validate -Environment Production -WorkspacePath $WorkspacePath

    Write-Host '  [5/5] Empaquetando (Package) en Producción...' -ForegroundColor Yellow
    Invoke-ExtensionForge -Action Package -Environment Production -Browser All -WorkspacePath $WorkspacePath
}
catch {
    Restore-VersionFiles
    Stop-LocalCD "Build/Validate/Package falló: $($_.Exception.Message)"
}

Write-Host ''
Write-Host "  ✅ CD local completado (v$($release.Next)). Paquetes en: $(Join-Path $WorkspacePath 'dist' 'packages')" -ForegroundColor Green
