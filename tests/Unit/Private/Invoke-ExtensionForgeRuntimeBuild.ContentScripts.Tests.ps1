# Suite Pester 5+ — P-01: el build respeta content_scripts de src/manifest.json
# Ejecutar: Invoke-Pester -Path ./tests/Unit/Private

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force

    # Workspace mínimo: salida Angular simulada + package.json + manifest base opcional
    function New-RuntimeWorkspace {
        param([object]$BaseManifest)
        $ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $ws 'src'), (Join-Path $ws 'ng') -Force | Out-Null
        Set-Content -Path (Join-Path $ws 'ng' 'index.html') -Value '<html></html>'
        '{ "version": "1.2.3" }' | Set-Content -Path (Join-Path $ws 'package.json')
        if ($null -ne $BaseManifest) {
            $BaseManifest | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $ws 'src' 'manifest.json')
        }
        return $ws
    }

    function Invoke-RuntimeBuild {
        param([string]$Workspace, [string]$Browser)
        InModuleScope 'ExtensionForge' -Parameters @{ Ws = $Workspace; B = $Browser } {
            param($Ws, $B)
            Invoke-ExtensionForgeRuntimeBuild -WorkspacePath $Ws -Browser $B -Environment Development `
                -NgDistPath (Join-Path $Ws 'ng') 6>$null | Out-Null
        }
        $path = Join-Path $Workspace 'dist' 'extension' $Browser.ToLowerInvariant() 'manifest.json'
        return Get-Content -Raw $path | ConvertFrom-Json
    }
}

AfterAll {
    Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue
}

Describe 'content_scripts del manifest base (P-01)' -Tag 'Private', 'Manifest' {

    It '<Browser>: respeta matches, js, css y run_at de src/manifest.json' -ForEach @(
        @{ Browser = 'Chrome' }, @{ Browser = 'Firefox' }
    ) {
        $ws = New-RuntimeWorkspace -BaseManifest ([ordered]@{
            manifest_version = 3; name = 'Test'; version = '1.2.3'
            content_scripts  = @(
                [ordered]@{ matches = @('https://example.com/*', 'https://*.example.org/*'); js = @('content.js'); css = @('content.css'); run_at = 'document_idle' }
            )
        })
        $m  = Invoke-RuntimeBuild -Workspace $ws -Browser $Browser
        $cs = @($m.content_scripts)
        $cs.Count           | Should -Be 1
        $cs[0].matches      | Should -Be @('https://example.com/*', 'https://*.example.org/*')
        $cs[0].matches      | Should -Not -Contain '<all_urls>'
        $cs[0].js           | Should -Be @('content.js')
        $cs[0].css          | Should -Be @('content.css')
        $cs[0].run_at       | Should -Be 'document_idle'
    }

    It 'conserva varios bloques de content_scripts en orden' {
        $ws = New-RuntimeWorkspace -BaseManifest ([ordered]@{
            manifest_version = 3; name = 'Test'; version = '1.2.3'
            content_scripts  = @(
                [ordered]@{ matches = @('https://a.example/*'); js = @('a.js') }
                [ordered]@{ matches = @('https://b.example/*'); js = @('b.js') }
            )
        })
        $cs = @((Invoke-RuntimeBuild -Workspace $ws -Browser Chrome).content_scripts)
        $cs.Count      | Should -Be 2
        $cs[0].js      | Should -Be @('a.js')
        $cs[1].matches | Should -Be @('https://b.example/*')
    }

    It 'content_scripts vacío omite la clave en el manifest final' {
        $ws = New-RuntimeWorkspace -BaseManifest ([ordered]@{
            manifest_version = 3; name = 'Test'; version = '1.2.3'; content_scripts = @()
        })
        $m = Invoke-RuntimeBuild -Workspace $ws -Browser Chrome
        $m.PSObject.Properties.Name | Should -Not -Contain 'content_scripts'
    }

    It 'sin content_scripts en el base mantiene el valor por defecto (<all_urls> + content.js)' {
        $ws = New-RuntimeWorkspace -BaseManifest ([ordered]@{ manifest_version = 3; name = 'Test'; version = '1.2.3' })
        $cs = @((Invoke-RuntimeBuild -Workspace $ws -Browser Chrome).content_scripts)
        $cs[0].matches | Should -Be @('<all_urls>')
        $cs[0].js      | Should -Be @('content.js')
    }

    It 'sin src/manifest.json mantiene el valor por defecto' {
        $ws = New-RuntimeWorkspace
        $cs = @((Invoke-RuntimeBuild -Workspace $ws -Browser Firefox).content_scripts)
        $cs[0].matches | Should -Be @('<all_urls>')
    }

    It 'falla si un bloque no define matches (obligatorio en MV3)' {
        $ws = New-RuntimeWorkspace -BaseManifest ([ordered]@{
            manifest_version = 3; name = 'Test'; version = '1.2.3'
            content_scripts  = @([ordered]@{ js = @('content.js') })
        })
        { Invoke-RuntimeBuild -Workspace $ws -Browser Chrome } | Should -Throw "*matches*"
    }
}
