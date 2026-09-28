<#
.SYNOPSIS
    CLI unificada de ExtensionForge.
.DESCRIPTION
    Orquestador central que despacha las 6 acciones arquitectónicas:
    Doctor, Initialize, Build, Validate, Package, InstallDev.
#>
function Invoke-ExtensionForge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('Doctor', 'Initialize', 'Build', 'Validate', 'Package', 'InstallDev')]
        [string]$Action,

        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment = 'Development',

        [ValidateSet('Chrome', 'Firefox', 'All')]
        [string]$Browser = 'All',

        [string]$WorkspacePath = "$PWD",

        [ValidateSet('angular-mv3', 'angular-mv3-demo')]
        [string]$Template = 'angular-mv3',

        # Solo para Initialize: ID de Firefox (gecko.id) que se escribe en src/manifest.json
        [string]$FirefoxExtensionId
    )

    $ErrorActionPreference = 'Stop'
    $logParams = @{
        Action        = $Action
        Environment   = $Environment
        Browser       = $Browser
        WorkspacePath = $WorkspacePath
    }

    Write-ExtensionForgeLog -Message "Iniciando acción '$Action'..." @logParams

    try {
        switch ($Action) {
            'Doctor' {
                $ok = Test-ExtensionForgeDoctor -WorkspacePath $WorkspacePath
                if (-not $ok) { throw 'Doctor detectó problemas en el entorno.' }
            }
            'Initialize' {
                $initParams = @{ WorkspacePath = $WorkspacePath; Browser = $Browser; Environment = $Environment; Template = $Template }
                if ($PSBoundParameters.ContainsKey('FirefoxExtensionId')) { $initParams['FirefoxExtensionId'] = $FirefoxExtensionId }
                Initialize-ExtensionForgeProject @initParams
            }
            'Build' {
                Build-ExtensionForgeProject -WorkspacePath $WorkspacePath -Browser $Browser -Environment $Environment
            }
            'Validate' {
                $ok = Test-ExtensionForgePackage -WorkspacePath $WorkspacePath -Environment $Environment
                if (-not $ok) { throw 'La validación del paquete falló.' }
            }
            'Package' {
                New-ExtensionForgePackage -WorkspacePath $WorkspacePath -Environment $Environment -Browser $Browser
            }
            'InstallDev' {
                Install-ExtensionForgeDevelopment -WorkspacePath $WorkspacePath -Browser $Browser
            }
        }
        Write-ExtensionForgeLog -Message "Acción '$Action' finalizada con éxito." -Level 'SUCCESS' @logParams
    }
    catch {
        Write-ExtensionForgeLog -Message $_.Exception.Message -Level 'ERROR' @logParams
        throw
    }
}
