<#
.SYNOPSIS
    Asistente interactivo (Wizard) de ExtensionForge.
.DESCRIPTION
    Menú interactivo en consola que guía al usuario desde el inicio hasta el
    scaffolding completo de una extensión Angular + Angular Material (Manifest V3).
    Genera y ejecuta dinámicamente los comandos de ExtensionForge, e incluye un
    glosario (Cheat Sheet) embebido.
    Uso: ./scripts/Start-ExtensionForgeWizard.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Show-Header {
    Clear-Host
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '  ║              🔨 EXTENSION FORGE v2.1                 ║' -ForegroundColor Cyan
    Write-Host '  ║     Asistente Interactivo - Generador de comandos    ║' -ForegroundColor Cyan
    Write-Host '  ╚══════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''
}

function Get-MenuChoice {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][System.Collections.Specialized.OrderedDictionary]$Options
    )

    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host '  ' + ('-' * 58) -ForegroundColor DarkGray
    $i = 1
    foreach ($key in $Options.Keys) {
        Write-Host ("  {0}. {1}" -f $i, $key) -ForegroundColor White
        $i++
    }
    Write-Host ''

    while ($true) {
        $selection = Read-Host '  Selecciona una opción'
        $num = 0
        if ([int]::TryParse($selection, [ref]$num) -and $num -ge 1 -and $num -le $Options.Count) {
            $value = @($Options.Values)[$num - 1]
            Write-Host ''
            return $value
        }
        Write-Host '  ⚠ Opción no válida. Inténtalo de nuevo.' -ForegroundColor Red
    }
}

function Show-CheatSheet {
    $sheetOptions = [ordered]@{
        'Comandos del Módulo Principal (Invoke-ExtensionForge)' = 'MainCmdlets'
        'Scripts de Automatización (carpeta /scripts/)'          = 'Scripts'
        'Ejemplo de Flujo Completo (De 0 a Producción)'          = 'Flow'
        '⬅ Volver al Menú Principal'                             = 'Back'
    }

    while ($true) {
        Show-Header
        $choice = Get-MenuChoice -Title '📖 GLOSARIO / CHEAT SHEET' -Options $sheetOptions

        switch ($choice) {
            'MainCmdlets' {
                Show-Header
                Write-Host '  📦 COMANDOS DEL MÓDULO PRINCIPAL' -ForegroundColor Green
                Write-Host '  ------------------------------------------------------------' -ForegroundColor DarkGray
                Write-Host '  Doctor      → Invoke-ExtensionForge -Action Doctor' -ForegroundColor White
                Write-Host '                Verifica requisitos (Node 22+, Angular 22+, PowerShell 7.6.6+).'
                Write-Host '  Initialize  → Invoke-ExtensionForge -Action Initialize -Browser All -Environment Development' -ForegroundColor White
                Write-Host '                Genera el andamiaje (background, content scripts, manifests, Angular Material). No sobrescribe.'
                Write-Host '  Build       → Invoke-ExtensionForge -Action Build -Browser Chrome -Environment Production' -ForegroundColor White
                Write-Host '                Ejecuta Angular CLI (AOT/SourceMaps dinámicos) y separa dist/ por navegador.'
                Write-Host '  Validate    → Invoke-ExtensionForge -Action Validate -Environment Production' -ForegroundColor White
                Write-Host '                Verifica manifest_version 3 y directivas CSP (unsafe-eval) antes de publicar.'
                Write-Host '  Package     → Invoke-ExtensionForge -Action Package -Browser Firefox -Environment Production' -ForegroundColor White
                Write-Host '                Crea los .zip listos para la tienda leyendo la versión del package.json.'
                Write-Host '  InstallDev  → Invoke-ExtensionForge -Action InstallDev -Browser All' -ForegroundColor White
                Write-Host '                Genera comandos de sideload (Chrome) y web-ext (Firefox) para testeo.'
                Write-Host ''
                Read-Host '  Pulsa ENTER para continuar'
            }
            'Scripts' {
                Show-Header
                Write-Host '  🤖 SCRIPTS DE AUTOMATIZACIÓN (/scripts/)' -ForegroundColor Green
                Write-Host '  ------------------------------------------------------------' -ForegroundColor DarkGray
                Write-Host '  Instalación segura      → ./scripts/Install-ExtensionForge.ps1 -Force' -ForegroundColor White
                Write-Host '  Instalación desarrollo   → ./scripts/Install-ExtensionForge.ps1 -Symlink' -ForegroundColor White
                Write-Host '  Adaptadores Shadow DOM   → ./scripts/Add-ContentAdapter.ps1 -AdapterType Sidebar' -ForegroundColor White
                Write-Host '  CI local                 → ./scripts/Invoke-LocalCI.ps1' -ForegroundColor White
                Write-Host '  CD local (producción)    → ./scripts/Invoke-LocalCD.ps1' -ForegroundColor White
                Write-Host '  Versionado SemVer        → ./scripts/Invoke-SemVerRelease.ps1 -BumpType patch -DryRun' -ForegroundColor White
                Write-Host ''
                Read-Host '  Pulsa ENTER para continuar'
            }
            'Flow' {
                Show-Header
                Write-Host '  🎯 FLUJO COMPLETO (DE 0 A PRODUCCIÓN)' -ForegroundColor Green
                Write-Host '  ------------------------------------------------------------' -ForegroundColor DarkGray
                Write-Host '  1. npm install' -ForegroundColor White
                Write-Host '  2. Invoke-ExtensionForge -Action Doctor' -ForegroundColor White
                Write-Host '  3. Invoke-ExtensionForge -Action Build -Browser All -Environment Development' -ForegroundColor White
                Write-Host '  4. ./scripts/Add-ContentAdapter.ps1 -AdapterType Sidebar   (opcional)' -ForegroundColor White
                Write-Host '  5. ./scripts/Invoke-LocalCI.ps1' -ForegroundColor White
                Write-Host '  6. ./scripts/Invoke-LocalCD.ps1' -ForegroundColor White
                Write-Host ''
                Read-Host '  Pulsa ENTER para continuar'
            }
            'Back' {
                return
            }
        }
    }
}

function Execute-Command {
    param([Parameter(Mandatory = $true)][string]$CommandStr)

    Write-Host ''
    Write-Host '  📋 Comando generado:' -ForegroundColor Cyan
    Write-Host "     $CommandStr" -ForegroundColor White
    Write-Host ''

    $answer = Read-Host '  ¿Deseas ejecutarlo ahora? (S/n)'
    if ($answer -notmatch '^(n|N|no|NO|No)$') {
        Write-Host ''
        Write-Host '  ▶ Ejecutando...' -ForegroundColor Green
        Write-Host ''
        if ($CommandStr -match 'Invoke-ExtensionForge') {
            # Preferir SIEMPRE el módulo local del repositorio (con los cambios más recientes),
            # para no usar una copia instalada en PSModulePath que pueda estar desactualizada.
            $localModule = Join-Path $PSScriptRoot '..\src\ExtensionForge\ExtensionForge.psd1'
            if (Test-Path $localModule) {
                Import-Module $localModule -Force
            }
            elseif (-not (Get-Module -Name ExtensionForge)) {
                Import-Module ExtensionForge -ErrorAction SilentlyContinue
            }
        }
        try {
            Invoke-Expression $CommandStr
        }
        catch {
            Write-Host "  ❌ Error de ejecución: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ''
        Read-Host '  Pulsa ENTER para continuar'
    }
}

function Start-Wizard {
    $mainOptions = [ordered]@{
        '🩺 Doctor (verificar requisitos)'                     = 'Doctor'
        '🏗 Initialize (generar andamiaje/scaffolding)'       = 'Initialize'
        '🔨 Build (compilar la extensión)'                    = 'Build'
        '✅ Validate (validar MV3 y CSP)'                     = 'Validate'
        '🧪 InstallDev (sideload / carga en desarrollo)'      = 'InstallDev'
        '📦 Package (empaquetar para la tienda)'              = 'Package'
        '🛠 Herramientas Extra (Adaptadores, CI/CD, SemVer)' = 'Tools'
        '📖 Ver Glosario / Cheat Sheet'                       = 'CheatSheet'
        '❌ Salir'                                            = 'Exit'
    }

    while ($true) {
        Show-Header
        $action = Get-MenuChoice -Title '¿Qué acción deseas realizar?' -Options $mainOptions

        if ($action -eq 'Exit') {
            Write-Host '  👋 ¡Hasta pronto!' -ForegroundColor Cyan
            return
        }

        if ($action -eq 'CheatSheet') {
            Show-CheatSheet
            continue
        }

        if ($action -eq 'Tools') {
            $toolOptions = [ordered]@{
                '🎨 AddAdapter (Sidebar / Overlay / Inline)' = 'AddAdapter'
                '🧪 Invoke-LocalCI (pruebas pre-commit)'      = 'LocalCI'
                '🚀 Invoke-LocalCD (empaquetado producción)'  = 'LocalCD'
                '🏷 SemVer (versionado explícito)'            = 'SemVer'
                '⬅ Volver'                                    = 'Back'
            }
            Show-Header
            $tool = Get-MenuChoice -Title '🛠 HERRAMIENTAS EXTRA' -Options $toolOptions

            switch ($tool) {
                'AddAdapter' {
                    $adapterOptions = [ordered]@{ 'Sidebar' = 'Sidebar'; 'Overlay' = 'Overlay'; 'Inline' = 'Inline' }
                    Show-Header
                    $adapter = Get-MenuChoice -Title '🎨 TIPO DE ADAPTADOR (Shadow DOM)' -Options $adapterOptions
                    Execute-Command "& `"$PSScriptRoot\Add-ContentAdapter.ps1`" -AdapterType $adapter"
                }
                'LocalCI' {
                    Execute-Command "& `"$PSScriptRoot\Invoke-LocalCI.ps1`""
                }
                'LocalCD' {
                    Execute-Command "& `"$PSScriptRoot\Invoke-LocalCD.ps1`""
                }
                'SemVer' {
                    $semverOptions = [ordered]@{
                        'Patch (bugfix)'           = 'patch'
                        'Minor (feature)'          = 'minor'
                        'Major (breaking)'         = 'major'
                    }
                    Show-Header
                    $bump = Get-MenuChoice -Title '🏷 TIPO DE INCREMENTO DE VERSIÓN' -Options $semverOptions
                    Execute-Command "& `"$PSScriptRoot\Invoke-SemVerRelease.ps1`" -BumpType $bump"
                }
                'Back' { continue }
            }
            continue
        }

        # Acciones del módulo principal
        $needsBrowser = $action -in @('Initialize', 'Build', 'Package', 'InstallDev')
        $needsEnvironment = $action -in @('Initialize', 'Build', 'Validate', 'Package')

        $browser = 'All'
        if ($needsBrowser) {
            $browserOptions = [ordered]@{
                'Ambos (Chrome y Firefox)' = 'All'
                'Solo Chrome'               = 'Chrome'
                'Solo Firefox'              = 'Firefox'
            }
            Show-Header
            $browser = Get-MenuChoice -Title '🌐 NAVEGADOR DESTINO' -Options $browserOptions
        }

        $environment = 'Development'
        if ($needsEnvironment) {
            $envOptions = [ordered]@{
                'Desarrollo'   = 'Development'
                'Staging'      = 'Staging'
                'Producción'   = 'Production'
            }
            Show-Header
            $environment = Get-MenuChoice -Title '⚙ ENTORNO' -Options $envOptions
        }

        $template = 'angular-mv3'
        if ($action -eq 'Initialize') {
            $templateOptions = [ordered]@{
                'Base (Popup + Background + Content Script)'      = 'angular-mv3'
                'Demo ForgeNotes (Popup + SidePanel + Options)'   = 'angular-mv3-demo'
            }
            Show-Header
            $template = Get-MenuChoice -Title '🧩 PLANTILLA' -Options $templateOptions
        }

        # ID de Firefox (gecko.id): obligatorio para firmar MV3 en AMO
        $firefoxId = ''
        if ($action -eq 'Initialize' -and $browser -in @('Firefox', 'All')) {
            Show-Header
            Write-Host '  🦊 ID DE FIREFOX (browser_specific_settings.gecko.id)' -ForegroundColor Cyan
            Write-Host "     Formato: 'nombre@dominio' (p. ej. mi-extension@mi-dominio.dev) o '{GUID}'." -ForegroundColor DarkGray
            Write-Host '     Pulsa ENTER para omitirlo (podrás definirlo después en src/manifest.json).' -ForegroundColor DarkGray
            while ($true) {
                $firefoxId = (Read-Host '  ID').Trim()
                if (-not $firefoxId) { break }
                $valid = ($firefoxId -match '^[a-zA-Z0-9-._]*@[a-zA-Z0-9-._]+$' -and $firefoxId.Length -le 80) -or
                         ($firefoxId -match '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$')
                if ($valid -and $firefoxId -notmatch '@ficticio\.com$') { break }
                Write-Host '  ⚠ ID no válido. Usa nombre@dominio o {GUID}.' -ForegroundColor Yellow
            }
        }

        $parts = @("Invoke-ExtensionForge", "-Action $action")
        if ($needsBrowser)     { $parts += "-Browser $browser" }
        if ($needsEnvironment) { $parts += "-Environment $environment" }
        if ($action -eq 'Initialize') { $parts += "-Template $template" }
        if ($firefoxId)               { $parts += "-FirefoxExtensionId '$firefoxId'" }

        Execute-Command ($parts -join ' ')
    }
}

Start-Wizard
