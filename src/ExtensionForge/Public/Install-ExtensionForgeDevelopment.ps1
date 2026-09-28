<#
.SYNOPSIS
    Prepara y documenta el sideload de la extensión para desarrollo.
.DESCRIPTION
    Genera las instrucciones (y el comando web-ext para Firefox) para cargar la
    extensión en caliente en Chrome y Firefox durante el desarrollo.
#>
function Install-ExtensionForgeDevelopment {
    [CmdletBinding()]
    param(
        [string]$WorkspacePath = "$PWD",
        [ValidateSet('Chrome', 'Firefox', 'All')]
        [string]$Browser = 'Chrome'
    )

    $logParams = @{ Action = 'InstallDev'; Environment = 'Development'; Browser = $Browser; WorkspacePath = $WorkspacePath }
    $Config    = Get-ExtensionForgeConfiguration -Environment 'Development' -Browser $Browser
    $OutputDir = Join-Path $WorkspacePath $Config['Paths']['Output']

    Write-ExtensionForgeLog -Message "Configurando sideloading para $Browser ..." @logParams

    if ($Browser -in @('Chrome', 'All')) {
        $ChromeDir = Join-Path $OutputDir 'chrome'
        Write-Host ''
        Write-Host '  🟢 GOOGLE CHROME — carga en desarrollo' -ForegroundColor Green
        Write-Host '     1. Abre chrome://extensions/' -ForegroundColor White
        Write-Host '     2. Activa el "Modo de desarrollador" (esquina superior derecha).' -ForegroundColor White
        Write-Host '     3. Pulsa "Cargar descomprimida".' -ForegroundColor White
        Write-Host "     4. Selecciona la carpeta: $ChromeDir" -ForegroundColor White
        Write-Host '     Opcional (auto): chrome.exe --load-extension="<ruta>"' -ForegroundColor DarkGray
        Write-Host ''
    }

    if ($Browser -in @('Firefox', 'All')) {
        $FirefoxDir = Join-Path $OutputDir 'firefox'
        Write-Host ''
        Write-Host '  🟠 MOZILLA FIREFOX — carga en desarrollo' -ForegroundColor Yellow
        Write-Host '     Opción A (manual):' -ForegroundColor White
        Write-Host '       1. Abre about:debugging#/runtime/this-firefox' -ForegroundColor White
        Write-Host '       2. Pulsa "Cargar complemento temporal..."' -ForegroundColor White
        Write-Host "       3. Selecciona manifest.json en: $FirefoxDir" -ForegroundColor White
        Write-Host '     Opción B (auto, recarga en vivo):' -ForegroundColor White
        Write-Host "       npx web-ext run --source-dir `"$FirefoxDir`"" -ForegroundColor Cyan
        Write-Host ''
    }

    Write-ExtensionForgeLog -Message 'Sideloading configurado. Sigue las instrucciones de arriba.' -Level 'SUCCESS' @logParams
}
