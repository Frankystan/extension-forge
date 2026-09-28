<#
.SYNOPSIS
    Compila la extensión Angular y separa los artefactos por navegador.
.DESCRIPTION
    1. Ejecuta Angular CLI (npx ng build) con la configuración del entorno.
    2. Compila background.ts y content.ts con esbuild (scripts/build-extension.mjs).
    3. Genera dist/extension/<browser> con el manifest específico del navegador.
    4. Escribe dist/extension/.build-complete: el servidor de recarga de desarrollo
       (scripts/dev-reload-server.mjs) lo vigila para recargar la extensión.

    Con Runtime.EnableHotReload (solo Development por defecto), background.js y
    content.js incluyen el cliente de recarga (puerto Runtime.DevReloadPort). En
    Staging/Production el cliente se elimina del bundle.
#>
function Build-ExtensionForgeProject {
    [CmdletBinding()]
    param(
        [string]$WorkspacePath = "$PWD",
        [ValidateSet('Chrome', 'Firefox', 'All')]
        [string]$Browser = 'All',
        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment = 'Development'
    )

    $ErrorActionPreference = 'Stop'
    $logParams = @{ Action = 'Build'; Environment = $Environment; Browser = $Browser; WorkspacePath = $WorkspacePath }
    $Config = Get-ExtensionForgeConfiguration -Environment $Environment -Browser $Browser

    $angularJsonPath = Join-Path $WorkspacePath 'angular.json'
    if (-not (Test-Path $angularJsonPath)) {
        throw "No se encontró 'angular.json'. Ejecuta 'Initialize' primero."
    }

    $angularJson = Get-Content -Raw $angularJsonPath | ConvertFrom-Json
    $projectName = ($angularJson.projects.PSObject.Properties | Select-Object -First 1).Name
    $outputPath = $angularJson.projects.$projectName.architect.build.options.outputPath
    if (-not $outputPath) { $outputPath = "dist/$projectName" }

    $ngConfig     = $Config['Angular']['Configuration']
    $sourceMap    = if ($Config['Angular']['SourceMap'])    { 'true' } else { 'false' }
    $optimization = if ($Config['Angular']['Optimization']) { 'true' } else { 'false' }

    $ngBuildCommand = "npx ng build --configuration $ngConfig --output-hashing none --source-map=$sourceMap --optimization=$optimization"
    Write-ExtensionForgeLog -Message "Ejecutando Angular CLI: $ngBuildCommand" @logParams

    Push-Location $WorkspacePath
    try {
        Invoke-Expression $ngBuildCommand
        if ($LASTEXITCODE -ne 0) { throw "Falló el build de Angular (exit $LASTEXITCODE)." }
    }
    finally {
        Pop-Location
    }

    # Localizar el directorio real de salida de Angular
    $NgDist = Join-Path $WorkspacePath "$outputPath\browser"
    if (-not (Test-Path (Join-Path $NgDist 'index.html'))) {
        $NgDist = Join-Path $WorkspacePath $outputPath
    }
    if (-not (Test-Path (Join-Path $NgDist 'index.html'))) {
        throw "No se encontró index.html en '$NgDist'. Revisa el outputPath de angular.json."
    }

    # Compilar background.js / content.js con esbuild
    $esbuildScript = Join-Path $WorkspacePath 'scripts\build-extension.mjs'
    if (Test-Path $esbuildScript) {
        Write-ExtensionForgeLog -Message 'Compilando background.js y content.js (esbuild)...' @logParams
        Push-Location $WorkspacePath
        # build-extension.mjs lee EXTFORGE_ENVIRONMENT (Production → minify + ngDevMode=false)
        $prevEnv  = $env:EXTFORGE_ENVIRONMENT
        $prevPort = $env:EXTFORGE_DEV_RELOAD_PORT
        $env:EXTFORGE_ENVIRONMENT = $Environment
        # Cliente de recarga: solo si el entorno lo habilita (nunca en Production)
        $hotReload = [bool]$Config['Runtime']['EnableHotReload'] -and $Environment -ne 'Production'
        $env:EXTFORGE_DEV_RELOAD_PORT = if ($hotReload) { [string]$Config['Runtime']['DevReloadPort'] } else { '0' }
        try {
            & node $esbuildScript $NgDist
            if ($LASTEXITCODE -ne 0) { throw "Falló la compilación de background/content (exit $LASTEXITCODE)." }
        }
        finally {
            $env:EXTFORGE_ENVIRONMENT = $prevEnv
            $env:EXTFORGE_DEV_RELOAD_PORT = $prevPort
            Pop-Location
        }
    }
    else {
        Write-ExtensionForgeLog -Message 'scripts/build-extension.mjs no encontrado; se usará el boilerplate de background.js.' -Level 'WARN' @logParams
    }

    # Preparar el runtime por navegador
    $browsers = if ($Browser -eq 'All') { @('Chrome', 'Firefox') } else { @($Browser) }
    foreach ($b in $browsers) {
        Invoke-ExtensionForgeRuntimeBuild -WorkspacePath $WorkspacePath -Browser $b -Environment $Environment -NgDistPath $NgDist | Out-Null
        Write-ExtensionForgeLog -Message "Build de $b completado." -Level 'SUCCESS' @logParams
    }

    # Marca de build completo (fuera de los runtimes: no entra en los ZIP)
    $stamp = Join-Path $WorkspacePath $Config['Paths']['Output'] '.build-complete'
    [ordered]@{ environment = $Environment; browsers = $browsers; at = (Get-Date).ToString('o') } |
        ConvertTo-Json -Compress | Set-Content -Path $stamp -Encoding utf8
}
