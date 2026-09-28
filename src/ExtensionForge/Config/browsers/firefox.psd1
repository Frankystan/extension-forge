<#
.SYNOPSIS
    Configuración específica para Mozilla Firefox (MV3).
.DESCRIPTION
    Dimensiones exclusivas de Firefox: background scripts (en lugar de
    service_worker), clave browser_action y browser_specific_settings (gecko).
#>
@{
    Browser = "Firefox"

    Manifest = @{
        BackgroundKey       = "scripts"
        ActionKey           = "browser_action"
        SpecificPermissions = @("contextMenus")

        BrowserSpecificSettings = @{
            gecko = @{
                id                = "extensionforge@ficticio.com"
                strict_min_version = "109.0"
            }
        }
    }
}
