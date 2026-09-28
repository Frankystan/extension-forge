# Suite Pester 5+ — integración del pipeline Initialize → Build → Validate → Package
# Ejecutar: Invoke-Pester -Path ./tests/Integration
#
# Todo el código de ExtensionForge se ejecuta de verdad (plantilla, manifests,
# adaptadores, validación y ZIP). Solo se simulan las dos herramientas externas
# que exigirían `npm install` de Angular:
#   - Invoke-Expression "npx ng build ..."  → escribe dist/<proyecto>/browser/index.html
#   - node scripts/build-extension.mjs     → escribe background.js y content.js
# El recorrido con Angular CLI y esbuild reales está en ExtensionForge-Pipeline.E2E.Tests.ps1.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    function Get-ZipEntryNames([string]$Path) {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try { @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') }) }
        finally { $zip.Dispose() }
    }

    function Register-ToolchainMocks {
        # Angular CLI simulado: respeta el outputPath de angular.json (Build hace Push-Location al workspace)
        Mock Invoke-Expression -ModuleName ExtensionForge {
            $aj   = Get-Content -Raw (Join-Path $PWD 'angular.json') | ConvertFrom-Json
            $proj = ($aj.projects.PSObject.Properties | Select-Object -First 1).Name
            $out  = Join-Path $PWD $aj.projects.$proj.architect.build.options.outputPath 'browser'
            New-Item -ItemType Directory -Path $out -Force | Out-Null
            Set-Content (Join-Path $out 'index.html') '<!doctype html><app-root></app-root><script src="main.js"></script>'
            Set-Content (Join-Path $out 'main.js')    'console.log("angular");'
            Copy-Item (Join-Path $PWD 'src' 'manifest.json') $out
            $global:LASTEXITCODE = 0
        }
        # esbuild simulado: node <script> <ngDist>
        Mock node -ModuleName ExtensionForge {
            $dist = $args[1]
            Set-Content (Join-Path $dist 'background.js') '// bundle background (esbuild)'
            Set-Content (Join-Path $dist 'content.js')    '// bundle content (esbuild)'
            $global:LASTEXITCODE = 0
        }
    }
}

AfterAll {
    Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue
}

Describe 'Pipeline completo en Production (Chrome + Firefox)' -Tag 'Integration' {

    BeforeAll {
        Register-ToolchainMocks
        $script:Ws = Join-Path $TestDrive 'mi-extension'
        New-Item -ItemType Directory -Path $script:Ws | Out-Null
    }

    It 'Initialize crea el proyecto Angular MV3 desde la plantilla' {
        Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -Browser All -Environment Production 6>$null
        foreach ($rel in 'angular.json', 'package.json', 'src/manifest.json', 'src/background.ts', 'src/content.ts', 'scripts/build-extension.mjs') {
            Join-Path $script:Ws $rel | Should -Exist -Because "la plantilla angular-mv3 incluye $rel"
        }
    }

    It 'Initialize no sobrescribe código del desarrollador en una segunda ejecución' {
        $component = Join-Path $script:Ws 'src' 'app' 'app.component.ts'
        Set-Content $component '// código propio del desarrollador'
        Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -Browser All -Environment Production 6>$null
        Get-Content -Raw $component | Should -Match 'código propio del desarrollador'
    }

    It 'Build invoca Angular con los flags de Production y genera un runtime por navegador' {
        # Versión propia para comprobar que se propaga a manifests y ZIPs
        $pkgPath = Join-Path $script:Ws 'package.json'
        $pkg = Get-Content -Raw $pkgPath | ConvertFrom-Json
        $pkg.version = '2.3.4'
        $pkg | ConvertTo-Json -Depth 10 | Set-Content $pkgPath

        Build-ExtensionForgeProject -WorkspacePath $script:Ws -Browser All -Environment Production 6>$null

        Should -Invoke Invoke-Expression -ModuleName ExtensionForge -Times 1 -Exactly -ParameterFilter {
            $Command -match '--configuration production' -and
            $Command -match '--source-map=false' -and
            $Command -match '--optimization=true' -and
            $Command -match '--output-hashing none'
        }
        Should -Invoke node -ModuleName ExtensionForge -Times 1 -Exactly

        foreach ($b in 'chrome', 'firefox') {
            foreach ($f in 'index.html', 'main.js', 'background.js', 'content.js', 'manifest.json') {
                Join-Path $script:Ws 'dist' 'extension' $b $f | Should -Exist
            }
        }
        # El bundle de esbuild no se sustituye por el boilerplate del adaptador
        Get-Content -Raw (Join-Path $script:Ws 'dist' 'extension' 'chrome' 'background.js') | Should -Match 'esbuild'
    }

    It 'El manifest de Chrome es MV3 con service_worker y la versión de package.json' {
        $m = Get-Content -Raw (Join-Path $script:Ws 'dist' 'extension' 'chrome' 'manifest.json') | ConvertFrom-Json
        $m.manifest_version          | Should -Be 3
        $m.version                   | Should -Be '2.3.4'
        $m.background.service_worker | Should -Be 'background.js'
        $m.action.default_popup      | Should -Be 'index.html'
        $m.PSObject.Properties.Name  | Should -Not -Contain 'browser_specific_settings'
        @($m.permissions)            | Should -Contain 'storage'
    }

    It 'El manifest de Firefox usa background.scripts y gecko' {
        $m = Get-Content -Raw (Join-Path $script:Ws 'dist' 'extension' 'firefox' 'manifest.json') | ConvertFrom-Json
        $m.manifest_version                        | Should -Be 3
        $m.version                                 | Should -Be '2.3.4'
        @($m.background.scripts)                   | Should -Be @('background.js')
        $m.action.default_popup                    | Should -Be 'index.html' -Because 'Firefox MV3 usa action'
        $m.PSObject.Properties.Name                | Should -Not -Contain 'browser_action'
        $m.browser_specific_settings.gecko.id      | Should -Not -BeNullOrEmpty
        @($m.permissions)                          | Should -Contain 'contextMenus'
    }

    It 'Validate aprueba los paquetes generados' {
        Test-ExtensionForgePackage -WorkspacePath $script:Ws -Environment Production 6>$null | Should -BeTrue
    }

    It 'Package crea ZIP por navegador (+ .xpi) con manifest.json en la raíz' {
        New-ExtensionForgePackage -WorkspacePath $script:Ws -Browser All -Environment Production 6>$null
        $pk = Join-Path $script:Ws 'dist' 'packages'
        foreach ($f in 'extensionforge-chrome-v2.3.4.zip', 'extensionforge-firefox-v2.3.4.zip', 'extensionforge-firefox-v2.3.4.xpi') {
            Join-Path $pk $f | Should -Exist
        }
        foreach ($zip in 'extensionforge-chrome-v2.3.4.zip', 'extensionforge-firefox-v2.3.4.zip') {
            $entries = Get-ZipEntryNames (Join-Path $pk $zip)
            $entries | Should -Contain 'manifest.json'   -Because 'las tiendas exigen el manifest en la raíz del ZIP'
            $entries | Should -Contain 'background.js'
            $entries | Should -Contain 'content.js'
            $entries | Should -Contain 'index.html'
        }
    }

    It 'Package es repetible: sobrescribe el ZIP existente sin fallar' {
        { New-ExtensionForgePackage -WorkspacePath $script:Ws -Browser Chrome -Environment Production 6>$null } | Should -Not -Throw
        @(Get-ChildItem (Join-Path $script:Ws 'dist' 'packages') -Filter '*chrome*.zip').Count | Should -Be 1
    }
}

Describe 'Pipeline en Development y con un solo navegador' -Tag 'Integration' {

    BeforeAll {
        Register-ToolchainMocks
        $script:Ws = Join-Path $TestDrive 'dev-extension'
        New-Item -ItemType Directory -Path $script:Ws | Out-Null
        Initialize-ExtensionForgeProject -WorkspacePath $script:Ws 6>$null
    }

    It 'Build Development activa SourceMaps y desactiva la optimización' {
        Build-ExtensionForgeProject -WorkspacePath $script:Ws -Browser Chrome -Environment Development 6>$null
        Should -Invoke Invoke-Expression -ModuleName ExtensionForge -Times 1 -Exactly -ParameterFilter {
            $Command -match '--configuration development' -and
            $Command -match '--source-map=true' -and
            $Command -match '--optimization=false'
        }
    }

    It 'Build -Browser Chrome genera solo el runtime de Chrome' {
        Join-Path $script:Ws 'dist' 'extension' 'chrome'  | Should -Exist
        Join-Path $script:Ws 'dist' 'extension' 'firefox' | Should -Not -Exist
    }
}

Describe 'Errores y controles del pipeline' -Tag 'Integration' {

    BeforeAll {
        Register-ToolchainMocks
    }

    It 'Build falla si el workspace no tiene angular.json' {
        $ws = Join-Path $TestDrive 'vacio'
        New-Item -ItemType Directory -Path $ws | Out-Null
        { Build-ExtensionForgeProject -WorkspacePath $ws 6>$null } | Should -Throw '*angular.json*'
    }

    It 'Build falla si Angular CLI devuelve un código de salida distinto de 0' {
        $ws = Join-Path $TestDrive 'ng-falla'
        New-Item -ItemType Directory -Path $ws | Out-Null
        Initialize-ExtensionForgeProject -WorkspacePath $ws 6>$null
        Mock Invoke-Expression -ModuleName ExtensionForge { $global:LASTEXITCODE = 1 }
        { Build-ExtensionForgeProject -WorkspacePath $ws 6>$null } | Should -Throw '*Angular*'
    }

    It 'Validate en Production rechaza una CSP con unsafe-eval' {
        $ws = Join-Path $TestDrive 'csp'
        $dir = Join-Path $ws 'dist' 'extension' 'chrome'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        @{
            manifest_version        = 3
            name                    = 'csp'
            version                 = '1.0.0'
            content_security_policy = @{ extension_pages = "script-src 'self' 'unsafe-eval'; object-src 'self'" }
        } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir 'manifest.json')
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Production 6>$null 3>$null | Should -BeFalse
    }

    It 'Validate rechaza un manifest con manifest_version distinto de 3' {
        $ws = Join-Path $TestDrive 'mv2'
        $dir = Join-Path $ws 'dist' 'extension' 'firefox'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        '{ "manifest_version": 2, "name": "old", "version": "1.0.0" }' | Set-Content (Join-Path $dir 'manifest.json')
        { $script:mv2Result = Test-ExtensionForgePackage -WorkspacePath $ws -Environment Development 6>$null 3>$null 2>$null } |
            Should -Not -Throw -Because 'Validate debe devolver $false, no abortar'
        $script:mv2Result | Should -BeFalse
    }

    It 'Validate rechaza claves de MV2 (browser_action) en un manifest MV3' {
        $ws = Join-Path $TestDrive 'mv2-keys'
        $dir = Join-Path $ws 'dist' 'extension' 'firefox'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        '{ "manifest_version": 3, "name": "x", "version": "1.0.0", "browser_action": { "default_popup": "index.html" } }' |
            Set-Content (Join-Path $dir 'manifest.json')
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Development 6>$null 3>$null 2>$null | Should -BeFalse
    }

    It 'Validate devuelve $false (sin abortar) si no existe dist/extension' {
        $ws = Join-Path $TestDrive 'sin-build'
        New-Item -ItemType Directory -Path $ws | Out-Null
        { $script:noDistResult = Test-ExtensionForgePackage -WorkspacePath $ws 6>$null 3>$null 2>$null } |
            Should -Not -Throw -Because 'la ayuda del cmdlet promete $false en caso de error'
        $script:noDistResult | Should -BeFalse
    }
}
