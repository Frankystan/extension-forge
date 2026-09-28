# Suite Pester 5+ — A-01…A-06 / DOC-01: generador de adaptadores Shadow DOM

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:Adapter  = Join-Path $script:RepoRoot 'scripts' 'Add-ContentAdapter.ps1'
    function New-AdapterWorkspace {
        $ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $ws 'src') -Force | Out-Null
        '{}' | Set-Content (Join-Path $ws 'angular.json')
        return $ws
    }
}

Describe 'Add-ContentAdapter' -Tag 'Unit', 'Tools' {

    It 'crea componente, adaptador, tema y tipos con rutas coherentes (A-01, A-02)' {
        $ws = New-AdapterWorkspace
        & $script:Adapter -WorkspacePath $ws -AdapterType Sidebar -ComponentName MyHTMLPanel 6>$null | Out-Null
        $comp = Join-Path $ws 'src' 'app' 'components' 'my-html-panel' 'my-html-panel.component.ts'
        $adp  = Join-Path $ws 'src' 'content-scripts' 'adapters' 'sidebar-adapter.ts'
        $comp | Should -Exist
        $adp  | Should -Exist
        Join-Path $ws 'src' 'content-scripts' 'adapters' 'adapter-theme.scss' | Should -Exist
        Join-Path $ws 'src' 'content-scripts' 'scss.d.ts' | Should -Exist
        $a = Get-Content -Raw $adp
        $a | Should -Match "from '\.\./\.\./app/components/my-html-panel/my-html-panel\.component'"
        $a | Should -Match "createElement\('app-my-html-panel'\)"
        $a | Should -Match 'export async function bootstrapSidebarAdapter'
        $c = Get-Content -Raw $comp
        $c | Should -Match "selector: 'app-my-html-panel'"
        $c | Should -Match 'export class MyHTMLPanel'
    }

    It 'el componente es compatible con AOT y Shadow DOM (A-03, A-05)' {
        $ws = New-AdapterWorkspace
        & $script:Adapter -WorkspacePath $ws -AdapterType Overlay 6>$null | Out-Null
        $c = Get-Content -Raw (Join-Path $ws 'src' 'app' 'components' 'extension-forge-widget' 'extension-forge-widget.component.ts')
        $c | Should -Match 'ViewEncapsulation\.ShadowDom'
        $c | Should -Not -Match 'templateUrl\s*:|styleUrls?\s*:'
        (Get-Content -Raw (Join-Path $ws 'src' 'content-scripts' 'adapters' 'adapter-theme.scss')) | Should -Match ':host\s*\{\s*@include mat\.theme'
    }

    It 'define tamaño y pointer-events del host por tipo (A-04)' -ForEach @(
        @{ Type = 'Sidebar'; Pattern = 'position: fixed; top: 0; right: 0; width: 24rem;.*height: 100vh' }
        @{ Type = 'Overlay'; Pattern = 'position: fixed; inset: 0;.*pointer-events: none' }
        @{ Type = 'Inline';  Pattern = 'position: relative; display: block; width: 100%' }
    ) {
        $ws = New-AdapterWorkspace
        & $script:Adapter -WorkspacePath $ws -AdapterType $Type -Width 24rem 6>$null | Out-Null
        Get-Content -Raw (Join-Path $ws 'src' 'content-scripts' 'adapters' "$($Type.ToLowerInvariant())-adapter.ts") | Should -Match $Pattern
    }

    It 'Inline usa -TargetSelector' {
        $ws = New-AdapterWorkspace
        & $script:Adapter -WorkspacePath $ws -AdapterType Inline -TargetSelector '#content' 6>$null | Out-Null
        Get-Content -Raw (Join-Path $ws 'src' 'content-scripts' 'adapters' 'inline-adapter.ts') | Should -Match "querySelector\('#content'\)"
    }

    It 'no sobrescribe un componente existente (regla de oro)' {
        $ws = New-AdapterWorkspace
        $comp = Join-Path $ws 'src' 'app' 'components' 'extension-forge-widget' 'extension-forge-widget.component.ts'
        New-Item -ItemType Directory -Path (Split-Path $comp) -Force | Out-Null
        '// mío' | Set-Content $comp
        & $script:Adapter -WorkspacePath $ws -AdapterType Sidebar 6>$null 3>$null | Out-Null
        Get-Content -Raw $comp | Should -Match '// mío'
    }

    It 'valida parámetros: <Name>' -ForEach @(
        @{ Name = 'ComponentName no PascalCase'; Params = @{ AdapterType = 'Sidebar'; ComponentName = 'mi-panel' } }
        @{ Name = 'Width inválido';              Params = @{ AdapterType = 'Sidebar'; Width = '100' } }
        @{ Name = 'selector con comillas';       Params = @{ AdapterType = 'Inline'; TargetSelector = "main'" } }
    ) {
        $ws = New-AdapterWorkspace
        { & $script:Adapter -WorkspacePath $ws @Params 6>$null } | Should -Throw
    }

    It 'rechaza un directorio que no es un proyecto Angular' {
        $ws = Join-Path $TestDrive ([guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $ws | Out-Null
        { & $script:Adapter -WorkspacePath $ws -AdapterType Sidebar 6>$null } | Should -Throw '*angular.json*'
    }

    It 'indica cómo importarlo en content.ts, no en angular.json (DOC-01)' {
        $ws = New-AdapterWorkspace
        $out = & $script:Adapter -WorkspacePath $ws -AdapterType Sidebar 6>&1 3>$null | Out-String
        $out | Should -Match "import \{ bootstrapSidebarAdapter \} from './content-scripts/adapters/sidebar-adapter'"
        $out | Should -Not -Match 'entryPoints'
    }
}
