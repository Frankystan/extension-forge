<#
.SYNOPSIS
    Verifica la salud del entorno de desarrollo (PowerShell, Node.js, Angular CLI).
.DESCRIPTION
    Comprueba que PowerShell 7.6.6+, Node.js 22+ y Angular CLI están disponibles.
    Devuelve $true si el entorno es válido; $false en caso contrario.
#>
function Test-ExtensionForgeDoctor {
    [CmdletBinding()]
    param(
        [string]$WorkspacePath = "$PWD"
    )

    $logParams = @{ Action = 'Doctor'; Environment = 'Development'; Browser = 'All'; WorkspacePath = $WorkspacePath }
    $issues = 0

    # 1. PowerShell 7.6.6+
    $psv  = $PSVersionTable.PSVersion
    $psOk = $psv -ge [System.Management.Automation.SemanticVersion]'7.6.6'
    if (-not $psOk) {
        Write-ExtensionForgeLog -Message "PowerShell 7.6.6+ es requerido (actual: $psv)." -Level 'ERROR' @logParams
        $issues++
    }
    else {
        Write-ExtensionForgeLog -Message "PowerShell $psv OK." @logParams
    }

    # 2. Node.js 22+ (Angular 22 ya no soporta Node 20; ver engines de @angular/cli@22)
    try {
        $nodeVersion = (& node -v 2>$null)
        if ($nodeVersion -match '^v(\d+)') {
            if ([int]$Matches[1] -lt 22) {
                Write-ExtensionForgeLog -Message "Node.js 22+ es requerido (actual: $nodeVersion)." -Level 'WARN' @logParams
                $issues++
            }
            else {
                Write-ExtensionForgeLog -Message "Node.js $nodeVersion OK." @logParams
            }
        }
        else {
            Write-ExtensionForgeLog -Message 'No se pudo determinar la versión de Node.js.' -Level 'WARN' @logParams
            $issues++
        }
    }
    catch {
        Write-ExtensionForgeLog -Message 'Node.js no está instalado o no está en el PATH.' -Level 'ERROR' @logParams
        $issues++
    }

    # 3. Angular CLI
    try {
        if (Test-ExtensionForgeTool -ToolName 'ng') {
            $ng = (& ng version 2>$null | Out-String)
        }
        else {
            $ng = (& npx --no-install ng version 2>$null | Out-String)
        }
        if ($ng -match 'Angular CLI:\s*(\d+\.\d+\.\d+)') {
            Write-ExtensionForgeLog -Message "Angular CLI $($Matches[1]) OK." @logParams
        }
        else {
            # No bloqueante: npx resolverá @angular/cli en cada build (ver README).
            Write-ExtensionForgeLog -Message 'Angular CLI no detectado (se usará npx en cada build).' -Level 'WARN' @logParams
        }
    }
    catch {
        Write-ExtensionForgeLog -Message 'Error al verificar Angular CLI.' -Level 'WARN' @logParams
        $issues++
    }

    if ($issues -eq 0) {
        Write-ExtensionForgeLog -Message 'Doctor completado: entorno válido.' -Level 'SUCCESS' @logParams
        return $true
    }
    Write-ExtensionForgeLog -Message "Doctor encontró $issues problema(s)." -Level 'WARN' @logParams
    return $false
}
