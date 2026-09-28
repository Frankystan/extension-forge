<#
.SYNOPSIS
    Generador de SemVer y Changelog de ExtensionForge.
.DESCRIPTION
    Analiza los logs JSONL (logs/dev.log) para decidir el salto de versión
    (patch/minor/major), actualiza src/manifest.json y package.json, y añade una
    entrada a CHANGELOG.md.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateSet('auto', 'patch', 'minor', 'major')]
    [string]$BumpType = 'auto',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ManifestPath = Join-Path $WorkspacePath 'src\manifest.json'
$PackagePath  = Join-Path $WorkspacePath 'package.json'
$ChangelogPath = Join-Path $WorkspacePath 'CHANGELOG.md'
$LogPath      = Join-Path $WorkspacePath 'logs\dev.log'

if (-not (Test-Path $ManifestPath)) {
    Write-Error "No se encontró '$ManifestPath'. Debes estar en la raíz del proyecto."
    exit 1
}

# 1. Detección automática del tipo de salto según logs
if ($BumpType -eq 'auto') {
    $BumpType = 'patch'
    if (Test-Path $LogPath) {
        $logText = Get-Content -Raw $LogPath
        if ($logText -match '"Action"\s*:\s*"Initialize"') {
            $BumpType = 'major'
        }
        elseif ($logText -match '"Action"\s*:\s*"Build"[\s\S]*?"Browser"\s*:\s*"All"') {
            $BumpType = 'minor'
        }
    }
}

# 2. Leer versión actual
$manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json
$current = $manifest.version
if (-not $current -or $current -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
    $current = '1.0.0'
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]

switch ($BumpType) {
    'major' { $major++; $minor = 0; $patch = 0 }
    'minor' { $minor++; $patch = 0 }
    'patch' { $patch++ }
}
$newVersion = "$major.$minor.$patch"
$date = (Get-Date).ToString('yyyy-MM-dd')

if ($DryRun) {
    Write-Host "  [DryRun] $current → $newVersion ($BumpType)" -ForegroundColor Yellow
    return
}

# 3. Actualizar manifest.json
$manifest.version = $newVersion
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestPath -Encoding utf8
Write-Host "  → src/manifest.json actualizado a $newVersion" -ForegroundColor Green

# 4. Actualizar package.json (si existe)
if (Test-Path $PackagePath) {
    $pkg = Get-Content -Raw $PackagePath | ConvertFrom-Json
    if ($null -ne $pkg.version) {
        $pkg.version = $newVersion
        $pkg | ConvertTo-Json -Depth 10 | Set-Content -Path $PackagePath -Encoding utf8
        Write-Host "  → package.json actualizado a $newVersion" -ForegroundColor Green
    }
}

# 5. Añadir entrada a CHANGELOG.md
$entry = "`n## [$newVersion] - $date`n"
$entry += "- Versión generada por ExtensionForge (bump: $BumpType).`n"

if (Test-Path $ChangelogPath) {
    $existing = Get-Content -Raw $ChangelogPath
    if ($existing -match '(?m)^#\s*Changelog\s*$') {
        $existing = [regex]::Replace($existing, '(?m)^#\s*Changelog\s*$\r?\n', "# Changelog`n$entry", 1)
    }
    else {
        $existing = "# Changelog`n$entry" + $existing
    }
    Set-Content -Path $ChangelogPath -Value $existing -Encoding utf8
}
else {
    Set-Content -Path $ChangelogPath -Value "# Changelog`n$entry" -Encoding utf8
}
Write-Host "  → CHANGELOG.md actualizado" -ForegroundColor Green

Write-Host "  ✅ Versión incrementada a $newVersion ($BumpType)." -ForegroundColor Green
