<#
.SYNOPSIS
    Instala el módulo ExtensionForge en el PSModulePath del usuario.
.DESCRIPTION
    Copia (o enlaza mediante Junction) la carpeta src/ExtensionForge al directorio
    de módulos del usuario actual, dejando los cmdlets disponibles globalmente.
    - -Force    : sobrescribe una instalación existente.
    - -Symlink  : crea un enlace (Junction) para desarrollo en caliente.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Symlink
)

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '  🔨 Instalador de ExtensionForge' -ForegroundColor Cyan

# Ruta fuente del módulo (src/ExtensionForge)
$SourceModulePath = Join-Path $PSScriptRoot '..\src\ExtensionForge'
$SourceModulePath = (Resolve-Path $SourceModulePath).Path

if (-not (Test-Path (Join-Path $SourceModulePath 'ExtensionForge.psd1'))) {
    Write-Error "No se encontró el manifiesto del módulo en '$SourceModulePath'."
    exit 1
}

# Directorio de módulos del usuario (primer elemento de PSModulePath)
$UserModuleDir = ($env:PSModulePath -split [System.IO.Path]::PathSeparator)[0]
if (-not $UserModuleDir) {
    $UserModuleDir = Join-Path ([System.Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
}
if (-not (Test-Path $UserModuleDir)) {
    New-Item -ItemType Directory -Path $UserModuleDir -Force | Out-Null
}

$TargetModulePath = Join-Path $UserModuleDir 'ExtensionForge'

if (Test-Path $TargetModulePath) {
    if ($Force -or $Symlink) {
        Write-Host "  → Eliminando instalación previa: $TargetModulePath" -ForegroundColor Yellow
        Remove-Item $TargetModulePath -Recurse -Force
    }
    else {
        Write-Warning "ExtensionForge ya está instalado en '$TargetModulePath'. Usa -Force o -Symlink para reinstalar."
        exit 0
    }
}

if ($Symlink) {
    Write-Host "  → Creando enlace de desarrollo (Junction)..." -ForegroundColor Yellow
    New-Item -ItemType Junction -Path $TargetModulePath -Target $SourceModulePath | Out-Null
}
else {
    Write-Host "  → Copiando el módulo a '$UserModuleDir'..." -ForegroundColor Yellow
    Copy-Item -Path $SourceModulePath -Destination $TargetModulePath -Recurse -Force
}

$installed = Get-Module -ListAvailable -Name ExtensionForge | Sort-Object Version -Descending | Select-Object -First 1
if ($installed) {
    Write-Host "  ✅ ExtensionForge v$($installed.Version) instalado correctamente." -ForegroundColor Green
    Write-Host "     Ejecuta 'Import-Module ExtensionForge' para cargarlo en esta sesión." -ForegroundColor White
}
else {
    Write-Error 'La instalación no pudo verificarse. Revisa el PSModulePath.'
    exit 1
}
