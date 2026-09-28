<#
.SYNOPSIS
    Módulo raíz de ExtensionForge.
.DESCRIPTION
    Carga dinámicamente todas las funciones privadas y públicas del módulo.
    - Private/  : funciones internas (no exportadas).
    - Public/   : cmdlets exportados al usuario.
#>

# Directorios de funciones
$privatePath = Join-Path $PSScriptRoot 'Private'
$publicPath  = Join-Path $PSScriptRoot 'Public'

# 1. Cargar funciones privadas (no exportadas)
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse | ForEach-Object {
        try {
            . $_.FullName
        }
        catch {
            Write-Warning "ExtensionForge: no se pudo cargar la función privada '$($_.Name)': $($_.Exception.Message)"
        }
    }
}

# 2. Cargar funciones públicas (exportadas)
$publicFunctions = @()
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse | ForEach-Object {
        try {
            . $_.FullName
            $publicFunctions += $_.BaseName
        }
        catch {
            Write-Warning "ExtensionForge: no se pudo cargar la función pública '$($_.Name)': $($_.Exception.Message)"
        }
    }
}

# 3. Exportar únicamente las funciones cargadas desde Public/
if ($publicFunctions.Count -gt 0) {
    Export-ModuleMember -Function $publicFunctions
}
