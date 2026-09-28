<#
.SYNOPSIS
    Verifica si una herramienta CLI está disponible como ejecutable en el PATH.
.DESCRIPTION
    Devuelve $true si el comando existe como aplicación/ejecutable, $false en caso contrario.
#>
function Test-ExtensionForgeTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName
    )

    try {
        $null = Get-Command $ToolName -CommandType Application -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}
