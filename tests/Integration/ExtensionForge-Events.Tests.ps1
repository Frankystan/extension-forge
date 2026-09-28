# Suite Pester 5+ — eventos proactivos Background → Popup (plantilla base)
# Ejecutar: Invoke-Pester -Path ./tests/Integration/ExtensionForge-Events.Tests.ps1
#
# Comprobaciones estáticas de la plantilla. El comportamiento en el navegador
# (entrega, reenvío al abrir, reconexión tras reiniciar el service worker) se
# verificó en Chromium: ver docs/dev-reload-messaging.md.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $script:Src      = Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'Templates' 'angular-mv3' 'src'
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force
    function Get-Src([string]$Rel) { Get-Content -Raw (Join-Path $script:Src $Rel) }
    function Get-Keys([string]$Block, [string]$Indent = '\s+') {
        @([regex]::Matches($Block, "(?m)^$Indent([A-Z_]+):") | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
    }
}

AfterAll { Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue }

Describe 'Plantilla: eventos Background → Popup' -Tag 'Integration', 'Messaging', 'Events' {

    It 'Initialize copia el contrato y el canal de eventos' {
        $ws = Join-Path $TestDrive 'ext'
        New-Item -ItemType Directory -Path $ws | Out-Null
        Initialize-ExtensionForgeProject -WorkspacePath $ws -FirefoxExtensionId 'ev@extensionforge.test' 6>$null
        Join-Path $ws 'src' 'app' 'models' 'events.model.ts' | Should -Exist
        Join-Path $ws 'src' 'app' 'models' 'events.ts'       | Should -Exist
    }

    It 'EventContract y EVENT_TYPE_MAP listan los mismos eventos' {
        $model    = Get-Src 'app/models/events.model.ts'
        $contract = [regex]::Match($model, 'interface EventContract \{(?<b>[\s\S]*?)\n\}').Groups['b'].Value
        $map      = [regex]::Match($model, 'EVENT_TYPE_MAP[^=]*=\s*\{(?<b>[^}]*)\}').Groups['b'].Value
        $types    = Get-Keys $contract
        $types.Count | Should -BeGreaterThan 0
        @([regex]::Matches($map, '([A-Z_]+):') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object | Should -Be $types
    }

    It 'el background solo emite eventos del contrato' {
        $model   = Get-Src 'app/models/events.model.ts'
        $types   = Get-Keys ([regex]::Match($model, 'interface EventContract \{(?<b>[\s\S]*?)\n\}').Groups['b'].Value)
        $emitted = @([regex]::Matches((Get-Src 'background.ts'), "events\.emit\('([A-Z_]+)'") | ForEach-Object { $_.Groups[1].Value }) | Sort-Object -Unique
        $emitted.Count | Should -BeGreaterThan 0
        foreach ($e in $emitted) { $types | Should -Contain $e }
    }

    It 'el canal rechaza puertos que no vienen de páginas de la extensión' {
        $hub = Get-Src 'app/models/events.ts'
        $hub | Should -Match 'sender\?\.id === chrome\.runtime\.id'
        $hub | Should -Match "sender\.url\?\.startsWith\(chrome\.runtime\.getURL\(''\)\)"
        $hub | Should -Match 'port\.disconnect\(\);'
    }

    It 'la superficie se reconecta si el puerto se cierra' {
        (Get-Src 'app/models/events.ts') | Should -Match 'onDisconnect\.addListener\(\(\) => \{[\s\S]*?scheduleReconnect\(\);'
    }

    It 'MessageService comparte un único puerto (share) y ofrece on$()' {
        $svc = Get-Src 'app/services/message.service.ts'
        $svc | Should -Match 'subscribeToEvents\('
        $svc | Should -Match '\.pipe\(share\(\)\)'
        $svc | Should -Match 'on\$<K extends EventType>'
    }

    It 'el content script anuncia CONTENT_READY y la notificación respeta la preferencia' {
        (Get-Src 'content.ts')    | Should -Match "sendExtensionMessage\('CONTENT_READY', \[\]\)"
        (Get-Src 'background.ts') | Should -Match "if \(notifications\) events\.emit\('NOTIFICATION'"
    }
}
