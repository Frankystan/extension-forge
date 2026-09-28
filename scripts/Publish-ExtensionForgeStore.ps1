<#
.SYNOPSIS
    Publica los paquetes generados en las tiendas (Chrome Web Store y AMO).
.DESCRIPTION
    Usa herramientas oficiales (web-ext para Firefox; chrome-webstore-upload para Chrome).
    Las credenciales se leen SIEMPRE de variables de entorno (nunca se incrustan secretos):

      Chrome  → CHROME_EXTENSION_ID, CHROME_CLIENT_ID, CHROME_CLIENT_SECRET, CHROME_REFRESH_TOKEN
      Firefox → AMO_JWT_ISSUER, AMO_JWT_SECRET

    Requisito previo: ejecutar 'Invoke-ExtensionForge -Action Package'.

    Paquete explícito (P-03): nunca se elige un ZIP por fecha. La versión a publicar
    es -Version o, si se omite, la de package.json. Chrome sube exactamente
    dist/packages/extensionforge-chrome-v<versión>.zip (o -PackagePath); Firefox
    firma dist/extension/firefox solo si su manifest tiene esa misma versión.
    Si falta el paquete o la versión no coincide, se aborta sin subir nada.
    Admite -WhatIf para comprobar qué se publicaría.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$WorkspacePath = "$PWD",
    [ValidateSet('Chrome', 'Firefox', 'All')]
    [string]$Browser = 'All',
    [ValidateSet('listed', 'unlisted')]
    [string]$FirefoxChannel = 'listed',

    # Versión X.Y.Z a publicar. Por defecto, la de package.json.
    [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')]
    [string]$Version,

    # ZIP de Chrome concreto. Si se indica, tiene prioridad sobre -Version para Chrome.
    [string]$PackagePath
)

$ErrorActionPreference = 'Stop'
$WorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath).Path
$packagesDir = Join-Path $WorkspacePath 'dist' 'packages'

Write-Host ''
Write-Host '  🌍 ExtensionForge — Publicación en tiendas' -ForegroundColor Cyan

# ── Versión y paquetes explícitos (se resuelven ANTES de subir nada) ─────────
if (-not $Version) {
    $pkgJson = Join-Path $WorkspacePath 'package.json'
    if (-not (Test-Path -LiteralPath $pkgJson)) {
        throw "No se indicó -Version y no existe '$pkgJson'."
    }
    $Version = [string](Get-Content -Raw -LiteralPath $pkgJson | ConvertFrom-Json).version
    if ($Version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
        throw "package.json tiene una versión no válida ('$Version'). Usa -Version X.Y.Z."
    }
}
Write-Host "     Versión a publicar: $Version" -ForegroundColor DarkGray

$chromeZip = $null
if ($Browser -in @('Chrome', 'All')) {
    if ($PackagePath) {
        if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) { throw "No existe -PackagePath '$PackagePath'." }
        $chromeZip = (Resolve-Path -LiteralPath $PackagePath).Path
    }
    else {
        $chromeZip = Join-Path $packagesDir "extensionforge-chrome-v$Version.zip"
        if (-not (Test-Path -LiteralPath $chromeZip -PathType Leaf)) {
            throw "No existe '$chromeZip'. Ejecuta 'Invoke-ExtensionForge -Action Package' para la versión $Version o indica -PackagePath."
        }
    }
    # El manifest dentro del ZIP debe tener la versión a publicar
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($chromeZip)
    try {
        $entry = $archive.Entries | Where-Object { $_.FullName -eq 'manifest.json' } | Select-Object -First 1
        if (-not $entry) { throw "'$chromeZip' no contiene manifest.json en la raíz." }
        $reader = [System.IO.StreamReader]::new($entry.Open())
        try { $zipVersion = [string]($reader.ReadToEnd() | ConvertFrom-Json).version } finally { $reader.Dispose() }
    }
    finally { $archive.Dispose() }
    if ($zipVersion -ne $Version) {
        throw "El manifest de '$(Split-Path $chromeZip -Leaf)' está en la versión '$zipVersion', no en '$Version'."
    }
}

$firefoxDir = Join-Path $WorkspacePath 'dist' 'extension' 'firefox'
if ($Browser -in @('Firefox', 'All')) {
    $ffManifest = Join-Path $firefoxDir 'manifest.json'
    if (-not (Test-Path -LiteralPath $ffManifest)) {
        throw "No existe '$ffManifest'. Ejecuta Build/Package para Firefox primero."
    }
    $ffVersion = [string](Get-Content -Raw -LiteralPath $ffManifest | ConvertFrom-Json).version
    if ($ffVersion -ne $Version) {
        throw "dist/extension/firefox está en la versión '$ffVersion', no en '$Version'. Recompila antes de publicar."
    }
}

# ── Firefox (Mozilla Add-ons) ──────────────────────────────────────────────
if ($Browser -in @('Firefox', 'All')) {
    Write-Host '  🟠 Firefox (AMO) — web-ext sign' -ForegroundColor Yellow
    if (-not $env:AMO_JWT_ISSUER -or -not $env:AMO_JWT_SECRET) {
        Write-Warning '  Faltan AMO_JWT_ISSUER / AMO_JWT_SECRET. Define estas variables para firmar y publicar.'
    }
    else {
      Write-Host "     Origen: $firefoxDir (v$Version, channel: $FirefoxChannel)"
      if ($PSCmdlet.ShouldProcess("AMO ($FirefoxChannel)", "Firmar y subir $firefoxDir v$Version")) {
        Write-Host "     Firma y subida a AMO de v$Version..."
        Push-Location $WorkspacePath
        try {
            & npx --yes web-ext sign --source-dir $firefoxDir --channel $FirefoxChannel `
                --api-key $env:AMO_JWT_ISSUER --api-secret $env:AMO_JWT_SECRET
            if ($LASTEXITCODE -ne 0) { throw "web-ext sign falló (exit $LASTEXITCODE)." }
        }
        finally { Pop-Location }
        Write-Host '  ✅ Firefox enviado a AMO.' -ForegroundColor Green
      }
    }
}

# ── Chrome (Chrome Web Store) ──────────────────────────────────────────────
if ($Browser -in @('Chrome', 'All')) {
    Write-Host '  🟢 Chrome (Chrome Web Store) — chrome-webstore-upload' -ForegroundColor Green
    $required = @('CHROME_EXTENSION_ID', 'CHROME_CLIENT_ID', 'CHROME_CLIENT_SECRET', 'CHROME_REFRESH_TOKEN')
    $missing = $required | Where-Object { -not (Get-Item "env:$_" -ErrorAction SilentlyContinue) }
    if ($missing) {
        Write-Warning "  Faltan variables de entorno: $($missing -join ', '). No se puede publicar en Chrome Web Store."
    }
    else {
        $zipName = Split-Path $chromeZip -Leaf
        Write-Host "     Paquete: $zipName (v$Version)"
        if ($PSCmdlet.ShouldProcess('Chrome Web Store', "Subir y publicar $zipName")) {
            Write-Host "     Subiendo $zipName..."
            Push-Location $WorkspacePath
            try {
                & npx --yes chrome-webstore-upload upload `
                    --source $chromeZip `
                    --extension-id $env:CHROME_EXTENSION_ID `
                    --client-id $env:CHROME_CLIENT_ID `
                    --client-secret $env:CHROME_CLIENT_SECRET `
                    --refresh-token $env:CHROME_REFRESH_TOKEN `
                    --auto-publish
                if ($LASTEXITCODE -ne 0) { throw "chrome-webstore-upload falló (exit $LASTEXITCODE)." }
            }
            finally { Pop-Location }
            Write-Host '  ✅ Chrome publicado en Chrome Web Store.' -ForegroundColor Green
        }
    }
}

Write-Host ''
Write-Host '  Publicación finalizada. Revisa los paneles de la tienda para confirmar el estado.' -ForegroundColor Cyan
