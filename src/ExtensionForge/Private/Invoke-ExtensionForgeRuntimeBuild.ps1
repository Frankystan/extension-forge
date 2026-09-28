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

    New-ExtensionForgeManifest -BrowserConfig $Config -OutputPath $BrowserOutputDir `
        -Version $AppVersion -Name $name -Description $desc

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
