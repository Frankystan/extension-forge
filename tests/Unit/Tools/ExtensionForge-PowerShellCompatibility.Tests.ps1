# Suite Pester 5 — compatibilidad de todos los scripts con PowerShell 7.6.6
# Ejecutar: Invoke-Pester -Path ./tests
#
# Hace dot-source del validador scripts/Test-ExtensionForgePowerShellCompatibility.ps1
# (sin ejecutarlo) y comprueba que ningún .ps1/.psm1/.psd1 del repositorio requiera
# una versión de PowerShell superior a la establecida para el proyecto.

BeforeAll {
    $RepoRoot  = Resolve-Path "$PSScriptRoot\..\..\.."
    $Validator = Resolve-Path "$PSScriptRoot\..\..\..\scripts\Test-ExtensionForgePowerShellCompatibility.ps1"
    . $Validator
}

Describe 'Compatibilidad con la versión mínima de PowerShell (7.6.6)' -Tag 'Compatibility' {

    It 'Todos los scripts (.ps1/.psm1/.psd1) son compatibles con PowerShell 7.6.6' {
        $Issues = @(Test-ExtensionForgePowerShellCompatibility -Path $RepoRoot -MinimumVersion '7.6.6' -PassThru)

        foreach ($Issue in @($Issues | Where-Object { $_.Severity -eq 'Error' })) {
            $Where = if ($Issue.Line) { " (línea $($Issue.Line))" } else { '' }
            Write-Host "  ❌ $($Issue.File): $($Issue.Message)$Where" -ForegroundColor Red
        }

        @($Issues | Where-Object { $_.Severity -eq 'Error' }).Count | Should -Be 0
    }

    It 'El manifiesto del módulo declara el piso exacto del proyecto (7.6.6)' {
        $Manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $RepoRoot 'src\ExtensionForge\ExtensionForge.psd1')
        $Manifest.PowerShellVersion | Should -Be '7.6.6'
    }

    It 'El Doctor exige el piso de PowerShell del proyecto (7.6.6+)' {
        $DoctorFile = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'src\ExtensionForge\Public\Test-ExtensionForgeDoctor.ps1')
        $DoctorFile | Should -Match "7\.6\.6"
    }
}
