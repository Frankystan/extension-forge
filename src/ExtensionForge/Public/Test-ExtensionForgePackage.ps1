<#
.SYNOPSIS
    Valida los paquetes compilados (Manifest V3 y CSP) antes de publicar.
.DESCRIPTION
    Comprueba que cada dist/extension/<browser>/manifest.json sea JSON válido,
    tenga manifest_version 3 y no contenga directivas CSP peligrosas (unsafe-eval).
    Devuelve $true si todo es correcto; $false en caso contrario.
#>
function Test-ExtensionForgePackage {
    [CmdletBinding()]
    param(
        [string]$WorkspacePath = "$PWD",
        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment = 'Production'
    )

    $ErrorActionPreference = 'Stop'
    $logParams = @{ Action = 'Validate'; Environment = $Environment; Browser = 'All'; WorkspacePath = $WorkspacePath }
    $Config    = Get-ExtensionForgeConfiguration -Environment $Environment -Browser 'All'
    $OutputDir = Join-Path $WorkspacePath $Config['Paths']['Output']

    if (-not (Test-Path $OutputDir)) {
        Write-ExtensionForgeLog -Message "Directorio de salida no encontrado: $OutputDir. Ejecuta 'Build' primero." -Level 'ERROR' @logParams
        return $false
    }

    $issues    = 0
    $browserDirs = @(Get-ChildItem -Path $OutputDir -Directory -ErrorAction SilentlyContinue)

    if ($browserDirs.Count -eq 0) {
        Write-ExtensionForgeLog -Message "No hay paquetes en '$OutputDir'. Ejecuta 'Build' primero." -Level 'ERROR' @logParams
        return $false
    }

    foreach ($dir in $browserDirs) {
        $manifestPath = Join-Path $dir.FullName 'manifest.json'
        if (-not (Test-Path $manifestPath)) {
            Write-ExtensionForgeLog -Message "Falta manifest.json en '$($dir.Name)'." -Level 'ERROR' @logParams
            $issues++
            continue
        }

        try {
            $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
        }
        catch {
            Write-ExtensionForgeLog -Message "manifest.json de '$($dir.Name)' está mal formado (JSON inválido)." -Level 'ERROR' @logParams
            $issues++
            continue
        }

        if ($manifest.manifest_version -ne 3) {
            Write-ExtensionForgeLog -Message "'$($dir.Name)': manifest_version debe ser 3 (actual: $($manifest.manifest_version))." -Level 'ERROR' @logParams
            $issues++
        }

        if ($Environment -eq 'Production') {
            $raw = Get-Content -Raw $manifestPath
            if ($raw -match 'unsafe-eval' -or $raw -match 'unsafe-inline') {
                Write-ExtensionForgeLog -Message "'$($dir.Name)': CSP contiene 'unsafe-eval'/'unsafe-inline' (rechazado por las tiendas)." -Level 'WARN' @logParams
                $issues++
            }
        }

        Write-ExtensionForgeLog -Message "'$($dir.Name)': manifest_version 3 y estructura OK." @logParams
    }

    if ($issues -gt 0) {
        Write-ExtensionForgeLog -Message "Validación completada con $issues problema(s)." -Level 'WARN' @logParams
        return $false
    }
    Write-ExtensionForgeLog -Message 'Validación superada: todos los paquetes son correctos.' -Level 'SUCCESS' @logParams
    return $true
}
