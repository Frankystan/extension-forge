<#
.SYNOPSIS
    Configuración específica para el entorno de Production.
.DESCRIPTION
    Sobrescribe defaults.psd1 garantizando minificado estricto, limpieza de
    SourceMaps y ofuscación para las tiendas de extensiones.
#>
@{
    Angular = @{
        Configuration   = "production"
        Optimization    = $true
        SourceMap       = $false
        ExtractLicenses = $true
        Aot             = $true
    }

    Runtime = @{
        EnableHotReload = $false
        LogVerbosity    = "Error"
        LogFile         = "production.log"
    }
}
