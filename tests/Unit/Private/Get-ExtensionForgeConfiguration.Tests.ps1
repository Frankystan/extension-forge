# Suite Pester 5+ — motor de configuración (deep merge) de ExtensionForge
# Ejecutar: Invoke-Pester -Path ./tests/Unit/Private
#
# Dos bloques:
#   1. Contrato con los PSD1 reales de src/ExtensionForge/Config (InModuleScope).
#   2. Semántica del merge con PSD1 de prueba en TestDrive (función dot-sourced
#      desde una copia aislada, para no depender de los valores reales).

BeforeAll {
    $script:RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:ModuleRoot = Join-Path $script:RepoRoot 'src' 'ExtensionForge'
    Import-Module (Join-Path $script:ModuleRoot 'ExtensionForge.psd1') -Force
}

AfterAll {
    Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ExtensionForgeConfiguration — contrato con Config/ real' -Tag 'Private', 'Config' {

    It 'No se exporta: es una función privada del módulo' {
        (Get-Command -Module ExtensionForge).Name | Should -Not -Contain 'Get-ExtensionForgeConfiguration'
    }

    It 'Usa Development / All como valores por defecto' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration
            $cfg['Environment'] | Should -Be 'Development'
            $cfg['Browser']     | Should -Be 'All'
            $cfg['Angular']['Configuration'] | Should -Be 'development'
            $cfg['Angular']['SourceMap']     | Should -BeTrue
            $cfg['Runtime']['EnableHotReload'] | Should -BeTrue
        }
    }

    It 'Conserva las secciones y claves base de defaults.psd1' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Environment Production -Browser Firefox
            foreach ($section in 'Paths', 'Angular', 'Scaffold', 'Manifest', 'Runtime') {
                $cfg.ContainsKey($section) | Should -BeTrue -Because "la sección '$section' viene de defaults.psd1"
            }
            $cfg['Paths']['Output']              | Should -Be 'dist/extension'
            $cfg['Paths']['ManifestSrc']         | Should -Be 'src/manifest.json'
            $cfg['Scaffold']['ManifestVersion']  | Should -Be 3
        }
    }

    It 'Production sobrescribe solo las claves que declara (deep merge, no reemplazo)' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Environment Production
            $cfg['Angular']['Configuration']   | Should -Be 'production'
            $cfg['Angular']['Optimization']    | Should -BeTrue
            $cfg['Angular']['SourceMap']       | Should -BeFalse
            $cfg['Angular']['Aot']             | Should -BeTrue
            $cfg['Angular']['ExtractLicenses'] | Should -BeTrue
            # Claves de Angular no presentes en production.psd1 → se heredan de defaults
            $cfg['Angular']['Command']         | Should -Be 'npx ng build'
            $cfg['Angular']['OutputHashing']   | Should -Be 'none'
            $cfg['Angular']['BaseHref']        | Should -Be '/'
            $cfg['Runtime']['EnableHotReload'] | Should -BeFalse
            $cfg['Runtime']['LogFile']         | Should -Be 'production.log'
        }
    }

    It 'Staging optimiza pero mantiene SourceMaps' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Environment Staging
            $cfg['Angular']['Optimization'] | Should -BeTrue
            $cfg['Angular']['SourceMap']    | Should -BeTrue
            $cfg['Runtime']['LogVerbosity'] | Should -Be 'Info'
        }
    }

    It 'Browser All no aplica ninguna capa de navegador' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Browser All
            $cfg['Manifest']['BackgroundKey'] | Should -Be 'service_worker'
            $cfg['Manifest']['BrowserSpecificSettings'].Count | Should -Be 0
        }
    }

    It 'Chrome mantiene service_worker y action' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Browser Chrome
            $cfg['Browser']                   | Should -Be 'Chrome'
            $cfg['Manifest']['BackgroundKey'] | Should -Be 'service_worker'
            $cfg['Manifest']['ActionKey']     | Should -Be 'action'
            $cfg['Manifest']['BrowserSpecificSettings'].Count | Should -Be 0
        }
    }

    It 'Firefox aplica scripts, browser_action y gecko anidado' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Environment Production -Browser Firefox
            $cfg['Manifest']['BackgroundKey'] | Should -Be 'scripts'
            $cfg['Manifest']['ActionKey']     | Should -Be 'browser_action'
            $gecko = $cfg['Manifest']['BrowserSpecificSettings']['gecko']
            $gecko['id']                 | Should -Be 'extensionforge@ficticio.com'
            $gecko['strict_min_version'] | Should -Be '109.0'
            # Las capas de entorno siguen vigentes tras aplicar la de navegador
            $cfg['Angular']['Optimization'] | Should -BeTrue
        }
    }

    It 'Los arrays se reemplazan, no se concatenan' {
        InModuleScope 'ExtensionForge' {
            $cfg = Get-ExtensionForgeConfiguration -Browser Firefox
            @($cfg['Manifest']['SpecificPermissions']) | Should -Be @('contextMenus')
            # Permissions no está en firefox.psd1 → se hereda intacto de defaults
            @($cfg['Manifest']['Permissions']) | Should -Be @('storage', 'activeTab')
        }
    }

    It 'Las llamadas sucesivas no se contaminan entre sí' {
        InModuleScope 'ExtensionForge' {
            $null = Get-ExtensionForgeConfiguration -Environment Production -Browser Firefox
            $cfg  = Get-ExtensionForgeConfiguration -Environment Development -Browser Chrome
            $cfg['Manifest']['BrowserSpecificSettings'].ContainsKey('gecko') | Should -BeFalse
            $cfg['Angular']['Optimization'] | Should -BeFalse
            $cfg['Runtime']['LogFile']      | Should -Be 'dev.log'
        }
    }

    It 'La dimensión activa prevalece sobre la clave Browser del PSD1' {
        InModuleScope 'ExtensionForge' {
            (Get-ExtensionForgeConfiguration -Browser Firefox)['Browser'] | Should -Be 'Firefox'
            (Get-ExtensionForgeConfiguration -Browser All)['Browser']     | Should -Be 'All'
        }
    }

    It 'Rechaza entornos y navegadores fuera del ValidateSet' {
        InModuleScope 'ExtensionForge' {
            { Get-ExtensionForgeConfiguration -Environment 'QA' }    | Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-ExtensionForgeConfiguration'
            { Get-ExtensionForgeConfiguration -Browser 'Safari' }    | Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-ExtensionForgeConfiguration'
        }
    }
}

Describe 'Get-ExtensionForgeConfiguration — semántica del merge con fixtures' -Tag 'Private', 'Config' {

    BeforeEach {
        # Estructura aislada: <root>/Private/<función>.ps1 y <root>/Config/...
        # La función resuelve Config/ con $PSScriptRoot, así que al dot-sourcearla
        # desde esta copia leerá exclusivamente los fixtures.
        $script:Fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $privateDir = Join-Path $script:Fixture 'Private'
        $configDir  = Join-Path $script:Fixture 'Config'
        New-Item -ItemType Directory -Path $privateDir, (Join-Path $configDir 'environments'), (Join-Path $configDir 'browsers') -Force | Out-Null
        Copy-Item (Join-Path $script:ModuleRoot 'Private' 'Get-ExtensionForgeConfiguration.ps1') $privateDir

        Set-Content (Join-Path $configDir 'defaults.psd1') -Value @'
@{
    Level1 = @{
        Keep   = 'base'
        Change = 'base'
        Level2 = @{ Keep = 'base'; Change = 'base'; Level3 = @{ Deep = 'base' } }
    }
    List   = @('a', 'b')
    Scalar = 'base'
}
'@
        Set-Content (Join-Path $configDir 'environments' 'production.psd1') -Value @'
@{
    Level1 = @{ Change = 'env'; Level2 = @{ Change = 'env'; Level3 = @{ Deep = 'env' } } }
    Scalar = 'env'
    EnvOnly = 'env'
}
'@
        Set-Content (Join-Path $configDir 'browsers' 'chrome.psd1') -Value @'
@{
    Level1 = @{ Level2 = @{ Change = 'browser' } }
    List   = @('c')
    Scalar = @{ NowATable = $true }
}
'@
        . (Join-Path $privateDir 'Get-ExtensionForgeConfiguration.ps1')
    }

    It 'Fusiona recursivamente hasta tres niveles conservando claves no sobrescritas' {
        $cfg = Get-ExtensionForgeConfiguration -Environment Production -Browser All
        $cfg.Level1.Keep                | Should -Be 'base'
        $cfg.Level1.Change              | Should -Be 'env'
        $cfg.Level1.Level2.Keep         | Should -Be 'base'
        $cfg.Level1.Level2.Change       | Should -Be 'env'
        $cfg.Level1.Level2.Level3.Deep  | Should -Be 'env'
        $cfg.EnvOnly                    | Should -Be 'env'
    }

    It 'Respeta la precedencia defaults < entorno < navegador' {
        $cfg = Get-ExtensionForgeConfiguration -Environment Production -Browser Chrome
        $cfg.Level1.Level2.Change      | Should -Be 'browser'
        $cfg.Level1.Level2.Level3.Deep | Should -Be 'env'
        $cfg.Level1.Change             | Should -Be 'env'
    }

    It 'Un valor de tipo distinto reemplaza al anterior (escalar → hashtable)' {
        $cfg = Get-ExtensionForgeConfiguration -Environment Production -Browser Chrome
        $cfg.Scalar           | Should -BeOfType [hashtable]
        $cfg.Scalar.NowATable | Should -BeTrue
    }

    It 'Reemplaza arrays completos' {
        @((Get-ExtensionForgeConfiguration -Browser Chrome).List) | Should -Be @('c')
    }

    It 'Omite en silencio las capas cuyo PSD1 no existe' {
        # No hay environments/development.psd1 ni browsers/firefox.psd1 en el fixture
        $cfg = Get-ExtensionForgeConfiguration -Environment Development -Browser Firefox
        $cfg.Scalar       | Should -Be 'base'
        $cfg.Level1.Change | Should -Be 'base'
        $cfg.ContainsKey('EnvOnly') | Should -BeFalse
        $cfg.Environment  | Should -Be 'Development'
        $cfg.Browser      | Should -Be 'Firefox'
    }

    It 'Lanza una excepción si falta defaults.psd1' {
        Remove-Item (Join-Path $script:Fixture 'Config' 'defaults.psd1')
        { Get-ExtensionForgeConfiguration } | Should -Throw '*defaults.psd1*'
    }
}
