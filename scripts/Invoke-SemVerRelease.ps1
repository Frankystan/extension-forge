<#
.SYNOPSIS
    Generador de SemVer y Changelog de ExtensionForge.
.DESCRIPTION
    Lee src/manifest.json y package.json, exige que ambos compartan una versión
    X.Y.Z válida, calcula el incremento solicitado (patch/minor/major) y lo aplica
    a los dos archivos junto con una entrada nueva en CHANGELOG.md.

    - No deduce la semántica del release a partir de logs históricos: el valor
      'auto' se conserva solo por compatibilidad y equivale a 'patch' (con aviso).
    - Aborta sin modificar nada si la versión es inválida, si las versiones no
      coinciden o si CHANGELOG.md ya contiene la versión destino.
    - Escritura transaccional: si falla una escritura, restaura lo ya escrito.
    - Soporta -DryRun, -WhatIf y -Confirm.
.OUTPUTS
    [pscustomobject] con Current, Next, BumpType y Applied.
.NOTES
    Versión 2.2.0 — fusiona el script del repositorio (interfaz, 'auto', rutas)
    con el candidato endurecido de la sesión Perplexity (validación y rollback).
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$WorkspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateSet('auto', 'patch', 'minor', 'major')]
    [string]$BumpType = 'patch',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$root          = (Resolve-Path -LiteralPath $WorkspacePath).Path
$manifestPath  = Join-Path $root 'src' 'manifest.json'
$packagePath   = Join-Path $root 'package.json'
$changelogPath = Join-Path $root 'CHANGELOG.md'

if ($BumpType -eq 'auto') {
    Write-Warning "BumpType 'auto' está obsoleto: se aplica 'patch'. Indica patch/minor/major de forma explícita."
    $BumpType = 'patch'
}

foreach ($required in @($manifestPath, $packagePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "No existe '$required'. No se ha modificado ningún archivo."
    }
}

$manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8
$packageText  = Get-Content -LiteralPath $packagePath  -Raw -Encoding utf8
$manifest     = $manifestText | ConvertFrom-Json -AsHashtable
$package      = $packageText  | ConvertFrom-Json -AsHashtable

$versionPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
$current = [string]$manifest['version']
$m = [regex]::Match($current, $versionPattern)
if (-not $m.Success) {
    throw "Versión de src/manifest.json inválida ('$current'): se exige X.Y.Z sin sufijos. No se ha modificado ningún archivo."
}
if ([string]$package['version'] -ne $current) {
    throw "package.json ('$($package['version'])') y src/manifest.json ('$current') deben compartir la versión actual. No se ha modificado ningún archivo."
}

$major = [long]$m.Groups[1].Value
$minor = [long]$m.Groups[2].Value
$patch = [long]$m.Groups[3].Value
switch ($BumpType) {
    'major' { $major++; $minor = 0; $patch = 0 }
    'minor' { $minor++; $patch = 0 }
    'patch' { $patch++ }
}
$next = "$major.$minor.$patch"

$oldChangelog = if (Test-Path -LiteralPath $changelogPath) { Get-Content -LiteralPath $changelogPath -Raw -Encoding utf8 } else { '' }
if ($oldChangelog -match "(?m)^## \[$([regex]::Escape($next))\]") {
    throw "CHANGELOG.md ya contiene la versión $next. No se ha modificado ningún archivo."
}

$result = [pscustomobject]@{ Current = $current; Next = $next; BumpType = $BumpType; Applied = $false }
Write-Host "  Incremento propuesto: $current → $next ($BumpType)" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host '  [DryRun] No se ha modificado ningún archivo.' -ForegroundColor Yellow
    return $result
}
if (-not $PSCmdlet.ShouldProcess($root, "Actualizar manifest.json, package.json y CHANGELOG.md a $next")) {
    return $result
}

$manifest['version'] = $next
$package['version']  = $next
$entry = "## [$next] - $((Get-Date).ToString('yyyy-MM-dd'))`n`n- Pendiente: describir los cambios verificados antes de publicar.`n"
$safeEntry = $entry.Replace('$', '$$')
if ($oldChangelog -match '(?m)^## \[Unreleased\]') {
    # La versión nueva se inserta DEBAJO del bloque Unreleased (antes de la siguiente versión).
    $newChangelog = [regex]::Replace($oldChangelog, '(?ms)^(## \[Unreleased\].*?)(?=^## \[|\z)', ('$1' + "`n" + $safeEntry + "`n"), 1)
}
elseif ($oldChangelog -match '(?m)^# Changelog\s*\r?\n') {
    $newChangelog = [regex]::Replace($oldChangelog, '(?m)^(# Changelog\s*\r?\n)', ('$1' + "`n" + $safeEntry + "`n"), 1)
}
elseif ([string]::IsNullOrWhiteSpace($oldChangelog)) {
    $newChangelog = "# Changelog`n`n$entry"
}
else {
    $newChangelog = "# Changelog`n`n$entry`n$oldChangelog"
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$existedChangelog = Test-Path -LiteralPath $changelogPath
$targets = @(
    @{ Path = $manifestPath;  Previous = $manifestText; Next = ($manifest | ConvertTo-Json -Depth 100) + "`n" }
    @{ Path = $packagePath;   Previous = $packageText;  Next = ($package  | ConvertTo-Json -Depth 100) + "`n" }
    @{ Path = $changelogPath; Previous = $oldChangelog; Next = $newChangelog }
)
$written = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($t in $targets) {
        [System.IO.File]::WriteAllText($t.Path, [string]$t.Next, $utf8NoBom)
        $written.Add($t)
    }
}
catch {
    foreach ($t in $written) {
        if ($t.Path -eq $changelogPath -and -not $existedChangelog) {
            Remove-Item -LiteralPath $t.Path -Force -ErrorAction SilentlyContinue
        }
        else {
            [System.IO.File]::WriteAllText($t.Path, [string]$t.Previous, $utf8NoBom)
        }
    }
    throw
}

Write-Host "  ✅ Versión incrementada a $next ($BumpType): manifest.json, package.json y CHANGELOG.md." -ForegroundColor Green
$result.Applied = $true
return $result
