# Suite Pester 5+ — recarga en desarrollo y MessageService tipado
# Ejecutar: Invoke-Pester -Path ./tests/Integration/ExtensionForge-DevReload.Tests.ps1
#
# Se simulan Angular CLI y esbuild (como en ExtensionForge-Pipeline.Tests.ps1).
# El mock de node captura EXTFORGE_DEV_RELOAD_PORT, que es lo que el build real
# pasa a esbuild (define __EXTFORGE_DEV_RELOAD_PORT__).

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $script:Tpl      = Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'Templates' 'angular-mv3'
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force

    function Register-ToolchainMocks {
        Mock Invoke-Expression -ModuleName ExtensionForge {
            $aj   = Get-Content -Raw (Join-Path $PWD 'angular.json') | ConvertFrom-Json
            $proj = ($aj.projects.PSObject.Properties | Select-Object -First 1).Name
            $out  = Join-Path $PWD $aj.projects.$proj.architect.build.options.outputPath 'browser'
            New-Item -ItemType Directory -Path $out -Force | Out-Null
            Set-Content (Join-Path $out 'index.html') '<!doctype html><app-root></app-root><script src="main.js"></script>'
            Set-Content (Join-Path $out 'main.js') 'console.log("angular");'
            Copy-Item (Join-Path $PWD 'src' 'manifest.json') $out
            $global:LASTEXITCODE = 0
        }
        Mock node -ModuleName ExtensionForge {
            $global:ExtForgeTestPort = $env:EXTFORGE_DEV_RELOAD_PORT
            $global:ExtForgeTestEnv  = $env:EXTFORGE_ENVIRONMENT
            $dist = $args[1]
            Set-Content (Join-Path $dist 'background.js') '// background'
            Set-Content (Join-Path $dist 'content.js')    '// content'
            $global:LASTEXITCODE = 0
        }
    }

    function New-DevWorkspace {
        $ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $ws | Out-Null
        Initialize-ExtensionForgeProject -WorkspacePath $ws -FirefoxExtensionId 'dev@extensionforge.test' 6>$null
        return $ws
    }
}

AfterAll {
    Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name ExtForgeTestPort, ExtForgeTestEnv -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Build: cliente de recarga según entorno' -Tag 'Integration', 'DevReload' {

    BeforeAll { Register-ToolchainMocks }

    It 'Development pasa Runtime.DevReloadPort a esbuild y escribe .build-complete' {
        $ws = New-DevWorkspace
        $env:EXTFORGE_DEV_RELOAD_PORT = 'previo'
        try {
            Build-ExtensionForgeProject -WorkspacePath $ws -Browser All -Environment Development 6>$null
            $global:ExtForgeTestPort | Should -Be '35729'
            $env:EXTFORGE_DEV_RELOAD_PORT | Should -Be 'previo' -Because 'el build restaura la variable'
        }
        finally { Remove-Item Env:EXTFORGE_DEV_RELOAD_PORT -ErrorAction SilentlyContinue }

        $stamp = Join-Path $ws 'dist' 'extension' '.build-complete'
        $stamp | Should -Exist
        $s = Get-Content -Raw $stamp | ConvertFrom-Json
        $s.environment | Should -Be 'Development'
        @($s.browsers) | Should -Be @('Chrome', 'Firefox')
    }

    It '<Environment> desactiva el cliente (puerto 0)' -ForEach @(
        @{ Environment = 'Staging' }
        @{ Environment = 'Production' }
    ) {
        $ws = New-DevWorkspace
        Build-ExtensionForgeProject -WorkspacePath $ws -Browser Chrome -Environment $Environment 6>$null
        $global:ExtForgeTestPort | Should -Be '0'
        $global:ExtForgeTestEnv  | Should -Be $Environment
    }

    It 'la marca .build-complete no entra en los paquetes' {
        $ws = New-DevWorkspace
        Build-ExtensionForgeProject -WorkspacePath $ws -Browser Chrome -Environment Development 6>$null
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Development 6>$null 3>$null | Should -BeTrue
        New-ExtensionForgePackage -WorkspacePath $ws -Browser Chrome -Environment Development 6>$null | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zipPath = (Get-ChildItem (Join-Path $ws 'dist' 'packages') -Filter '*.zip' | Select-Object -First 1).FullName
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        try { @($zip.Entries.FullName) | Should -Not -Contain '.build-complete' }
        finally { $zip.Dispose() }
    }
}

Describe 'Plantilla: recarga y MessageService' -Tag 'Integration', 'DevReload', 'Messaging' {

    It 'Initialize copia mensajería, cliente y servidor de recarga' {
        $ws = New-DevWorkspace
        foreach ($rel in 'src/app/models/messages.model.ts', 'src/app/models/messaging.ts',
                         'src/app/services/message.service.ts', 'src/dev/dev-reload.ts',
                         'src/dev/dev-env.d.ts', 'scripts/dev-reload-server.mjs') {
            Join-Path $ws $rel | Should -Exist
        }
        $pkg = Get-Content -Raw (Join-Path $ws 'package.json') | ConvertFrom-Json
        $pkg.devDependencies.ws | Should -Not -BeNullOrEmpty
        $pkg.scripts.'dev:reload' | Should -Be 'node scripts/dev-reload-server.mjs'
    }

    It 'contrato, lista de tipos y handlers del background coinciden' {
        $model = Get-Content -Raw (Join-Path $script:Tpl 'src' 'app' 'models' 'messages.model.ts')
        $bg    = Get-Content -Raw (Join-Path $script:Tpl 'src' 'background.ts')
        $contract = [regex]::Match($model, 'interface MessageContract \{(?<b>[\s\S]*?)\n\}').Groups['b'].Value
        $types    = @([regex]::Matches($contract, '(?m)^\s+([A-Z_]+):') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
        $map      = [regex]::Match($model, 'MESSAGE_TYPE_MAP[^=]*=\s*\{(?<b>[^}]*)\}').Groups['b'].Value
        $mapTypes = @([regex]::Matches($map, '([A-Z_]+):') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
        $handlers = [regex]::Match($bg, 'const handlers: MessageHandlers = \{(?<b>[\s\S]*?)\n\};').Groups['b'].Value
        $hTypes   = @([regex]::Matches($handlers, '(?m)^  ([A-Z_]+):') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
        $types.Count | Should -BeGreaterThan 0
        $mapTypes | Should -Be $types
        $hTypes   | Should -Be $types
    }

    It 'background y content llaman al cliente solo tras la guarda del define' {
        foreach ($t in 'angular-mv3', 'angular-mv3-demo') {
            $src = Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'Templates' $t 'src'
            (Get-Content -Raw (Join-Path $src 'background.ts')) | Should -Match 'if \(__EXTFORGE_DEV_RELOAD_PORT__\) void startDevReload\(\);'
            (Get-Content -Raw (Join-Path $src 'content.ts'))    | Should -Match 'if \(__EXTFORGE_DEV_RELOAD_PORT__\) announceDevContentScript\(\);'
            (Get-Content -Raw (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'Templates' $t 'scripts' 'build-extension.mjs')) |
                Should -Match '__EXTFORGE_DEV_RELOAD_PORT__: String\(production \? 0'
        }
    }

    It 'el servidor de recarga solo escucha en 127.0.0.1' {
        (Get-Content -Raw (Join-Path $script:Tpl 'scripts' 'dev-reload-server.mjs')) | Should -Match "host: '127\.0\.0\.1'"
    }
}

Describe 'Start-ExtensionForgeDev.ps1' -Tag 'Integration', 'DevReload' {

    It 'falla con un mensaje claro si falta scripts/dev-reload-server.mjs' {
        $ws = Join-Path $TestDrive 'sin-servidor'
        New-Item -ItemType Directory -Path $ws -Force | Out-Null
        { & (Join-Path $script:RepoRoot 'scripts' 'Start-ExtensionForgeDev.ps1') -WorkspacePath $ws -NoWatch 6>$null } |
            Should -Throw '*dev-reload-server.mjs*'
    }
}
