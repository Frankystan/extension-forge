<#
.SYNOPSIS
    Valida un ID de extensión de Firefox (browser_specific_settings.gecko.id).
.DESCRIPTION
    Formatos admitidos por Firefox/AMO (MDN, browser_specific_settings):
      - Tipo email: ^[a-zA-Z0-9-._]*@[a-zA-Z0-9-._]+$ (recomendado ≤ 80 caracteres),
        p. ej. 'mi-extension@mi-dominio.dev' o '@mi-extension.frank'.
      - GUID entre llaves: {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}.
    En Manifest V3 el ID es obligatorio para firmar; AMO no lo asigna.
    IsPlaceholder es $true para el marcador de ejemplo de ExtensionForge.
.OUTPUTS
    [pscustomobject] @{ IsValid; IsPlaceholder; Reason }
#>
function Test-ExtensionForgeFirefoxId {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Id
    )

    $emailLike = '^[a-zA-Z0-9-._]*@[a-zA-Z0-9-._]+$'
    $guid      = '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$'

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return [pscustomobject]@{ IsValid = $false; IsPlaceholder = $false; Reason = 'no está definido (obligatorio para firmar en Manifest V3).' }
    }
    if ($Id -notmatch $emailLike -and $Id -notmatch $guid) {
        return [pscustomobject]@{ IsValid = $false; IsPlaceholder = $false; Reason = "'$Id' no tiene formato válido (tipo email 'nombre@dominio' o GUID '{…}')." }
    }
    if ($Id -match $emailLike -and $Id.Length -gt 80) {
        return [pscustomobject]@{ IsValid = $false; IsPlaceholder = $false; Reason = "'$Id' supera 80 caracteres." }
    }
    $isPlaceholder = $Id -match '@ficticio\.com$'
    return [pscustomobject]@{ IsValid = $true; IsPlaceholder = $isPlaceholder; Reason = $null }
}
