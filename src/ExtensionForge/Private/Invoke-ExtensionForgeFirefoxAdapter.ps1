<#
.SYNOPSIS
    Transformaciones finales exclusivas de Firefox (Background Script, no SW).
.DESCRIPTION
    Garantiza la existencia de un background.js como Background Script de Firefox.
#>
function Invoke-ExtensionForgeFirefoxAdapter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $BackgroundPath = Join-Path $OutputPath 'background.js'
    if (Test-Path $BackgroundPath) { return }

    $boilerplate = @"
// ExtensionForge: Firefox Background Script
browser.runtime.onInstalled.addListener(() => {
    console.log('[ExtensionForge][Firefox] Extensión instalada (Background Script).');
});
"@

    Set-Content -Path $BackgroundPath -Value $boilerplate -Encoding utf8
}
