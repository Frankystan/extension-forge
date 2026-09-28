<#
.SYNOPSIS
    Empaqueta las extensiones validadas en archivos ZIP listos para las tiendas.
.DESCRIPTION
    Comprime dist/extension/<browser> en dist/packages/extensionforge-<browser>-v<version>.zip.
    Para Firefox genera además un .xpi (ZIP renombrado) para carga sin firmar.
#>
function New-ExtensionForgePackage {
    [CmdletBinding()]
    param(
        [string]$WorkspacePath = "$PWD",
        [ValidateSet('Chrome', 'Firefox', 'All')]
        [string]$Browser = 'All',
        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment = 'Production'
    )

    $ErrorActionPreference = 'Stop'
    $logParams   = @{ Action = 'Package'; Environment = $Environment; Browser = $Browser; WorkspacePath = $WorkspacePath }
    $Config      = Get-ExtensionForgeConfiguration -Environment $Environment -Browser $Browser
    $OutputDir   = Join-Path $WorkspacePath $Config['Paths']['Output']
    $PackagesDir = Join-Path $WorkspacePath $Config['Paths']['Packages']

    if (-not (Test-Path $OutputDir)) {
        Write-ExtensionForgeLog -Message "Directorio de salida no encontrado: $OutputDir. Ejecuta 'Build' primero." -Level 'ERROR' @logParams
        return
    }
    if (-not (Test-Path $PackagesDir)) {
        New-Item -ItemType Directory -Path $PackagesDir -Force | Out-Null
    }

    # Versión de la app desde package.json
    $AppVersion = '1.0.0'
    $PkgJsonPath = Join-Path $WorkspacePath 'package.json'
    if (Test-Path $PkgJsonPath) {
        $v = (Get-Content -Raw $PkgJsonPath | ConvertFrom-Json).version
        if ($v) { $AppVersion = $v }
    }

    $browsersToPackage = if ($Browser -eq 'All') { @('chrome', 'firefox') } else { @($Browser.ToLowerInvariant()) }

    foreach ($b in $browsersToPackage) {
        $SourceDir = Join-Path $OutputDir $b
        if (-not (Test-Path $SourceDir)) {
            Write-ExtensionForgeLog -Message "No se encontró el directorio de compilación para '$b'." -Level 'WARN' @logParams
            continue
        }

        $ZipFileName = "extensionforge-$b-v$AppVersion.zip"
        $ZipPath     = Join-Path $PackagesDir $ZipFileName
        if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

        Write-ExtensionForgeLog -Message "Empaquetando '$b' en $ZipFileName ..." @logParams

        # Comprimir el contenido del directorio (no el directorio en sí)
        $items = Get-ChildItem -Path $SourceDir -Force
        Compress-Archive -Path $items.FullName -DestinationPath $ZipPath -CompressionLevel Optimal

        # Para Firefox, generar además un .xpi (mismo ZIP renombrado)
        if ($b -eq 'firefox') {
            $XpiPath = Join-Path $PackagesDir "extensionforge-$b-v$AppVersion.xpi"
            if (Test-Path $XpiPath) { Remove-Item $XpiPath -Force }
            Copy-Item -Path $ZipPath -Destination $XpiPath -Force
            Write-ExtensionForgeLog -Message "Paquete Firefox generado: $ZipFileName (+ .xpi)." -Level 'SUCCESS' @logParams
        }
        else {
            Write-ExtensionForgeLog -Message "Paquete $b creado: $ZipFileName" -Level 'SUCCESS' @logParams
        }
    }
}
