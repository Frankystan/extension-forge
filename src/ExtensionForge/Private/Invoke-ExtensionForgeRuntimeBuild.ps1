<#
.SYNOPSIS
    Empaqueta la salida post-build de Angular para un navegador concreto.
.DESCRIPTION
    Copia los artefactos compilados a dist/extension/<browser>, genera el manifest
    específico y aplica el adaptador del navegador.
#>
function Invoke-ExtensionForgeRuntimeBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Chrome', 'Firefox')]
        [string]$Browser,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment,

        [Parameter(Mandatory = $true)]
        [string]$NgDistPath
    )

    $Config          = Get-ExtensionForgeConfiguration -Environment $Environment -Browser $Browser
    $OutputDir       = Join-Path $WorkspacePath $Config['Paths']['Output']
    $BrowserOutputDir = Join-Path $OutputDir $Browser.ToLowerInvariant()

    if (Test-Path $BrowserOutputDir) {
        Remove-Item $BrowserOutputDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BrowserOutputDir -Force | Out-Null

    # Copiar artefactos compilados de Angular
    if (Test-Path $NgDistPath) {
        Copy-Item -Path (Join-Path $NgDistPath '*') -Destination $BrowserOutputDir -Recurse -Force
    }

    Write-ExtensionForgeLog -Message "Preparando runtime de la extensión para $Browser" `
        -Action 'Build' -Environment $Environment -Browser $Browser -WorkspacePath $WorkspacePath

    # Versión desde package.json
    $AppVersion = '1.0.0'
    $PkgPath = Join-Path $WorkspacePath 'package.json'
    if (Test-Path $PkgPath) {
        $v = (Get-Content -Raw $PkgPath | ConvertFrom-Json).version
        if ($v) { $AppVersion = $v }
    }

    # Nombre/descripción desde src/manifest.json (si existe)
    $name = $Config['Scaffold']['DefaultName']
    $desc = $Config['Scaffold']['DefaultDescription']
    $baseManifest = Join-Path $WorkspacePath 'src\manifest.json'
    if (Test-Path $baseManifest) {
        try {
            $bm = Get-Content -Raw $baseManifest | ConvertFrom-Json
            if ($bm.name)        { $name = $bm.name }
            if ($bm.description) { $desc = $bm.description }
        }
        catch { }
    }

    # browser_specific_settings (Firefox): el manifest base tiene prioridad sobre la
    # configuración (Config/browsers/firefox.psd1). Se fusiona por bloque (gecko,
    # gecko_android...) y por clave, p. ej. gecko.id o gecko.data_collection_permissions.
    if ($Browser -eq 'Firefox' -and $bm -and $bm.PSObject.Properties.Name -contains 'browser_specific_settings' -and $null -ne $bm.browser_specific_settings) {
        $bss = [ordered]@{}
        $cfgBss = $Config['Manifest']['BrowserSpecificSettings']
        if ($cfgBss) {
            foreach ($k in @($cfgBss.Keys)) {
                $block = [ordered]@{}
                if ($cfgBss[$k] -is [System.Collections.IDictionary]) { foreach ($kk in @($cfgBss[$k].Keys)) { $block[$kk] = $cfgBss[$k][$kk] } }
                $bss[$k] = $block
            }
        }
        foreach ($p in @($bm.browser_specific_settings.PSObject.Properties)) {
            if ($p.Value -is [System.Management.Automation.PSCustomObject]) {
                if (-not ($bss[$p.Name] -is [System.Collections.IDictionary])) { $bss[$p.Name] = [ordered]@{} }
                foreach ($q in @($p.Value.PSObject.Properties)) { $bss[$p.Name][$q.Name] = $q.Value }
            }
            else {
                $bss[$p.Name] = $p.Value
            }
        }
        $Config['Manifest']['BrowserSpecificSettings'] = $bss
    }

    $manifestParams = @{
        BrowserConfig = $Config
        OutputPath    = $BrowserOutputDir
        Version       = $AppVersion
        Name          = $name
        Description   = $desc
    }
    # content_scripts del manifest base (matches, js, css, run_at...) se respetan tal cual
    if ($bm -and $bm.PSObject.Properties.Name -contains 'content_scripts' -and $null -ne $bm.content_scripts) {
        $manifestParams['ContentScripts'] = @($bm.content_scripts)
    }
    New-ExtensionForgeManifest @manifestParams

    # Fusionar claves extra del manifest base (side_panel, options_ui, host_permissions, ...)
    if ($bm) {
        $genManifestPath = Join-Path $BrowserOutputDir 'manifest.json'
        $gen = Get-Content -Raw $genManifestPath | ConvertFrom-Json

        # Permisos: unir los del base con los generados (sin duplicados)
        if ($bm.permissions) {
            $gen.permissions = @(@($gen.permissions) + @($bm.permissions) | Select-Object -Unique)
        }

        # Claves extra del base no gestionadas por el generador específico de navegador
        $handled = @('manifest_version', 'name', 'version', 'description', 'action', 'browser_action', 'background', 'permissions', 'content_scripts', 'browser_specific_settings', 'icons')
        foreach ($p in @($bm.PSObject.Properties)) {
            if ($handled -notcontains $p.Name) {
                $gen | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
            }
        }

        $gen | ConvertTo-Json -Depth 12 | Set-Content -Path $genManifestPath -Encoding utf8
    }

    # Adaptador por navegador (garantiza background.js)
    if ($Browser -eq 'Chrome') {
        Invoke-ExtensionForgeChromeAdapter -OutputPath $BrowserOutputDir
    }
    else {
        Invoke-ExtensionForgeFirefoxAdapter -OutputPath $BrowserOutputDir
    }

    return $BrowserOutputDir
}
