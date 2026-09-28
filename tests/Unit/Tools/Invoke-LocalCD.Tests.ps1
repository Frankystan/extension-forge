# Suite Pester 5+ — CD-01: Invoke-LocalCD aborta sin Git o sin tests/

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:LocalCD  = Join-Path $script:RepoRoot 'scripts' 'Invoke-LocalCD.ps1'

    function New-CDWorkspace([switch]$Git, [switch]$Tests, [switch]$Dirty) {
        $ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $ws 'src') -Force | Out-Null
        '{ "manifest_version": 3, "name": "T", "version": "1.0.0" }' | Set-Content (Join-Path $ws 'src' 'manifest.json')
        '{ "name": "t", "version": "1.0.0" }' | Set-Content (Join-Path $ws 'package.json')
        if ($Tests) {
            New-Item -ItemType Directory -Path (Join-Path $ws 'tests') | Out-Null
            "Describe 'x' { It 'falla' { 1 | Should -Be 2 } }" | Set-Content (Join-Path $ws 'tests' 'Fail.Tests.ps1')
        }
        if ($Git) {
            & git -C $ws init -q
            & git -C $ws -c user.name=t -c user.email=t@t add -A
            & git -C $ws -c user.name=t -c user.email=t@t commit -q -m init
            if ($Dirty) { 'x' | Set-Content (Join-Path $ws 'pendiente.txt') }
        }
        return $ws
    }
    function Get-Version([string]$Ws) { (Get-Content -Raw (Join-Path $Ws 'package.json') | ConvertFrom-Json).version }
}

Describe 'Invoke-LocalCD (CD-01)' -Tag 'Unit', 'Tools' {

    It 'aborta si el proyecto no es un repositorio Git' {
        $ws = New-CDWorkspace -Tests
        { & $script:LocalCD -WorkspacePath $ws 6>$null } | Should -Throw '*no es un repositorio Git*'
        Get-Version $ws | Should -Be '1.0.0'
    }

    It 'aborta si hay cambios sin commitear' {
        $ws = New-CDWorkspace -Git -Tests -Dirty
        { & $script:LocalCD -WorkspacePath $ws 6>$null } | Should -Throw '*cambios sin commitear*'
    }

    It 'aborta si no existe tests/' {
        $ws = New-CDWorkspace -Git
        { & $script:LocalCD -WorkspacePath $ws 6>$null } | Should -Throw '*tests*-AllowNoTests*'
        Get-Version $ws | Should -Be '1.0.0'
    }

    It 'aborta si fallan los tests y no versiona' {
        $ws = New-CDWorkspace -Git -Tests
        { & $script:LocalCD -WorkspacePath $ws 6>$null *>$null } | Should -Throw '*test(s) fallaron*'
        Get-Version $ws | Should -Be '1.0.0'
    }

    It '-AllowNoGit y -AllowNoTests pasan las puertas; si Build falla, restaura la versión' {
        $ws = New-CDWorkspace
        # Sin angular.json el Build falla después del SemVer.
        { & $script:LocalCD -WorkspacePath $ws -AllowNoGit -AllowNoTests 6>$null 3>$null *>$null } | Should -Throw '*Build/Validate/Package falló*'
        Get-Version $ws | Should -Be '1.0.0'
        (Get-Content -Raw (Join-Path $ws 'src' 'manifest.json') | ConvertFrom-Json).version | Should -Be '1.0.0'
        Join-Path $ws 'CHANGELOG.md' | Should -Not -Exist
    }
}
