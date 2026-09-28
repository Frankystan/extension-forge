<#
.SYNOPSIS
    Configuración específica para el entorno de Development.
.DESCRIPTION
    Sobrescribe defaults.psd1 para habilitar mapas de origen, deshabilitar
    optimizaciones y activar hot-reload + logs de depuración.
#>
@{
    Angular = @{
        Configuration   = "development"
        Optimization    = $false
        SourceMap       = $true
        ExtractLicenses = $false
        Aot             = $false
    }

    Runtime = @{
        EnableHotReload = $true
        LogVerbosity    = "Debug"
        LogFile         = "dev.log"
    }
}
