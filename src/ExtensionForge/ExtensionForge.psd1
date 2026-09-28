@{
    RootModule        = 'ExtensionForge.psm1'
    ModuleVersion     = '2.1.0'
    GUID              = '9f4e2a1b-7c3d-4e5f-8a6b-1d2e3f4a5b6c'
    Author            = 'ExtensionForge Team'
    CompanyName       = 'ExtensionForge'
    Copyright         = '(c) 2026. Todos los derechos reservados.'
    Description       = 'Módulo para automatizar el desarrollo, la producción y el empaquetado de extensiones Angular (Manifest V3) compatibles con Google Chrome y Mozilla Firefox.'
    PowerShellVersion = '7.6.6'

    FunctionsToExport = @(
        'Invoke-ExtensionForge',
        'Test-ExtensionForgeDoctor',
        'Initialize-ExtensionForgeProject',
        'Build-ExtensionForgeProject',
        'Test-ExtensionForgePackage',
        'New-ExtensionForgePackage',
        'Install-ExtensionForgeDevelopment'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Angular', 'AngularMaterial', 'ManifestV3', 'Chrome', 'Firefox', 'Extension', 'Scaffold', 'DevOps')
            LicenseUri = 'https://opensource.org/license/mit'
            ProjectUri = 'https://github.com/ficticio/extension-forge'
        }
    }
}
