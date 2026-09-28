<#
.SYNOPSIS
    Configuración específica para Mozilla Firefox (MV3).
.DESCRIPTION
    Dimensiones exclusivas de Firefox: background scripts (en lugar de
    service_worker), clave action (MV3; browser_action es de MV2) y
    browser_specific_settings (gecko).
#>
@{
    Browser = "Firefox"

    Manifest = @{
        BackgroundKey       = "scripts"
        ActionKey           = "action"   # MV3: "browser_action" fue sustituido por "action"
        SpecificPermissions = @("contextMenus")

        BrowserSpecificSettings = @{
            gecko = @{
                # Marcador de ejemplo: define el ID real en src/manifest.json
                # (browser_specific_settings.gecko.id) o con Initialize -FirefoxExtensionId.
                # Validate lo rechaza en Production.
                id                = "extensionforge@ficticio.com"
                strict_min_version = "109.0"
            }
        }
    }
}
