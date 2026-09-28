<#
.SYNOPSIS
    Bucle de desarrollo de ExtensionForge: build + recarga automática.
.DESCRIPTION
    Sobre el proyecto de extensión (por defecto, el directorio actual):
      1. Arranca scripts/dev-reload-server.mjs (WebSocket en 127.0.0.1:<puerto>).
      2. Compila en Development (Build-ExtensionForgeProject).
      3. Vigila src/ y public/ y recompila tras cada cambio (con espera de agrupación).
    Cada build escribe dist/extension/.build-complete; el servidor lo detecta y
    envía RELOAD_EXTENSION al background (src/dev/dev-reload.ts), que recarga la
    extensión y refresca las pestañas con content script.

    Carga dist/extension/chrome (o firefox) sin empaquetar una vez; después basta
    con guardar archivos. Ctrl+C para salir.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = "$PWD",
    [ValidateSet('Chrome', 'Firefox', 'All')]
    [string]$Browser = 'All',
    # Puerto del servidor de recarga. Por defecto, Runtime.DevReloadPort (35729).
    [ValidateRange(1, 65535)]
    [int]$Port,
    # Milisegundos sin cambios antes de recompilar.
    [ValidateRange(100, 10000)]
    [int]$DebounceMs = 400,
    # Un único build con el servidor activo (los backgrounds conectados se recargan) y termina.
    [switch]$NoWatch
)

$ErrorActionPreference = 'Stop'
$WorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath).Path
Import-Module (Join-Path $PSScriptRoot '..' 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force

$serverScript = Join-Path $WorkspacePath 'scripts' 'dev-reload-server.mjs'
if (-not (Test-Path -LiteralPath $serverScript)) {
    throw "No existe '$serverScript'. Copia scripts/dev-reload-server.mjs de la plantilla (Initialize lo añade si falta) y ejecuta 'npm install' (requiere 'ws')."
}

$config = & (Get-Module ExtensionForge) { Get-ExtensionForgeConfiguration -Environment Development -Browser All }
if (-not $config['Runtime']['EnableHotReload']) {
    Write-Warning 'Runtime.EnableHotReload está desactivado en Development: el background no incluirá el cliente de recarga.'
}
if (-not $PSBoundParameters.ContainsKey('Port')) { $Port = [int]$config['Runtime']['DevReloadPort'] }
if ($Port -ne [int]$config['Runtime']['DevReloadPort']) {
    Write-Warning "El puerto $Port no coincide con Runtime.DevReloadPort ($($config['Runtime']['DevReloadPort'])): el background se conecta a este último."
}

Write-Host ''
Write-Host '  🔁 ExtensionForge — Desarrollo con recarga automática' -ForegroundColor Cyan
Write-Host "     Proyecto: $WorkspacePath" -ForegroundColor DarkGray

$serverLog = Join-Path ([System.IO.Path]::GetTempPath()) ("extforge-dev-reload-$Port.log")
$server = Start-Process -FilePath 'node' -ArgumentList @($serverScript, $Port) -WorkingDirectory $WorkspacePath `
    -PassThru -NoNewWindow -RedirectStandardOutput $serverLog -RedirectStandardError "$serverLog.err"
Start-Sleep -Milliseconds 500
if ($server.HasExited) {
    $err = if (Test-Path "$serverLog.err") { Get-Content -Raw "$serverLog.err" } else { '' }
    throw "El servidor de recarga no arrancó (¿puerto $Port ocupado o falta 'ws'?). $err"
}
Write-Host "  ✅ Servidor de recarga en ws://127.0.0.1:$Port (log: $serverLog)" -ForegroundColor Green

function Invoke-DevBuild {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Build-ExtensionForgeProject -WorkspacePath $WorkspacePath -Browser $Browser -Environment Development 6>$null | Out-Null
        Write-Host ("  ✅ Build Development en {0:N1} s → recarga enviada" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Build fallido: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '     Corrige el error y guarda de nuevo; la extensión no se recarga.' -ForegroundColor DarkGray
    }
}

$watchers = @()
try {
    Invoke-DevBuild
    if ($NoWatch) { return }

    foreach ($dirName in 'src', 'public') {
        $dir = Join-Path $WorkspacePath $dirName
        if (-not (Test-Path $dir)) { continue }
        $w = [System.IO.FileSystemWatcher]::new($dir)
        $w.IncludeSubdirectories = $true
        $w.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite'
        foreach ($evt in 'Changed', 'Created', 'Deleted', 'Renamed') {
            $null = Register-ObjectEvent -InputObject $w -EventName $evt -SourceIdentifier "ExtForgeDev.$dirName.$evt"
        }
        $w.EnableRaisingEvents = $true
        $watchers += $w
    }
    Write-Host '  👀 Vigilando src/ y public/. Guarda un archivo para recompilar (Ctrl+C para salir).' -ForegroundColor Cyan

    while ($true) {
        $evt = Wait-Event -Timeout 1
        if (-not $evt) {
            if ($server.HasExited) { throw 'El servidor de recarga se detuvo.' }
            continue
        }
        # Agrupa ráfagas de cambios (guardado de varios archivos, formateadores...)
        $changed = [System.Collections.Generic.HashSet[string]]::new()
        do {
            if ($evt.SourceEventArgs.FullPath) { $null = $changed.Add([System.IO.Path]::GetRelativePath($WorkspacePath, $evt.SourceEventArgs.FullPath)) }
            Remove-Event -EventIdentifier $evt.EventIdentifier
            $evt = Wait-Event -Timeout ($DebounceMs / 1000)
        } while ($evt)
        Write-Host "  ✏ Cambios: $((@($changed) | Select-Object -First 3) -join ', ')$(if ($changed.Count -gt 3) { " (+$($changed.Count - 3))" })" -ForegroundColor Yellow
        Invoke-DevBuild
        # Descarta eventos generados durante el build
        Get-Event -SourceIdentifier 'ExtForgeDev.*' -ErrorAction SilentlyContinue | Remove-Event
    }
}
finally {
    foreach ($w in $watchers) { $w.EnableRaisingEvents = $false; $w.Dispose() }
    Get-EventSubscriber -ErrorAction SilentlyContinue | Where-Object SourceIdentifier -like 'ExtForgeDev.*' | Unregister-Event
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    Write-Host '  ⏹ Servidor de recarga detenido.' -ForegroundColor DarkGray
}
