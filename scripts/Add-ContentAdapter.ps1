<#
.SYNOPSIS
    Generador de adaptadores de contenido (Shadow DOM) de ExtensionForge.
.DESCRIPTION
    Crea un puente TypeScript que inyecta una app Angular dentro de un Shadow DOM
    (en modo abierto) en una web ajena, evitando fugas de estilos CSS.
    Soporta los tipos: Sidebar, Overlay, Inline.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter(Mandatory = $true, HelpMessage = 'Tipo de adaptador a generar')]
    [ValidateSet('Sidebar', 'Overlay', 'Inline')]
    [string]$AdapterType,
    [string]$ComponentName = 'ExtensionForgeWidget'
)

$ErrorActionPreference = 'Stop'

$AdaptersDir = Join-Path $WorkspacePath 'src\content-scripts\adapters'
$AdapterFileName = ("{0}-adapter.ts" -f $AdapterType.ToLowerInvariant())
$AdapterPath = Join-Path $AdaptersDir $AdapterFileName

if (Test-Path $AdapterPath) {
    Write-Warning "El adaptador '$AdapterFileName' ya existe. No se sobrescribe (regla de oro)."
    return
}

if (-not (Test-Path $AdaptersDir)) {
    New-Item -ItemType Directory -Path $AdaptersDir -Force | Out-Null
}

switch ($AdapterType) {
    'Sidebar'  { $AnchorElement = 'document.body';              $CssZIndex = '2147483647' }
    'Overlay'  { $AnchorElement = 'document.body';              $CssZIndex = '999999' }
    'Inline'   { $AnchorElement = "document.querySelector('main') || document.body"; $CssZIndex = '1000' }
    default    { $AnchorElement = 'document.body';              $CssZIndex = '1000' }
}

$Position = if ($AdapterType -eq 'Sidebar') { 'fixed' } else { 'absolute' }

$template = @"
// ---------------------------------------------------------------------------
// Adaptador de contenido ($AdapterType) — Shadow DOM
// Generado por ExtensionForge. Inyecta el componente Angular de forma aislada.
// ---------------------------------------------------------------------------
import { createApplication } from '@angular/platform-browser';
import { ApplicationConfig } from '@angular/core';
import { $ComponentName } from '../../app/components/$($ComponentName.ToLowerInvariant())/$($ComponentName.ToLowerInvariant()).component';

export function bootstrap${AdapterType}Adapter(): void {
  const host = document.createElement('ext-forge-$($AdapterType.ToLowerInvariant())-host');
  host.style.position = '$Position';
  host.style.zIndex = '$CssZIndex';
  host.style.top = '0';
  host.style.left = '0';

  const anchor = $AnchorElement as HTMLElement;
  anchor.appendChild(host);

  const shadow = host.attachShadow({ mode: 'open' });
  const mountPoint = document.createElement('app-$($ComponentName.ToLowerInvariant())');
  shadow.appendChild(mountPoint);

  const appConfig: ApplicationConfig = { providers: [] };
  createApplication(appConfig).then((appRef) => {
    appRef.bootstrap($ComponentName, mountPoint);
  });
}

// Auto-ejecución: descomenta para arrancar el adaptador al cargar el content script.
// bootstrap${AdapterType}Adapter();
"@

Set-Content -Path $AdapterPath -Value $template -Encoding utf8

Write-Host "  ✅ Adaptador '$AdapterType' creado en: $AdapterPath" -ForegroundColor Green
Write-Host '  ⚠ Recuerda añadirlo a los entryPoints de angular.json y al array content_scripts del manifest.' -ForegroundColor Yellow
