<#
.SYNOPSIS
    Busca código dinámico o remoto en un runtime de extensión (P-04).
.DESCRIPTION
    Manifest V3 prohíbe ejecutar código remoto y la CSP de las páginas de extensión
    bloquea eval y similares, así que esos patrones fallan en runtime y las tiendas
    los rechazan. Revisa:
      - *.js / *.mjs (sin *.map): eval(...), new Function(...), Function('...'),
        setTimeout/setInterval con cadena, import('http...').
      - *.html: <script src="http(s)://..."> (script remoto).
      - Restos del cliente de recarga de desarrollo (src/dev/dev-reload.ts), que
        solo debe existir en builds de Development.
    Los comentarios /* ... */ y // ... no se eliminan: un falso positivo se resuelve
    en el código fuente, no desactivando la regla.
.OUTPUTS
    [pscustomobject[]] con Rule, File (relativo a -Path), Line y Snippet.
#>
function Find-ExtensionForgeUnsafeCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $jsRules = [ordered]@{
        'eval()'                      = '(?<![\w$.])eval\s*\('
        'new Function()'              = '\bnew\s+Function\s*\('
        'Function() con cadena'       = '(?<![\w$.])(?<!\bnew\s+)Function\s*\(\s*[''"`]'
        'setTimeout/setInterval con cadena' = '(?<![\w$])set(?:Timeout|Interval)\s*\(\s*[''"`]'
        'import() remoto'             = '\bimport\s*\(\s*[''"`]https?://'
        'cliente de recarga de desarrollo' = 'RELOAD_EXTENSION|\[ExtensionForge\]\[dev-reload\]'
    }
    $htmlRules = [ordered]@{
        'script remoto' = '<script\b[^>]*\bsrc\s*=\s*["'']?(?:https?:)?//'
    }

    $root = (Resolve-Path -LiteralPath $Path).Path
    $findings = [System.Collections.Generic.List[object]]::new()

    $files = Get-ChildItem -LiteralPath $root -Recurse -File |
        Where-Object { $_.Extension -in @('.js', '.mjs', '.html', '.htm') }

    foreach ($file in $files) {
        $rules = if ($file.Extension -in @('.html', '.htm')) { $htmlRules } else { $jsRules }
        $rel   = [System.IO.Path]::GetRelativePath($root, $file.FullName)
        $lines = @(Get-Content -LiteralPath $file.FullName)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = [string]$lines[$i]
            foreach ($rule in $rules.GetEnumerator()) {
                $m = [regex]::Match($line, $rule.Value)
                if ($m.Success) {
                    $start   = [Math]::Max(0, $m.Index - 30)
                    $snippet = $line.Substring($start, [Math]::Min(80, $line.Length - $start)).Trim()
                    $findings.Add([pscustomobject]@{ Rule = $rule.Key; File = $rel; Line = $i + 1; Snippet = $snippet })
                }
            }
        }
    }
    return $findings.ToArray()
}
