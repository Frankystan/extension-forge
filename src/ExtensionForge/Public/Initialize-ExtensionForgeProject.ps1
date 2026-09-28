<#
.SYNOPSIS
    Genera el andamiaje (scaffolding) de una extensión Angular + Angular Material MV3.
.DESCRIPTION
    - Si no existe angular.json: crea un proyecto Angular completo desde la plantilla.
    - Si ya existe: añade solo los archivos de extensión que falten y parchea
      angular.json/package.json SIN sobrescribir código nativo del desarrollador
      (regla de oro).
#>
function Initialize-ExtensionForgeProject {
    [CmdletBinding()]
    param(
        [string]$WorkspacePath = "$PWD",
        [ValidateSet('Chrome', 'Firefox', 'All')]
        [string]$Browser = 'All',
        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment = 'Development',
        [ValidateSet('angular-mv3', 'angular-mv3-demo')]
        [string]$Template = 'angular-mv3'
    )

    $ErrorActionPreference = 'Stop'
    $logParams = @{ Action = 'Initialize'; Environment = $Environment; Browser = $Browser; WorkspacePath = $WorkspacePath }

    # Guard: evitar hacer scaffold dentro del propio repositorio de ExtensionForge
    $repoModuleMarker  = Join-Path $WorkspacePath 'src\ExtensionForge\ExtensionForge.psd1'
    $repoScriptsMarker = Join-Path $WorkspacePath 'scripts\Start-ExtensionForgeWizard.ps1'
    if ((Test-Path $repoModuleMarker) -and (Test-Path $repoScriptsMarker)) {
        throw "Estás ejecutando 'Initialize' dentro del repositorio de la herramienta ExtensionForge ($WorkspacePath). Crea un directorio aparte para tu extensión y vuelve a ejecutarlo allí (p. ej. 'cd C:\Dev\mi-extension')."
    }

    $TemplateDir = Join-Path $PSScriptRoot "..\Templates\$Template"
    $TemplateDir = (Resolve-Path $TemplateDir).Path

    Write-ExtensionForgeLog -Message 'Iniciando scaffolding de la extensión...' @logParams

    $angularJsonPath = Join-Path $WorkspacePath 'angular.json'

    if (-not (Test-Path $angularJsonPath)) {
        Write-ExtensionForgeLog -Message "No se detectó 'angular.json'. Creando proyecto Angular + Angular Material desde la plantilla..." @logParams

        # Copia la plantilla completa, sin sobrescribir nada que ya exista
        Get-ChildItem -Path $TemplateDir -Recurse -File | ForEach-Object {
            $rel  = $_.FullName.Substring($TemplateDir.Length).TrimStart('\', '/')
            $dest = Join-Path $WorkspacePath $rel
            if (Test-Path $dest) {
                Write-ExtensionForgeLog -Message "Omitido (ya existe): $rel" @logParams
            }
            else {
                $dir = Split-Path $dest -Parent
                if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Copy-Item -Path $_.FullName -Destination $dest
                Write-ExtensionForgeLog -Message "Creado: $rel" @logParams
            }
        }
    }
    else {
        Write-ExtensionForgeLog -Message "'angular.json' detectado: aplicando parches sin sobrescribir código existente..." @logParams

        # Añadir solo los archivos de extensión que falten
        $extFiles = @('src\background.ts', 'src\content.ts', 'src\manifest.json', 'scripts\build-extension.mjs')
        foreach ($rel in $extFiles) {
            $dest = Join-Path $WorkspacePath $rel
            if (-not (Test-Path $dest)) {
                $src = Join-Path $TemplateDir $rel
                if (Test-Path $src) {
                    $dir = Split-Path $dest -Parent
                    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                    Copy-Item -Path $src -Destination $dest -Force
                    Write-ExtensionForgeLog -Message "Añadido: $rel" @logParams
                }
            }
        }

        # Parchear angular.json (outputHashing none + assets manifest.json)
        $angularJson = Get-Content -Raw $angularJsonPath | ConvertFrom-Json
        $projectName = $null
        if ($angularJson.projects) {
            $projectName = ($angularJson.projects.PSObject.Properties | Select-Object -First 1).Name
        }
        $build = $null
        if ($projectName -and $angularJson.projects.$projectName.architect -and $angularJson.projects.$projectName.architect.build) {
            $build = $angularJson.projects.$projectName.architect.build
        }

        if (-not $build) {
            Write-ExtensionForgeLog -Message "angular.json sin bloque 'projects.<nombre>.architect.build': se omite el parche de build (se respeta el contenido existente)." -Level 'WARN' @logParams
        }
        else {
            $assets = @($build.options.assets)
            if ($assets -notcontains 'src/manifest.json') {
                $newAssets = [System.Collections.Generic.List[object]]::new()
                foreach ($a in $assets) { $newAssets.Add($a) }
                $newAssets.Add('src/manifest.json')
                $build.options.assets = $newAssets
                Write-ExtensionForgeLog -Message "angular.json: 'src/manifest.json' añadido a assets." @logParams
            }

            if ($build.configurations) {
                foreach ($cfgName in @($build.configurations.PSObject.Properties.Name)) {
                    $build.configurations.$cfgName | Add-Member -NotePropertyName 'outputHashing' -NotePropertyValue 'none' -Force
                }
                Write-ExtensionForgeLog -Message "angular.json: outputHashing='none' aplicado." @logParams
            }

            # Actualizar el builder legacy a @angular/build (Angular v22+)
            if ($build.builder -eq '@angular-devkit/build-angular:application') {
                $build.builder = '@angular/build:application'
                Write-ExtensionForgeLog -Message "angular.json: builder actualizado a '@angular/build:application'." @logParams
            }
            $serve = $angularJson.projects.$projectName.architect.serve
            if ($serve -and $serve.builder -eq '@angular-devkit/build-angular:dev-server') {
                $serve.builder = '@angular/build:dev-server'
                Write-ExtensionForgeLog -Message "angular.json: builder de serve actualizado a '@angular/build:dev-server'." @logParams
            }

            $angularJson | ConvertTo-Json -Depth 20 | Set-Content -Path $angularJsonPath -Encoding utf8
        }

        # Corregir tsconfig.json (moduleResolution legacy → module preserve, Angular v22 / TS 6)
        $tsconfigPath = Join-Path $WorkspacePath 'tsconfig.json'
        if (Test-Path $tsconfigPath) {
            $ts = Get-Content -Raw $tsconfigPath | ConvertFrom-Json
            $tsChanged = $false
            if ($ts.compilerOptions.moduleResolution -eq 'node') {
                $ts.compilerOptions.PSObject.Properties.Remove('moduleResolution')
                $tsChanged = $true
            }
            if ($ts.compilerOptions.module -eq 'ES2022') {
                $ts.compilerOptions.module = 'preserve'
                $tsChanged = $true
            }
            if ($tsChanged) {
                $ts | ConvertTo-Json -Depth 10 | Set-Content -Path $tsconfigPath -Encoding utf8
                Write-ExtensionForgeLog -Message "tsconfig.json: moduleResolution/module corregidos para Angular v22 (TS 6)." @logParams
            }
        }

        # Parchear package.json (scripts build:ext / watch:ext)
        $pkgPath = Join-Path $WorkspacePath 'package.json'
        if (Test-Path $pkgPath) {
            $pkg = Get-Content -Raw $pkgPath | ConvertFrom-Json
            $changed = $false
            if ($null -eq $pkg.scripts) {
                $pkg | Add-Member -NotePropertyName 'scripts' -NotePropertyValue ([pscustomobject]@{}) -Force
                $changed = $true
            }
            if ($null -eq $pkg.scripts.'build:ext') {
                $pkg.scripts | Add-Member -NotePropertyName 'build:ext' -NotePropertyValue 'ng build --configuration production && node scripts/build-extension.mjs' -Force
                $changed = $true
            }
            if ($null -eq $pkg.scripts.'watch:ext') {
                $pkg.scripts | Add-Member -NotePropertyName 'watch:ext' -NotePropertyValue 'ng build --watch --configuration development' -Force
                $changed = $true
            }
            if ($changed) {
                $pkg | ConvertTo-Json -Depth 20 | Set-Content -Path $pkgPath -Encoding utf8
                Write-ExtensionForgeLog -Message 'package.json: scripts build:ext/watch:ext añadidos.' @logParams
            }
        }
    }

    Write-ExtensionForgeLog -Message 'Scaffolding completado con éxito.' -Level 'SUCCESS' @logParams
    Write-ExtensionForgeLog -Message "Siguiente paso: ejecuta 'npm install' en '$WorkspacePath' y luego 'Invoke-ExtensionForge -Action Build'." @logParams
}
