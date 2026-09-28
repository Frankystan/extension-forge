# Suite Pester 5+ — P-03: Publish-ExtensionForgeStore con paquete/versión explícitos
# Nunca sube nada: todas las pruebas usan -WhatIf o fallan antes de publicar.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:Publish  = Join-Path $script:RepoRoot 'scripts' 'Publish-ExtensionForgeStore.ps1'

    function New-ZipWithManifest([string]$Path, [string]$Version) {
        $tmp = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        [ordered]@{ manifest_version = 3; name = 'T'; version = $Version } | ConvertTo-Json | Set-Content (Join-Path $tmp 'manifest.json')
        Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $Path
    }

    function New-PublishWorkspace {
        param([string]$PackageVersion = '1.2.3', [string[]]$ChromeZips = @('1.2.3'), [string]$FirefoxVersion = '1.2.3')
        $ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $pk = Join-Path $ws 'dist' 'packages'
        $ff = Join-Path $ws 'dist' 'extension' 'firefox'
        New-Item -ItemType Directory -Path $pk, $ff -Force | Out-Null
        [ordered]@{ name = 't'; version = $PackageVersion } | ConvertTo-Json | Set-Content (Join-Path $ws 'package.json')
        [ordered]@{ manifest_version = 3; name = 'T'; version = $FirefoxVersion } | ConvertTo-Json | Set-Content (Join-Path $ff 'manifest.json')
        foreach ($v in $ChromeZips) { New-ZipWithManifest (Join-Path $pk "extensionforge-chrome-v$v.zip") $v }
        return $ws
    }

    $script:SavedEnv = @{}
    foreach ($n in 'CHROME_EXTENSION_ID', 'CHROME_CLIENT_ID', 'CHROME_CLIENT_SECRET', 'CHROME_REFRESH_TOKEN', 'AMO_JWT_ISSUER', 'AMO_JWT_SECRET') {
        $script:SavedEnv[$n] = [Environment]::GetEnvironmentVariable($n)
        [Environment]::SetEnvironmentVariable($n, 'valor-de-prueba')
    }
}

AfterAll {
    foreach ($n in $script:SavedEnv.Keys) { [Environment]::SetEnvironmentVariable($n, $script:SavedEnv[$n]) }
}

Describe 'Publish-ExtensionForgeStore (P-03)' -Tag 'Unit', 'Tools' {

    It 'con -WhatIf elige el ZIP de la versión de package.json, no el más reciente' {
        $ws = New-PublishWorkspace -PackageVersion '1.2.3' -ChromeZips @('1.2.3', '9.9.9')
        # 9.9.9 es el más reciente por fecha
        (Get-Item (Join-Path $ws 'dist' 'packages' 'extensionforge-chrome-v9.9.9.zip')).LastWriteTime = (Get-Date).AddHours(1)
        $out = & $script:Publish -WorkspacePath $ws -Browser Chrome -WhatIf 6>&1 | Out-String
        $out | Should -Match 'extensionforge-chrome-v1\.2\.3\.zip'
        $out | Should -Not -Match 'v9\.9\.9'
    }

    It '-Version selecciona otro paquete explícito' {
        $ws = New-PublishWorkspace -ChromeZips @('1.2.3', '2.0.0') -FirefoxVersion '2.0.0'
        $out = & $script:Publish -WorkspacePath $ws -Browser All -Version 2.0.0 -WhatIf 6>&1 | Out-String
        $out | Should -Match 'extensionforge-chrome-v2\.0\.0\.zip'
        $out | Should -Match 'v2\.0\.0'
    }

    It 'aborta si no existe el ZIP de la versión (sin recurrir a otro)' {
        $ws = New-PublishWorkspace -PackageVersion '1.2.4' -ChromeZips @('1.2.3') -FirefoxVersion '1.2.4'
        { & $script:Publish -WorkspacePath $ws -Browser Chrome -WhatIf 6>$null } | Should -Throw '*extensionforge-chrome-v1.2.4.zip*'
    }

    It 'aborta si el manifest del ZIP no coincide con la versión' {
        $ws  = New-PublishWorkspace
        $bad = Join-Path $ws 'dist' 'packages' 'renombrado.zip'
        New-ZipWithManifest $bad '0.0.1'
        { & $script:Publish -WorkspacePath $ws -Browser Chrome -PackagePath $bad -WhatIf 6>$null } | Should -Throw "*'0.0.1'*"
    }

    It 'aborta si dist/extension/firefox está en otra versión' {
        $ws = New-PublishWorkspace -FirefoxVersion '1.0.0'
        { & $script:Publish -WorkspacePath $ws -Browser Firefox -WhatIf 6>$null } | Should -Throw "*'1.0.0'*"
    }

    It 'rechaza -Version con formato inválido' {
        $ws = New-PublishWorkspace
        { & $script:Publish -WorkspacePath $ws -Version '1.2' -WhatIf 6>$null } | Should -Throw
    }
}
