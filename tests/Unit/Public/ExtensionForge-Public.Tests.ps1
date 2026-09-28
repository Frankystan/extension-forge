# Suite Pester 5 — cmdlets públicos y helpers internos de ExtensionForge
# Ejecutar: Invoke-Pester -Path ./tests
#
# Los helpers privados se invocan dentro de InModuleScope, porque el módulo
# solo exporta los cmdlets de Public/.

BeforeAll {
    $ModulePath = Resolve-Path "$PSScriptRoot\..\..\..\src\ExtensionForge\ExtensionForge.psd1"
    Import-Module $ModulePath -Force
    $global:TestWorkspace = Join-Path $env:TEMP ("ExtForge_PublicTests_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $global:TestWorkspace -Force | Out-Null
}

AfterAll {
    if (Test-Path $global:TestWorkspace) {
        Remove-Item $global:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Configuración (deep merge)' -Tag 'Private' {
    It 'Debe fusionar defaults + environment + browser sin perder claves base' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Environment 'Production' -Browser 'Firefox'
            $cfg['Paths']['Output'] | Should -Be 'dist/extension'
            $cfg['Angular']['Optimization'] | Should -Be $true
            $cfg['Angular']['SourceMap'] | Should -Be $false
            $cfg['Manifest']['BackgroundKey'] | Should -Be 'scripts'
            $cfg['Manifest']['BrowserSpecificSettings']['gecko']['id'] | Should -Be 'extensionforge@ficticio.com'
            $cfg['Browser'] | Should -Be 'Firefox'
        }
    }
}

Describe 'Write-ExtensionForgeLog' -Tag 'Logging' {
    It 'Debe crear logs/dev.log en formato JSONL' {
        InModuleScope 'ExtensionForge' {
            Write-ExtensionForgeLog -Message 'test' -Level 'INFO' -Action 'Doctor' -Environment 'Development' -Browser 'All' -WorkspacePath $global:TestWorkspace
            $log = Get-Content -Path (Join-Path $global:TestWorkspace 'logs\dev.log')
            $log | Should -Not -BeNullOrEmpty
            $entry = $log | Select-Object -Last 1 | ConvertFrom-Json
            $entry.Action | Should -Be 'Doctor'
            $entry.Level | Should -Be 'INFO'
            $entry.Message | Should -Be 'test'
        }
    }
}

Describe 'Test-ExtensionForgeTool' -Tag 'Private' {
    It 'Debe devolver booleano' {
        InModuleScope 'ExtensionForge' {
            (Test-ExtensionForgeTool -ToolName 'node') | Should -BeOfType [bool]
        }
    }
}

Describe 'New-ExtensionForgeManifest' -Tag 'Manifest' {
    It 'Debe generar un manifest MV3 válido para Chrome' {
        InModuleScope 'ExtensionForge' {
            $out = Join-Path $global:TestWorkspace 'chrome-out'
            New-Item -ItemType Directory -Path $out -Force | Out-Null
            $cfg = Get-ExtensionForgeConfiguration -Environment 'Production' -Browser 'Chrome'
            New-ExtensionForgeManifest -BrowserConfig $cfg -OutputPath $out -Version '1.0.0'
            $m = Get-Content -Raw (Join-Path $out 'manifest.json') | ConvertFrom-Json
            $m.manifest_version | Should -Be 3
            $m.background.service_worker | Should -Be 'background.js'
        }
    }

    It 'Debe generar browser_specific_settings para Firefox' {
        InModuleScope 'ExtensionForge' {
            $out = Join-Path $global:TestWorkspace 'firefox-out'
            New-Item -ItemType Directory -Path $out -Force | Out-Null
            $cfg = Get-ExtensionForgeConfiguration -Environment 'Production' -Browser 'Firefox'
            New-ExtensionForgeManifest -BrowserConfig $cfg -OutputPath $out -Version '1.0.0'
            $m = Get-Content -Raw (Join-Path $out 'manifest.json') | ConvertFrom-Json
            $m.background.scripts | Should -Contain 'background.js'
            $m.browser_specific_settings.gecko.id | Should -Be 'extensionforge@ficticio.com'
        }
    }
}
