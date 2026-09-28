# Suite Pester 5+ — scripts/Invoke-SemVerRelease.ps1 (v2.2.0)
# Cada prueba usa un workspace temporal aislado; no toca el repositorio.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:SemVer   = Join-Path $script:RepoRoot 'scripts' 'Invoke-SemVerRelease.ps1'

    function New-SemVerWorkspace {
        param([string]$ManifestVersion = '1.2.3', [string]$PackageVersion = '1.2.3', [string]$Changelog)
        $base = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $ws = Join-Path $base ('ExtForge_SemVer_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $ws 'src') -Force | Out-Null
        [ordered]@{ manifest_version = 3; name = 'Test'; version = $ManifestVersion } | ConvertTo-Json |
            Set-Content -Path (Join-Path $ws 'src' 'manifest.json') -Encoding utf8
        [ordered]@{ name = 'test'; version = $PackageVersion; private = $true } | ConvertTo-Json |
            Set-Content -Path (Join-Path $ws 'package.json') -Encoding utf8
        if ($PSBoundParameters.ContainsKey('Changelog')) {
            Set-Content -Path (Join-Path $ws 'CHANGELOG.md') -Value $Changelog -Encoding utf8
        }
        return $ws
    }
    function Get-Version([string]$Path) { (Get-Content -Raw $Path | ConvertFrom-Json).version }
}

Describe 'Invoke-SemVerRelease' -Tag 'Unit', 'Tools' {

    AfterEach {
        if ($script:Ws -and (Test-Path $script:Ws)) { Remove-Item $script:Ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'calcula <Bump>: 1.2.3 → <Expected>' -ForEach @(
        @{ Bump = 'patch'; Expected = '1.2.4' }
        @{ Bump = 'minor'; Expected = '1.3.0' }
        @{ Bump = 'major'; Expected = '2.0.0' }
    ) {
        $script:Ws = New-SemVerWorkspace
        $r = & $script:SemVer -WorkspacePath $script:Ws -BumpType $Bump 6>$null
        $r.Next    | Should -Be $Expected
        $r.Applied | Should -BeTrue
        Get-Version (Join-Path $script:Ws 'src' 'manifest.json') | Should -Be $Expected
        Get-Version (Join-Path $script:Ws 'package.json')        | Should -Be $Expected
        Get-Content -Raw (Join-Path $script:Ws 'CHANGELOG.md')   | Should -Match "## \[$([regex]::Escape($Expected))\]"
    }

    It '-DryRun no modifica ningún archivo' {
        $script:Ws = New-SemVerWorkspace
        $r = & $script:SemVer -WorkspacePath $script:Ws -BumpType minor -DryRun 6>$null
        $r.Next    | Should -Be '1.3.0'
        $r.Applied | Should -BeFalse
        Get-Version (Join-Path $script:Ws 'src' 'manifest.json') | Should -Be '1.2.3'
        Join-Path $script:Ws 'CHANGELOG.md' | Should -Not -Exist
    }

    It '-WhatIf no modifica ningún archivo' {
        $script:Ws = New-SemVerWorkspace
        $r = & $script:SemVer -WorkspacePath $script:Ws -BumpType patch -WhatIf 6>$null
        $r.Applied | Should -BeFalse
        Get-Version (Join-Path $script:Ws 'package.json') | Should -Be '1.2.3'
    }

    It 'rechaza una versión inválida (<Version>) sin tocar archivos' -ForEach @(
        @{ Version = '2.0' }, @{ Version = '1.0.0-beta' }, @{ Version = '01.2.3' }
    ) {
        $script:Ws = New-SemVerWorkspace -ManifestVersion $Version -PackageVersion $Version
        { & $script:SemVer -WorkspacePath $script:Ws -BumpType patch 6>$null } | Should -Throw '*inválida*'
        Get-Version (Join-Path $script:Ws 'src' 'manifest.json') | Should -Be $Version
    }

    It 'rechaza versiones distintas entre manifest y package.json' {
        $script:Ws = New-SemVerWorkspace -ManifestVersion '1.2.3' -PackageVersion '9.9.9'
        { & $script:SemVer -WorkspacePath $script:Ws -BumpType patch 6>$null } | Should -Throw '*compartir*'
        Get-Version (Join-Path $script:Ws 'package.json') | Should -Be '9.9.9'
    }

    It 'rechaza si CHANGELOG.md ya contiene la versión destino' {
        $script:Ws = New-SemVerWorkspace -Changelog "# Changelog`n`n## [1.2.4] - 2026-01-01`n"
        { & $script:SemVer -WorkspacePath $script:Ws -BumpType patch 6>$null } | Should -Throw '*ya contiene*'
        Get-Version (Join-Path $script:Ws 'src' 'manifest.json') | Should -Be '1.2.3'
    }

    It "'auto' se acepta por compatibilidad y equivale a patch" {
        $script:Ws = New-SemVerWorkspace
        $r = & $script:SemVer -WorkspacePath $script:Ws -BumpType auto -DryRun 6>$null 3>$null
        $r.BumpType | Should -Be 'patch'
        $r.Next     | Should -Be '1.2.4'
    }

    It 'inserta la versión debajo de [Unreleased] conservando su contenido' {
        $cl = "# Changelog`n`n## [Unreleased]`n`n- Cambio pendiente.`n`n## [1.2.3] - 2026-01-01`n`n- Anterior.`n"
        $script:Ws = New-SemVerWorkspace -Changelog $cl
        & $script:SemVer -WorkspacePath $script:Ws -BumpType patch 6>$null | Out-Null
        $text = Get-Content -Raw (Join-Path $script:Ws 'CHANGELOG.md')
        $text | Should -Match 'Cambio pendiente'
        $text.IndexOf('## [Unreleased]') | Should -BeLessThan $text.IndexOf('## [1.2.4]')
        $text.IndexOf('## [1.2.4]')      | Should -BeLessThan $text.IndexOf('## [1.2.3]')
    }
}
