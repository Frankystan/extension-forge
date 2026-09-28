# Suite Pester 5+ — preferencias en chrome.storage.local (plantilla base)
# Ejecutar: Invoke-Pester -Path ./tests/Integration/ExtensionForge-Settings.Tests.ps1
#
# Comprobaciones estáticas de la plantilla. El comportamiento en el navegador
# (persistencia al reabrir el popup, cambios en vivo, datos corruptos) se
# verificó en Chromium: ver docs/storage.md.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $script:Src      = Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'Templates' 'angular-mv3' 'src'
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force
    function Get-Src([string]$Rel) { Get-Content -Raw (Join-Path $script:Src $Rel) }
}

AfterAll { Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue }

Describe 'Plantilla: estado en chrome.storage' -Tag 'Integration', 'Storage' {

    It 'Initialize copia modelo, almacén y servicio de preferencias' {
        $ws = Join-Path $TestDrive 'ext'
        New-Item -ItemType Directory -Path $ws | Out-Null
        Initialize-ExtensionForgeProject -WorkspacePath $ws -FirefoxExtensionId 'st@extensionforge.test' 6>$null
        foreach ($rel in 'src/app/models/settings.model.ts', 'src/app/models/settings-store.ts', 'src/app/services/settings.service.ts') {
            Join-Path $ws $rel | Should -Exist
        }
        (Get-Content -Raw (Join-Path $ws 'src' 'manifest.json') | ConvertFrom-Json).permissions | Should -Contain 'storage'
    }

    It 'cada campo de Settings tiene valor por defecto y validación' {
        $model  = Get-Src 'app/models/settings.model.ts'
        $iface  = [regex]::Match($model, 'export interface Settings \{(?<b>[\s\S]*?)\n\}').Groups['b'].Value
        $fields = @([regex]::Matches($iface, '(?m)^\s+(\w+):') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
        $defs   = [regex]::Match($model, 'DEFAULT_SETTINGS[^=]*=\s*Object\.freeze\(\{(?<b>[\s\S]*?)\}\)').Groups['b'].Value
        $dKeys  = @([regex]::Matches($defs, '(?m)^\s+(\w+):') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
        $norm   = [regex]::Match($model, 'export function normalizeSettings[\s\S]*?return \{(?<b>[\s\S]*?)\n  \};').Groups['b'].Value
        $nKeys  = @([regex]::Matches($norm, '(?m)^    (\w+):') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
        $fields.Count | Should -BeGreaterThan 1
        $dKeys | Should -Be $fields
        $nKeys | Should -Be $fields
    }

    It 'el popup carga las preferencias antes del primer render' {
        (Get-Src 'main.ts') | Should -Match 'provideAppInitializer\(\(\) => inject\(SettingsService\)\.ready\)'
    }

    It 'el background siembra o migra las preferencias en onInstalled' {
        $bg = Get-Src 'background.ts'
        $bg | Should -Match "import \{ ensureSettings[^}]*\} from './app/models/settings-store'"
        $bg | Should -Match 'onInstalled\.addListener\([\s\S]*?void ensureSettings\(\);'
    }

    It 'SettingsService escucha storage.onChanged y deshace el cambio si falla la escritura' {
        $svc = Get-Src 'app/services/settings.service.ts'
        $svc | Should -Match 'onSettingsChanged\('
        $svc | Should -Match 'inject\(DestroyRef\)\.onDestroy'
        $svc | Should -Match 'this\.state\.set\(previous\)'
    }
}
