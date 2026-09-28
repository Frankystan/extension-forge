<#
.SYNOPSIS
    Genera dinámicamente un manifest.json (Manifest V3) específico por navegador.
.DESCRIPTION
    Chrome  : background.service_worker = "background.js" (type module) + action.
    Firefox : background.scripts = ["background.js"] + action + browser_specific_settings (gecko).
    content_scripts: si se pasa -ContentScripts (p. ej. desde src/manifest.json) se
    respeta tal cual; un array vacío omite la clave. Sin -ContentScripts se usa el
    valor por defecto (matches <all_urls>, js content.js).
#>
function New-ExtensionForgeManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BrowserConfig,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [string]$Version = '1.0.0',
        [string]$Name = 'ExtensionForge Extension',
        [string]$Description = 'Extensión construida con Angular + Angular Material (Manifest V3).',

        # content_scripts del manifest base. Si se omite, se usa <all_urls> + content.js.
        [AllowEmptyCollection()]
        [object[]]$ContentScripts
    )

    $scaffold    = $BrowserConfig['Scaffold']
    $manifestCfg = $BrowserConfig['Manifest']
    $browser     = [string]$BrowserConfig['Browser']

    $manifest = [ordered]@{
        manifest_version = [int]$scaffold['ManifestVersion']
        name             = $Name
        version          = $Version
        description      = $Description
    }

    # Acción (popup): "action" en MV3 para Chrome y Firefox ("browser_action" es de MV2)
    $actionKey = if ($manifestCfg['ActionKey']) { $manifestCfg['ActionKey'] } else { 'action' }
    $manifest[$actionKey] = [ordered]@{ default_popup = 'index.html' }

    # Background: "service_worker" (Chrome) o "scripts" (Firefox)
    $bgKey = if ($manifestCfg['BackgroundKey']) { $manifestCfg['BackgroundKey'] } else { 'service_worker' }
    $background = [ordered]@{}
    if ($browser -eq 'Firefox') {
        $background[$bgKey] = @('background.js')
    }
    else {
        $background[$bgKey] = 'background.js'
        if ($bgKey -eq 'service_worker') { $background['type'] = 'module' }
    }
    $manifest['background'] = $background

    # Permisos: base + específicos del navegador (sin duplicados)
    $permissions = [System.Collections.Generic.List[object]]::new()
    if ($manifestCfg['Permissions'])        { foreach ($p in $manifestCfg['Permissions'])        { if ($permissions -notcontains $p) { $permissions.Add($p) } } }
    if ($manifestCfg['SpecificPermissions']) { foreach ($p in $manifestCfg['SpecificPermissions']) { if ($permissions -notcontains $p) { $permissions.Add($p) } } }
    if ($permissions.Count -gt 0) { $manifest['permissions'] = @($permissions) }

    # Content script
    if ($PSBoundParameters.ContainsKey('ContentScripts')) {
        $scripts = @($ContentScripts | Where-Object { $null -ne $_ })
        for ($i = 0; $i -lt $scripts.Count; $i++) {
            $cs = $scripts[$i]
            $csMatches = if ($cs -is [System.Collections.IDictionary]) { $cs['matches'] } else { $cs.matches }
            if (-not $csMatches -or @($csMatches).Count -eq 0) {
                throw "content_scripts[$i] no define 'matches' (obligatorio en Manifest V3)."
            }
        }
        if ($scripts.Count -gt 0) { $manifest['content_scripts'] = $scripts }
    }
    else {
        $manifest['content_scripts'] = @(
            [ordered]@{
                matches = @('<all_urls>')
                js      = @('content.js')
            }
        )
    }

    # Ajustes específicos de navegador (gecko) para Firefox
    if ($browser -eq 'Firefox' -and $manifestCfg['BrowserSpecificSettings']) {
        $manifest['browser_specific_settings'] = $manifestCfg['BrowserSpecificSettings']
    }

    # Iconos (solo si existen en el output)
    $icons = [ordered]@{}
    foreach ($size in @(16, 48, 128)) {
        $iconRel = "assets/icons/icon$size.png"
        if (Test-Path (Join-Path $OutputPath $iconRel)) {
            $icons["$size"] = $iconRel
        }
    }
    if ($icons.Count -gt 0) { $manifest['icons'] = $icons }

    $json = $manifest | ConvertTo-Json -Depth 12
    Set-Content -Path (Join-Path $OutputPath 'manifest.json') -Value $json -Encoding utf8
}
