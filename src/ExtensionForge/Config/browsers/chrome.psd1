<#
.SYNOPSIS
    Configuración específica para Google Chrome (MV3).
.DESCRIPTION
    Dimensiones exclusivas del navegador Chrome (Manifest, permisos, background).
#>
@{
    Browser = "Chrome"

    Manifest = @{
        BackgroundKey       = "service_worker"
        ActionKey           = "action"
        SpecificPermissions = @()
    }
}
