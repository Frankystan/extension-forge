<#
.SYNOPSIS
    Configuración específica para el entorno de Staging.
.DESCRIPTION
    Punto intermedio entre Development y Production: optimización activa con
    mapas de origen para diagnóstico, sin hot-reload.
#>
@{
    Angular = @{
        Configuration   = "production"
        Optimization    = $true
        SourceMap       = $true
        ExtractLicenses = $false
        Aot             = $true
    }

    Runtime = @{
        EnableHotReload = $false
        LogVerbosity    = "Info"
        LogFile         = "dev.log"
    }
}
