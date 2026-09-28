<#
.SYNOPSIS
    Motor interno de configuración de ExtensionForge (deep merge por capas).
.DESCRIPTION
    Localiza y fusiona los PSD1 de configuración en este orden:
      defaults.psd1  →  environments/<env>.psd1  →  browsers/<browser>.psd1
    La fusión es recursiva para hashtables anidados (deep merge).
#>
function Get-ExtensionForgeConfiguration {
    [CmdletBinding()]
    param(
        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment = 'Development',
        [ValidateSet('Chrome', 'Firefox', 'All')]
        [string]$Browser = 'All'
    )

    $ConfigDir    = Join-Path $PSScriptRoot '..\Config'
    $DefaultsPath = Join-Path $ConfigDir 'defaults.psd1'

    if (-not (Test-Path $DefaultsPath)) {
        throw "No se encontró el archivo de configuración base: $DefaultsPath"
    }

    function Merge-Hashtable {
        param([hashtable]$Base, [hashtable]$Override)
        foreach ($key in @($Override.Keys)) {
            if ($Base.ContainsKey($key) -and $Base[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
                $null = Merge-Hashtable -Base $Base[$key] -Override $Override[$key]
            }
            else {
                $Base[$key] = $Override[$key]
            }
        }
        return $Base
    }

    # 1. Capa base
    $Merged = Import-PowerShellDataFile -Path $DefaultsPath

    # 2. Capa de entorno
    $EnvPath = Join-Path $ConfigDir "environments\$($Environment.ToLowerInvariant()).psd1"
    if (Test-Path $EnvPath) {
        $EnvCfg = Import-PowerShellDataFile -Path $EnvPath
        $Merged = Merge-Hashtable -Base $Merged -Override $EnvCfg
    }

    # 3. Capa de navegador (solo para un navegador concreto)
    if ($Browser -ne 'All') {
        $BrowserPath = Join-Path $ConfigDir "browsers\$($Browser.ToLowerInvariant()).psd1"
        if (Test-Path $BrowserPath) {
            $BrowserCfg = Import-PowerShellDataFile -Path $BrowserPath
            $Merged = Merge-Hashtable -Base $Merged -Override $BrowserCfg
        }
    }

    # Dimensiones activas en la configuración resultante
    $Merged['Environment'] = $Environment
    $Merged['Browser']     = $Browser

    return $Merged
}
