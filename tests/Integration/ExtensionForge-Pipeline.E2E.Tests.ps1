# Suite Pester 5+ — E2E real: Initialize → npm install → Build → Validate → Package
# Sin simulaciones: usa Angular CLI y esbuild reales de la plantilla angular-mv3.
#
# Se omite por defecto (descarga cientos de MB y tarda minutos). Para ejecutarla:
#   $env:EXTFORGE_E2E = '1'; Invoke-Pester -Path ./tests/Integration -Tag E2E
# Requisitos: Node.js compatible con package.json de la plantilla y acceso a npm.

BeforeDiscovery {
    $script:RunE2E = $env:EXTFORGE_E2E -eq '1'
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force
    Add-Type -AssemblyName System.IO.Compression.FileSystem
}

AfterAll {
    Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue
}

Describe 'E2E real con Angular CLI y esbuild' -Tag 'Integration', 'E2E' -Skip:(-not $script:RunE2E) {

    BeforeAll {
        $base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } elseif ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $script:Ws = Join-Path $base ('ExtForge_E2E_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Ws -Force | Out-Null
        Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -FirefoxExtensionId 'e2e@extensionforge.test' 6>$null

        Push-Location $script:Ws
        try {
            npm install --no-audit --no-fund --loglevel=error
            if ($LASTEXITCODE -ne 0) { throw "npm install falló (exit $LASTEXITCODE)" }
        }
        finally { Pop-Location }
    }

    AfterAll {
        if ($script:Ws -and (Test-Path $script:Ws)) {
            Remove-Item $script:Ws -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Build Production compila Angular y los bundles de background/content' {
        { Build-ExtensionForgeProject -WorkspacePath $script:Ws -Browser All -Environment Production 6>$null } | Should -Not -Throw
        foreach ($b in 'chrome', 'firefox') {
            foreach ($f in 'index.html', 'manifest.json', 'background.js', 'content.js') {
                Join-Path $script:Ws 'dist' 'extension' $b $f | Should -Exist
            }
            # background.js es el bundle de esbuild, no el boilerplate del adaptador
            Get-Content -Raw (Join-Path $script:Ws 'dist' 'extension' $b 'background.js') |
                Should -Not -Match '^// ExtensionForge: (Chrome Service Worker|Firefox Background)'
        }
    }

    It 'Build Production no deja SourceMaps en los runtimes' {
        @(Get-ChildItem (Join-Path $script:Ws 'dist' 'extension') -Recurse -Filter '*.map').Count | Should -Be 0
    }

    It 'Validate Production aprueba los paquetes' {
        Test-ExtensionForgePackage -WorkspacePath $script:Ws -Environment Production 6>$null | Should -BeTrue
    }

    It 'Package genera ZIPs cargables con manifest.json en la raíz' {
        New-ExtensionForgePackage -WorkspacePath $script:Ws -Browser All -Environment Production 6>$null
        $version = (Get-Content -Raw (Join-Path $script:Ws 'package.json') | ConvertFrom-Json).version
        foreach ($b in 'chrome', 'firefox') {
            $zipPath = Join-Path $script:Ws 'dist' 'packages' "extensionforge-$b-v$version.zip"
            $zipPath | Should -Exist
            $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
            try {
                $names = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
                $names | Should -Contain 'manifest.json'
                $names | Should -Contain 'index.html'
                $names | Should -Contain 'background.js'
            }
            finally { $zip.Dispose() }
        }
    }

    It 'Adaptador Sidebar: el content script se compila con AOT (sin JIT) y pasa Validate' {
        & (Join-Path $script:RepoRoot 'scripts' 'Add-ContentAdapter.ps1') -WorkspacePath $script:Ws -AdapterType Sidebar 6>$null | Out-Null
        Add-Content -Path (Join-Path $script:Ws 'src' 'content.ts') -Value @(
            "import { bootstrapSidebarAdapter } from './content-scripts/adapters/sidebar-adapter';"
            'void bootstrapSidebarAdapter();'
        )
        { Build-ExtensionForgeProject -WorkspacePath $script:Ws -Browser All -Environment Production 6>$null } | Should -Not -Throw
        foreach ($b in 'chrome', 'firefox') {
            $js = Get-Content -Raw (Join-Path $script:Ws 'dist' 'extension' $b 'content.js')
            $js | Should -Match 'ext-forge-sidebar-host' -Because 'el adaptador forma parte del bundle'
            $js | Should -Not -Match 'ɵɵngDeclare' -Because 'el linker completa las declaraciones parciales de Angular Material'
            $js | Should -Not -Match 'ɵɵdefineComponent\(\{[^}]*template:\s*`' -Because 'el componente llega compilado (AOT), no como plantilla JIT'
        }
        Test-ExtensionForgePackage -WorkspacePath $script:Ws -Environment Production 6>$null | Should -BeTrue
    }
}
