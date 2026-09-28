# Suite Pester 5+ — P-02: ID de Firefox (gecko.id) parametrizable y validado
# Ejecutar: Invoke-Pester -Path ./tests/Unit/Private

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force

    function New-FirefoxWorkspace {
        param([object]$BaseManifest)
        $ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $ws 'src'), (Join-Path $ws 'ng') -Force | Out-Null
        Set-Content -Path (Join-Path $ws 'ng' 'index.html') -Value '<html></html>'
        '{ "version": "1.0.0" }' | Set-Content -Path (Join-Path $ws 'package.json')
        if ($null -ne $BaseManifest) {
            $BaseManifest | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $ws 'src' 'manifest.json')
        }
        return $ws
    }

    function Invoke-FirefoxBuild {
        param([string]$Workspace, [string]$Browser = 'Firefox')
        InModuleScope 'ExtensionForge' -Parameters @{ Ws = $Workspace; B = $Browser } {
            param($Ws, $B)
            Invoke-ExtensionForgeRuntimeBuild -WorkspacePath $Ws -Browser $B -Environment Production `
                -NgDistPath (Join-Path $Ws 'ng') 6>$null | Out-Null
        }
        Get-Content -Raw (Join-Path $Workspace 'dist' 'extension' $Browser.ToLowerInvariant() 'manifest.json') | ConvertFrom-Json
    }
}

AfterAll {
    Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue
}

Describe 'Test-ExtensionForgeFirefoxId' -Tag 'Private', 'Firefox' {

    It "acepta '<Id>'" -ForEach @(
        @{ Id = 'mi-extension@mi-dominio.dev' }
        @{ Id = '@mi-extension.frank' }
        @{ Id = '{daf44bf7-a45e-4450-979c-91cf07434c3d}' }
    ) {
        InModuleScope 'ExtensionForge' -Parameters @{ Id = $Id } {
            param($Id)
            $r = Test-ExtensionForgeFirefoxId -Id $Id
            $r.IsValid       | Should -BeTrue
            $r.IsPlaceholder | Should -BeFalse
        }
    }

    It "rechaza '<Id>'" -ForEach @(
        @{ Id = '' }, @{ Id = 'sin-arroba' }, @{ Id = 'con espacio@dominio' }, @{ Id = '{no-es-guid}' }
        @{ Id = ('a' * 80) + '@x.dev' }
    ) {
        InModuleScope 'ExtensionForge' -Parameters @{ Id = $Id } {
            param($Id)
            (Test-ExtensionForgeFirefoxId -Id $Id).IsValid | Should -BeFalse
        }
    }

    It 'marca como placeholder el ID de ejemplo de Config/browsers/firefox.psd1' {
        InModuleScope 'ExtensionForge' {
            $r = Test-ExtensionForgeFirefoxId -Id 'extensionforge@ficticio.com'
            $r.IsValid       | Should -BeTrue
            $r.IsPlaceholder | Should -BeTrue
        }
    }
}

Describe 'Build: browser_specific_settings desde src/manifest.json' -Tag 'Private', 'Firefox' {

    It 'el gecko.id del manifest base sustituye al de la configuración y conserva strict_min_version' {
        $ws = New-FirefoxWorkspace -BaseManifest ([ordered]@{
            manifest_version = 3; name = 'T'; version = '1.0.0'
            browser_specific_settings = [ordered]@{ gecko = [ordered]@{ id = 'mi-ext@frank.dev' } }
        })
        $g = (Invoke-FirefoxBuild -Workspace $ws).browser_specific_settings.gecko
        $g.id                 | Should -Be 'mi-ext@frank.dev'
        $g.strict_min_version | Should -Be '109.0'
    }

    It 'propaga claves adicionales (data_collection_permissions, gecko_android)' {
        $ws = New-FirefoxWorkspace -BaseManifest ([ordered]@{
            manifest_version = 3; name = 'T'; version = '1.0.0'
            browser_specific_settings = [ordered]@{
                gecko         = [ordered]@{ id = 'mi-ext@frank.dev'; strict_min_version = '128.0'; data_collection_permissions = [ordered]@{ required = @('none') } }
                gecko_android = [ordered]@{ strict_min_version = '128.0' }
            }
        })
        $bss = (Invoke-FirefoxBuild -Workspace $ws).browser_specific_settings
        $bss.gecko.strict_min_version                   | Should -Be '128.0'
        @($bss.gecko.data_collection_permissions.required) | Should -Be @('none')
        $bss.gecko_android.strict_min_version           | Should -Be '128.0'
    }

    It 'sin browser_specific_settings en el base usa la configuración' {
        $ws = New-FirefoxWorkspace -BaseManifest ([ordered]@{ manifest_version = 3; name = 'T'; version = '1.0.0' })
        (Invoke-FirefoxBuild -Workspace $ws).browser_specific_settings.gecko.id | Should -Be 'extensionforge@ficticio.com'
    }

    It 'Chrome no recibe browser_specific_settings' {
        $ws = New-FirefoxWorkspace -BaseManifest ([ordered]@{
            manifest_version = 3; name = 'T'; version = '1.0.0'
            browser_specific_settings = [ordered]@{ gecko = [ordered]@{ id = 'mi-ext@frank.dev' } }
        })
        (Invoke-FirefoxBuild -Workspace $ws -Browser Chrome).PSObject.Properties.Name | Should -Not -Contain 'browser_specific_settings'
    }
}

Describe 'Validate: gecko.id en el paquete Firefox' -Tag 'Public', 'Firefox' {

    BeforeAll {
        function New-ValidateWorkspace([object]$Gecko) {
            $ws  = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $dir = Join-Path $ws 'dist' 'extension' 'firefox'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $m = [ordered]@{ manifest_version = 3; name = 'T'; version = '1.0.0'; action = @{ default_popup = 'index.html' } }
            if ($null -ne $Gecko) { $m['browser_specific_settings'] = @{ gecko = $Gecko } }
            $m | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'manifest.json')
            return $ws
        }
    }

    It 'Production rechaza el ID de ejemplo' {
        $ws = New-ValidateWorkspace @{ id = 'extensionforge@ficticio.com' }
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Production 6>$null 2>$null 3>$null | Should -BeFalse
    }

    It 'Development acepta el ID de ejemplo (solo aviso)' {
        $ws = New-ValidateWorkspace @{ id = 'extensionforge@ficticio.com' }
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Development 6>$null 3>$null | Should -BeTrue
    }

    It 'rechaza un paquete Firefox sin gecko.id' {
        $ws = New-ValidateWorkspace $null
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Development 6>$null 2>$null 3>$null | Should -BeFalse
    }

    It 'rechaza un gecko.id con formato inválido' {
        $ws = New-ValidateWorkspace @{ id = 'sin-arroba' }
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Development 6>$null 2>$null 3>$null | Should -BeFalse
    }

    It 'Production acepta un ID propio válido' {
        $ws = New-ValidateWorkspace @{ id = 'mi-ext@frank.dev' }
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Production 6>$null | Should -BeTrue
    }
}

Describe 'Initialize -FirefoxExtensionId' -Tag 'Public', 'Firefox' {

    BeforeEach {
        $script:Ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Ws | Out-Null
    }

    It 'escribe browser_specific_settings.gecko.id en src/manifest.json' {
        Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -FirefoxExtensionId 'mi-ext@frank.dev' 6>$null
        $bm = Get-Content -Raw (Join-Path $script:Ws 'src' 'manifest.json') | ConvertFrom-Json
        $bm.browser_specific_settings.gecko.id | Should -Be 'mi-ext@frank.dev'
        $bm.content_scripts                    | Should -Not -BeNullOrEmpty -Because 'el resto del manifest se conserva'
    }

    It 'no sustituye un ID propio ya existente (regla de oro)' {
        Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -FirefoxExtensionId 'primero@frank.dev' 6>$null
        Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -FirefoxExtensionId 'segundo@frank.dev' 6>$null 3>$null
        (Get-Content -Raw (Join-Path $script:Ws 'src' 'manifest.json') | ConvertFrom-Json).browser_specific_settings.gecko.id |
            Should -Be 'primero@frank.dev'
    }

    It 'rechaza un ID inválido o el marcador de ejemplo' {
        { Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -FirefoxExtensionId 'sin-arroba' 6>$null } | Should -Throw '*formato*'
        { Initialize-ExtensionForgeProject -WorkspacePath $script:Ws -FirefoxExtensionId 'x@ficticio.com' 6>$null } | Should -Throw '*marcador*'
    }

    It 'Invoke-ExtensionForge propaga -FirefoxExtensionId' {
        Invoke-ExtensionForge -Action Initialize -WorkspacePath $script:Ws -FirefoxExtensionId 'cli@frank.dev' 6>$null
        (Get-Content -Raw (Join-Path $script:Ws 'src' 'manifest.json') | ConvertFrom-Json).browser_specific_settings.gecko.id |
            Should -Be 'cli@frank.dev'
    }
}
