# Suite Pester 5+ — P-04: código dinámico/remoto en los bundles de Production
# Ejecutar: Invoke-Pester -Path ./tests/Unit/Private

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'src' 'ExtensionForge' 'ExtensionForge.psd1') -Force

    function New-Runtime([hashtable]$Files) {
        $ws  = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $dir = Join-Path $ws 'dist' 'extension' 'chrome'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [ordered]@{ manifest_version = 3; name = 'T'; version = '1.0.0'; action = @{ default_popup = 'index.html' } } |
            ConvertTo-Json | Set-Content (Join-Path $dir 'manifest.json')
        foreach ($k in $Files.Keys) { Set-Content -Path (Join-Path $dir $k) -Value $Files[$k] }
        return $ws
    }
    function Find-In([string]$Ws) {
        InModuleScope 'ExtensionForge' -Parameters @{ P = (Join-Path $Ws 'dist' 'extension' 'chrome') } {
            param($P) Find-ExtensionForgeUnsafeCode -Path $P
        }
    }
}

AfterAll { Remove-Module ExtensionForge -Force -ErrorAction SilentlyContinue }

Describe 'Find-ExtensionForgeUnsafeCode' -Tag 'Private', 'CSP' {

    It 'detecta <Rule>' -ForEach @(
        @{ Rule = 'eval()';                            Code = 'var x=eval("1+1");' }
        @{ Rule = 'new Function()';                    Code = 'const f=new Function("a","return a");' }
        @{ Rule = 'Function() con cadena';             Code = 'var g=Function("return this")();' }
        @{ Rule = 'setTimeout/setInterval con cadena'; Code = 'setTimeout("alert(1)",10);' }
        @{ Rule = 'import() remoto';                   Code = 'import("https://cdn.example.com/x.js");' }
        @{ Rule = 'cliente de recarga de desarrollo';  Code = 'var d="[ExtensionForge][dev-reload]";' }
    ) {
        $f = @(Find-In (New-Runtime @{ 'content.js' = "console.log(1);`n$Code" }))
        $f.Count      | Should -Be 1
        $f[0].Rule    | Should -Be $Rule
        $f[0].File    | Should -Be 'content.js'
        $f[0].Line    | Should -Be 2
    }

    It 'detecta un script remoto en HTML' {
        $f = @(Find-In (New-Runtime @{ 'index.html' = '<html><script src="https://cdn.example.com/lib.js"></script></html>' }))
        $f.Count   | Should -Be 1
        $f[0].Rule | Should -Be 'script remoto'
    }

    It 'no marca usos legítimos (<Name>)' -ForEach @(
        @{ Name = 'método .eval()';            Code = 'engine.eval(x); obj.$eval(y);' }
        @{ Name = 'identificador evaluate()';   Code = 'evaluate(x); myeval(y);' }
        @{ Name = 'setTimeout con función';     Code = 'setTimeout(() => run(), 10);' }
        @{ Name = 'import() local';             Code = 'import("./chunk.js");' }
        @{ Name = 'typeof Function';            Code = 'if (typeof x === "function") Function.prototype.call.call(x);' }
    ) {
        @(Find-In (New-Runtime @{ 'content.js' = $Code })).Count | Should -Be 0
    }

    It 'ignora los .map' {
        @(Find-In (New-Runtime @{ 'content.js.map' = '{"sourcesContent":["eval(1)"]}' })).Count | Should -Be 0
    }
}

Describe 'Validate Production revisa los bundles (P-04)' -Tag 'Public', 'CSP' {

    It 'Production falla si un bundle usa eval' {
        $ws = New-Runtime @{ 'background.js' = 'eval("x")' }
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Production 6>$null 2>$null 3>$null | Should -BeFalse
    }

    It 'Development no revisa los bundles' {
        $ws = New-Runtime @{ 'background.js' = 'eval("x")' }
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Development 6>$null 3>$null | Should -BeTrue
    }

    It 'Production aprueba bundles limpios' {
        $ws = New-Runtime @{ 'background.js' = 'chrome.runtime.onInstalled.addListener(() => {});' }
        Test-ExtensionForgePackage -WorkspacePath $ws -Environment Production 6>$null | Should -BeTrue
    }
}
