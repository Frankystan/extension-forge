<#
.SYNOPSIS
    Publica los paquetes generados en las tiendas (Chrome Web Store y AMO).
.DESCRIPTION
    Usa herramientas oficiales (web-ext para Firefox; chrome-webstore-upload para Chrome).
    Las credenciales se leen SIEMPRE de variables de entorno (nunca se incrustan secretos):

      Chrome  → CHROME_EXTENSION_ID, CHROME_CLIENT_ID, CHROME_CLIENT_SECRET, CHROME_REFRESH_TOKEN
      Firefox → AMO_JWT_ISSUER, AMO_JWT_SECRET

    Requisito previo: ejecutar 'Invoke-ExtensionForge -Action Package'.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateSet('Chrome', 'Firefox', 'All')]
    [string]$Browser = 'All',
    [ValidateSet('listed', 'unlisted')]
    [string]$FirefoxChannel = 'listed'
)

$ErrorActionPreference = 'Stop'
$packagesDir = Join-Path $WorkspacePath 'dist\packages'

Write-Host ''
Write-Host '  🌍 ExtensionForge — Publicación en tiendas' -ForegroundColor Cyan

if (-not (Test-Path $packagesDir)) {
    Write-Error "No se encontró '$packagesDir'. Ejecuta 'Invoke-ExtensionForge -Action Package' primero."
    exit 1
}

# ── Firefox (Mozilla Add-ons) ──────────────────────────────────────────────
if ($Browser -in @('Firefox', 'All')) {
    Write-Host '  🟠 Firefox (AMO) — web-ext sign' -ForegroundColor Yellow
    if (-not $env:AMO_JWT_ISSUER -or -not $env:AMO_JWT_SECRET) {
        Write-Warning '  Faltan AMO_JWT_ISSUER / AMO_JWT_SECRET. Define estas variables para firmar y publicar.'
    }
    else {
        $firefoxDir = Join-Path $WorkspacePath 'dist\extension\firefox'
        Write-Host "     Firma y subida a AMO (channel: $FirefoxChannel)..."
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

# ── Chrome (Chrome Web Store) ──────────────────────────────────────────────
if ($Browser -in @('Chrome', 'All')) {
    Write-Host '  🟢 Chrome (Chrome Web Store) — chrome-webstore-upload' -ForegroundColor Green
    $required = @('CHROME_EXTENSION_ID', 'CHROME_CLIENT_ID', 'CHROME_CLIENT_SECRET', 'CHROME_REFRESH_TOKEN')
    $missing = $required | Where-Object { -not (Get-Item "env:$_" -ErrorAction SilentlyContinue) }
    if ($missing) {
        Write-Warning "  Faltan variables de entorno: $($missing -join ', '). No se puede publicar en Chrome Web Store."
    }
    else {
        $zip = Get-ChildItem -Path $packagesDir -Filter 'extensionforge-chrome-v*.zip' |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $zip) {
            Write-Warning '  No se encontró extensionforge-chrome-v*.zip.'
        }
        else {
            Write-Host "     Subiendo $($zip.Name)..."
            Push-Location $WorkspacePath
            try {
                & npx --yes chrome-webstore-upload upload `
                    --source $zip.FullName `
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
