<#
.SYNOPSIS
    Transformaciones finales exclusivas de Chrome (Service Worker MV3).
.DESCRIPTION
    Garantiza la existencia de un background.js como Service Worker estándar MV3.
#>
function Invoke-ExtensionForgeChromeAdapter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $BackgroundPath = Join-Path $OutputPath 'background.js'
    if (Test-Path $BackgroundPath) { return }

    $boilerplate = @"
// ExtensionForge: Chrome Service Worker (MV3)
self.addEventListener('install', () => {
    console.log('[ExtensionForge][Chrome] Service Worker instalado.');
    self.skipWaiting();
});
self.addEventListener('activate', (event) => {
    event.waitUntil(self.clients.claim());
});
"@

    Set-Content -Path $BackgroundPath -Value $boilerplate -Encoding utf8
}
