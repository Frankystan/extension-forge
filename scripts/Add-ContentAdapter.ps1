<#
.SYNOPSIS
    Generador de adaptadores de contenido (Shadow DOM) de ExtensionForge.
.DESCRIPTION
    Crea, en el proyecto de extensión indicado (por defecto, el directorio actual):
      - src/app/components/<kebab>/<kebab>.component.ts — componente Angular standalone
        con ViewEncapsulation.ShadowDom, plantilla y estilos inline (compatibles con AOT).
        Solo si no existe (regla de oro).
      - src/content-scripts/adapters/<tipo>-adapter.ts — puente que crea un host aislado
        (Shadow DOM) en la página y arranca el componente con createApplication.
      - src/content-scripts/adapters/adapter-theme.scss — tema Material 3 aplicado en :host
        del Shadow Root (el tema global de styles.scss no atraviesa el Shadow DOM).
      - src/content-scripts/scss.d.ts — tipos para importar .scss como texto.
    El build (scripts/build-extension.mjs) compila content.ts con AOT (ngc) si existe
    tsconfig.content.json, de modo que el content script no necesita el compilador JIT
    (MV3 bloquea eval/new Function).

    Tipos:
      Sidebar — panel fijo a la derecha, alto completo.
      Overlay — tarjeta flotante centrada; el host no bloquea clics fuera del panel.
      Inline  — bloque insertado al principio de -TargetSelector (por defecto 'main', o body).
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = "$PWD",

    [Parameter(Mandatory = $true, HelpMessage = 'Tipo de adaptador a generar')]
    [ValidateSet('Sidebar', 'Overlay', 'Inline')]
    [string]$AdapterType,

    # Nombre de clase del componente en PascalCase (p. ej. ExtensionForgeWidget).
    [ValidatePattern('^[A-Z][A-Za-z0-9]*$')]
    [string]$ComponentName = 'ExtensionForgeWidget',

    # Ancho del Sidebar / Overlay (CSS).
    [string]$Width = '360px',

    # Solo Inline: selector CSS del contenedor donde se inserta el bloque.
    [string]$TargetSelector = 'main'
)

$ErrorActionPreference = 'Stop'

$WorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath).Path
if (-not (Test-Path (Join-Path $WorkspacePath 'angular.json'))) {
    throw "'$WorkspacePath' no parece un proyecto de extensión (falta angular.json). Ejecuta el script desde tu proyecto o usa -WorkspacePath."
}
if ($Width -notmatch '^\d+(\.\d+)?(px|rem|em|vw|%)$') {
    throw "-Width '$Width' no es una longitud CSS válida (p. ej. 360px, 24rem, 30vw)."
}
if ($TargetSelector -match "['`"\\]") {
    throw "-TargetSelector no puede contener comillas ni barras invertidas."
}

# ExtensionForgeWidget → extension-forge-widget
$kebab    = ([regex]::Replace($ComponentName, '(?<=[a-z0-9])([A-Z])|(?<=[A-Z])([A-Z])(?=[a-z])', '-$1$2')).ToLowerInvariant()
$typeLow  = $AdapterType.ToLowerInvariant()

$created = [System.Collections.Generic.List[string]]::new()
function Write-IfMissing([string]$RelPath, [string]$Content) {
    $full = Join-Path $WorkspacePath $RelPath
    if (Test-Path -LiteralPath $full) {
        Write-Host "  · Ya existe (no se sobrescribe): $RelPath" -ForegroundColor DarkGray
        return $false
    }
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $full -Value $Content -Encoding utf8
    $created.Add($RelPath)
    Write-Host "  ✅ Creado: $RelPath" -ForegroundColor Green
    return $true
}

$adapterRel = "src/content-scripts/adapters/$typeLow-adapter.ts"
if (Test-Path -LiteralPath (Join-Path $WorkspacePath $adapterRel)) {
    Write-Warning "El adaptador '$adapterRel' ya existe. No se sobrescribe (regla de oro)."
    return
}

# ── Componente Angular (standalone, ShadowDom, inline → compatible con ngc AOT) ──
$componentTs = @"
import { ChangeDetectionStrategy, Component, ViewEncapsulation, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';

// Componente montado por los adaptadores de contenido de ExtensionForge.
// Plantilla y estilos inline: el content script se compila con ngc (AOT) y no
// procesa templateUrl/styleUrl con SCSS. ViewEncapsulation.ShadowDom hace que
// Angular inserte los estilos del componente (y de Angular Material) dentro de
// su propio Shadow Root, aislados de la página.
@Component({
  selector: 'app-$kebab',
  standalone: true,
  imports: [MatButtonModule],
  encapsulation: ViewEncapsulation.ShadowDom,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: ``
    <section class="ef-card">
      <h2>ExtensionForge</h2>
      <p>Clics: {{ clicks() }}</p>
      <button mat-flat-button type="button" (click)="clicks.update(n => n + 1)">Pulsar</button>
    </section>
  ``,
  styles: [``
    /* Flex en lugar de height: 100%: funciona igual en páginas en modo quirks. */
    :host { display: flex; flex-direction: column; flex: 1 1 auto; font-family: Roboto, 'Helvetica Neue', sans-serif; }
    .ef-card {
      box-sizing: border-box;
      flex: 1 1 auto;
      padding: 16px;
      background: var(--mat-sys-surface, #fff);
      color: var(--mat-sys-on-surface, #1b1b1f);
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, .25);
    }
    h2 { margin: 0 0 8px; font-size: 18px; }
  ``],
})
export class $ComponentName {
  readonly clicks = signal(0);
}
"@

# ── Estilos del host por tipo (A-04) ──
switch ($AdapterType) {
    'Sidebar' {
        $hostCss = "position: fixed; top: 0; right: 0; width: $Width; max-width: 100vw; height: 100vh; z-index: 2147483647; pointer-events: auto;"
        $anchor  = 'document.body'
        $insert  = 'anchor.appendChild(host);'
    }
    'Overlay' {
        # El host cubre la ventana sin capturar clics; solo el panel los recibe.
        $hostCss = "position: fixed; inset: 0; z-index: 2147483646; pointer-events: none; display: grid; place-items: center;"
        $anchor  = 'document.body'
        $insert  = 'anchor.appendChild(host);'
    }
    'Inline' {
        $hostCss = "position: relative; display: block; width: 100%; margin: 12px 0; z-index: auto;"
        $anchor  = "(document.querySelector('$TargetSelector') ?? document.body)"
        $insert  = 'anchor.prepend(host);'
    }
}
$mountCss = switch ($AdapterType) {
    'Sidebar' { 'display: flex; flex-direction: column; height: 100%;' }
    'Overlay' { "display: block; width: $Width; max-width: calc(100vw - 32px); pointer-events: auto;" }
    'Inline'  { 'display: block;' }
}

$adapterTs = @"
// ---------------------------------------------------------------------------
// Adaptador de contenido ($AdapterType) — Shadow DOM
// Generado por ExtensionForge. Inyecta el componente Angular de forma aislada.
// Uso en src/content.ts:
//   import { bootstrap${AdapterType}Adapter } from './content-scripts/adapters/$typeLow-adapter';
//   void bootstrap${AdapterType}Adapter();
// ---------------------------------------------------------------------------
import { ApplicationRef, provideZonelessChangeDetection } from '@angular/core';
import { createApplication } from '@angular/platform-browser';
import { $ComponentName } from '../../app/components/$kebab/$kebab.component';
import themeCss from './adapter-theme.scss';

const HOST_TAG = 'ext-forge-$typeLow-host';

export async function bootstrap${AdapterType}Adapter(): Promise<ApplicationRef | null> {
  // Evita montar dos veces (p. ej. si el content script se reinyecta).
  if (document.querySelector(HOST_TAG)) {
    return null;
  }

  const host = document.createElement(HOST_TAG);
  // all: initial corta la herencia de estilos de la página hacia el host.
  host.setAttribute('style', 'all: initial; $hostCss');

  const anchor = $anchor as HTMLElement;
  $insert

  // Shadow Root exterior: aísla el host y aplica el tema Material 3 en :host (A-05).
  const shadow = host.attachShadow({ mode: 'open' });
  const theme = document.createElement('style');
  theme.textContent = themeCss;
  shadow.appendChild(theme);

  const mountPoint = document.createElement('app-$kebab');
  mountPoint.setAttribute('style', '$mountCss');
  shadow.appendChild(mountPoint);

  const appRef = await createApplication({ providers: [provideZonelessChangeDetection()] });
  appRef.bootstrap($ComponentName, mountPoint);
  return appRef;
}
"@

$themeScss = @"
@use '@angular/material' as mat;

// Tema Material 3 para los adaptadores de contenido. Se aplica en :host del
// Shadow Root exterior; las variables CSS (--mat-sys-*) se heredan hacia el
// Shadow Root del componente. Ajusta paletas/tipografía como en src/styles.scss.
:host {
  @include mat.theme((
    color: (
      primary: mat.`$azure-palette,
      tertiary: mat.`$blue-palette,
    ),
    typography: Roboto,
    density: 0,
  ));
}
"@

$scssTypes = @"
// Permite importar .scss como texto CSS en los content scripts
// (scripts/build-extension.mjs los compila con sass).
declare module '*.scss' {
  const css: string;
  export default css;
}
"@

$null = Write-IfMissing "src/app/components/$kebab/$kebab.component.ts" $componentTs
$null = Write-IfMissing 'src/content-scripts/adapters/adapter-theme.scss' $themeScss
$null = Write-IfMissing 'src/content-scripts/scss.d.ts' $scssTypes
$null = Write-IfMissing $adapterRel $adapterTs

if (-not (Test-Path (Join-Path $WorkspacePath 'tsconfig.content.json'))) {
    Write-Warning "Falta tsconfig.content.json: sin él, build-extension.mjs no compila content.ts con AOT y el componente Angular no arrancará en el content script. Copia el de la plantilla (Initialize lo añade)."
}

Write-Host ''
Write-Host '  Siguiente paso — importa y arranca el adaptador en src/content.ts:' -ForegroundColor Yellow
Write-Host "    import { bootstrap${AdapterType}Adapter } from './content-scripts/adapters/$typeLow-adapter';" -ForegroundColor White
Write-Host "    void bootstrap${AdapterType}Adapter();" -ForegroundColor White
Write-Host '  El build lo compila con AOT (ngc + esbuild); no hace falta tocar angular.json.' -ForegroundColor DarkGray
Write-Host '  content_scripts.matches de src/manifest.json decide en qué páginas aparece.' -ForegroundColor DarkGray
