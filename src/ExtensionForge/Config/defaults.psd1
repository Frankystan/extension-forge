<#
.SYNOPSIS
    Configuraciones globales por defecto de ExtensionForge.
.DESCRIPTION
    Base principal de dimensiones, rutas y switches que luego será sobrescrita
    por el entorno (Development/Staging/Production) y el navegador (Chrome/Firefox)
    mediante deep-merge (Get-ExtensionForgeConfiguration).
#>
@{
    # Rutas base relativas al $WorkspacePath
    Paths = @{
        Source      = "src"
        Output      = "dist/extension"
        Logs        = "logs"
        Packages    = "dist/packages"
        ManifestSrc = "src/manifest.json"
    }

    # Configuraciones de compilación de Angular
    Angular = @{
        Command         = "npx ng build"
        Configuration   = "development"
        BaseHref        = "/"
        Aot             = $false
        Optimization    = $false
        SourceMap       = $true
        ExtractLicenses = $false
        OutputHashing   = "none"
    }

    # Parámetros del andamiaje (Scaffold)
    Scaffold = @{
        IncludePopup         = $true
        IncludeSidebar       = $true
        IncludeOptions       = $true
        IncludeDiagnostics   = $true
        IncludeBackground    = $true
        IncludeContentScript = $true
        ManifestVersion      = 3
        UseAngularMaterial   = $true
        DefaultName          = "ExtensionForge Extension"
        DefaultDescription   = "Extensión construida con Angular + Angular Material (Manifest V3)."
    }

    # Base del manifest (se completa con la capa de navegador)
    Manifest = @{
        Version             = "1.0.0"
        Permissions         = @("storage", "activeTab")
        BackgroundKey       = "service_worker"
        ActionKey           = "action"
        SpecificPermissions = @()
        BrowserSpecificSettings = @{}
    }

    # Comportamiento en tiempo de ejecución
    Runtime = @{
        EnableHotReload = $true
        LogVerbosity    = "Debug"
        LogFile         = "dev.log"
    }
}
