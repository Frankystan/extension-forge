#requires -Version 7.6.6
<#
.SYNOPSIS
    Valida (y opcionalmente normaliza) que todos los scripts PowerShell del repositorio
    ExtensionForge sean compatibles con la versión mínima de PowerShell establecida para
    el proyecto: 7.6.6.

.DESCRIPTION
    Escanea recursivamente todos los archivos *.ps1, *.psm1 y *.psd1 del repositorio y
    comprueba, para cada uno:

      1. Sintaxis  — parseo con el parser real de PowerShell (errores de sintaxis = ERROR).
      2. #requires -Version X  — si X > 7.6.6, el script no arrancaría en el piso mínimo (ERROR).
         Si X < 7.6.6, el script declara un piso inferior al del proyecto (WARNING, normalizable).
      3. Manifiestos de módulo (*.psd1) — la clave PowerShellVersion no puede superar 7.6.6 (ERROR);
         si es inferior, se normaliza a 7.6.6.
      4. Reglas de características versionadas — detecta sintaxis/cmdlets introducidos después
         del piso (p. ej. PSWhere(), Get-Command -ExcludeModule, ConvertFrom-Json -DateKind,
         Join-Path con -ChildPath múltiple…) y construcciones eliminadas o renombradas en el piso
         (p. ej. ThreadJob\Start-ThreadJob, renombrado a Microsoft.PowerShell.ThreadJob en 7.6).
         Las cadenas y comentarios se enmascaran para evitar falsos positivos.

    Con -Normalize corrige automáticamente lo corregible (sin tocar código de lógica):
      * Sube PowerShellVersion / #requires -Version inferiores al piso hasta 7.6.6.
      * Con -AddRequires, inserta '#requires -Version 7.6.6' al inicio de los scripts que no lo declaran.
      * Reescribe 'ThreadJob\Start-ThreadJob' -> 'Microsoft.PowerShell.ThreadJob\Start-ThreadJob'.
    Lo que requiera una versión SUPERIOR a 7.6.6 nunca se baja automáticamente: se reporta
    como ERROR para revisión manual (bajar el piso enmascararía una dependencia real).

.PARAMETER Path
    Raíz a escanear. Por defecto, la raíz del repositorio (un nivel por encima de scripts/).

.PARAMETER MinimumVersion
    Versión mínima de PowerShell establecida para el proyecto. Por defecto '7.6.6'.

.PARAMETER Normalize
    Aplica las correcciones automáticas descritas arriba. Sin este switch el script solo informa.

.PARAMETER AddRequires
    Con -Normalize: añade '#requires -Version <piso>' a los .ps1/.psm1 que no declaren ninguno.

.PARAMETER Strict
    Trata como WARNING la ausencia de '#requires -Version' en .ps1/.psm1.

.PARAMETER Exclude
    Nombres de carpeta a excluir del escaneo (comparación por segmento de ruta).

.PARAMETER ReturnOnly
    No usa 'exit': devuelve $true/$false y deja el código de salida intacto.
    Útil cuando otro script o un test invocan este archivo con el operador '&'.

.PARAMETER PassThru
    Emite los objetos de problema (File, Kind, Severity, Line, Message) además del booleano.

.EXAMPLE
    ./scripts/Test-ExtensionForgePowerShellCompatibility.ps1
    Valida todo el repositorio contra PowerShell 7.6.6.

.EXAMPLE
    ./scripts/Test-ExtensionForgePowerShellCompatibility.ps1 -Normalize -AddRequires
    Normaliza los scripts del repositorio al piso 7.6.6.

.NOTES
    Regla de oro del proyecto: no sobrescribir lógica del desarrollador. La normalización solo
    toca declaraciones de versión y el nombre cualificado del módulo ThreadJob renombrado.
#>
[CmdletBinding()]
param(
    [string]$Path = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$MinimumVersion = '7.6.6',
    [switch]$Normalize,
    [switch]$AddRequires,
    [switch]$Strict,
    [string[]]$Exclude = @('.git', '.backups', 'logs', 'node_modules', 'dist', 'coverage', 'release'),
    [switch]$ReturnOnly,
    [switch]$PassThru
)

Set-StrictMode -Version Latest

# =====================================================================
# Reglas de características versionadas.
#   IntroducedIn : la característica NO existe antes de esta versión -> ERROR si > piso.
#   RemovedIn    : la característica dejó de funcionar en esta versión -> ERROR si <= piso.
#   Fix          : reemplazo aplicado por -Normalize cuando la regla dispara (opcional).
# Los patrones se evalúan sobre el texto con cadenas y comentarios enmascarados.
# =====================================================================
$script:ExtensionForgeCompatibilityRules = @(
    @{
        Name         = 'PSWhere()/PSForEach() (alias intrínsecos)'
        Pattern      = '\.\s*PS(Where|ForEach)\s*\('
        IntroducedIn = '7.6.0'
    },
    @{
        Name         = 'Get-Command -ExcludeModule'
        Pattern      = 'Get-Command\b[^\r\n]*?-ExcludeModule\b'
        IntroducedIn = '7.6.0'
    },
    @{
        Name         = 'Join-Path con -ChildPath múltiple (string[])'
        Pattern      = 'Join-Path\b[^\r\n]*?-ChildPath\s+\S+\s*,'
        IntroducedIn = '7.6.0'
    },
    @{
        Name         = 'ConvertFrom-Json -DateKind'
        Pattern      = 'ConvertFrom-Json\b[^\r\n]*?-DateKind\b'
        IntroducedIn = '7.5.0'
    },
    @{
        Name         = 'Bloque clean {}'
        Pattern      = '\bclean\s*\{'
        IntroducedIn = '7.3.0'
    },
    @{
        Name         = '$PSStyle (salida ANSI)'
        Pattern      = '\$PSStyle\b'
        IntroducedIn = '7.2.0'
    },
    @{
        Name         = 'ForEach-Object -Parallel'
        Pattern      = 'ForEach-Object\b[^\r\n]*?-Parallel\b'
        IntroducedIn = '7.0.0'
    },
    @{
        Name         = 'Operador ternario (? :), null-coalescing (??) y encadenado (&& / ||)'
        Pattern      = '\?\?|&&|\|\||\?\s+[^:=\r\n]+:'
        IntroducedIn = '7.0.0'
    },
    @{
        Name         = 'Módulo ThreadJob con nombre antiguo (renombrado en 7.6)'
        Pattern      = 'ThreadJob\\(Start|Stop)-ThreadJob'
        RemovedIn    = '7.6.0'
        Fix          = 'Microsoft.PowerShell.ThreadJob\${1}-ThreadJob'
    }
)

# =====================================================================
# Helpers
# =====================================================================

function Get-ExtensionForgeMaskedCode {
    <# Enmascara (con espacios) las cadenas y comentarios para que las reglas regex
       no produzcan falsos positivos por texto incrustado en literales. #>
    [CmdletBinding()]
    param(
        [string]$Content,
        [System.Management.Automation.Language.Token[]]$Tokens
    )

    $chars = $Content.ToCharArray()
    foreach ($token in $Tokens) {
        if ($token.Kind -in @(
                [System.Management.Automation.Language.TokenKind]::Comment,
                [System.Management.Automation.Language.TokenKind]::StringLiteral,
                [System.Management.Automation.Language.TokenKind]::StringExpandable)) {
            for ($i = $token.Extent.StartOffset; $i -lt $token.Extent.EndOffset -and $i -lt $chars.Length; $i++) {
                if ($chars[$i] -ne "`n" -and $chars[$i] -ne "`r") { $chars[$i] = ' ' }
            }
        }
    }
    return (-join $chars)
}

function Get-ExtensionForgeLineNumber {
    param([string]$Text, [int]$Offset)
    return (1 + ([regex]::Matches($Text.Substring(0, [Math]::Min($Offset, $Text.Length)), "`n")).Count)
}

function Write-ExtensionForgeFilePreservingEncoding {
    <# Escribe texto conservando BOM y saltos de línea originales del archivo. #>
    [CmdletBinding()]
    param([string]$FileFullName, [string]$Content)

    $bytes = [System.IO.File]::ReadAllBytes($FileFullName)
    $hasUtf8Bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $isUtf16Le  = ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)
    $isUtf16Be  = ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF)

    if ($isUtf16Le)  { $encoding = [System.Text.Encoding]::Unicode }
    elseif ($isUtf16Be) { $encoding = [System.Text.Encoding]::BigEndianUnicode }
    else              { $encoding = [System.Text.UTF8Encoding]::new($hasUtf8Bom) }

    [System.IO.File]::WriteAllText($FileFullName, $Content, $encoding)
}

# =====================================================================
# Función principal de análisis (reutilizable por tests vía dot-sourcing)
# =====================================================================

function Test-ExtensionForgePowerShellCompatibility {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Path = (Get-Location).Path,
        [string]$MinimumVersion = '7.6.6',
        [switch]$Normalize,
        [switch]$AddRequires,
        [switch]$Strict,
        [string[]]$Exclude = @('.git', '.backups', 'logs', 'node_modules', 'dist', 'coverage', 'release'),
        [switch]$PassThru
    )

    $Min      = [System.Management.Automation.SemanticVersion]$MinimumVersion
    $Issues   = [System.Collections.Generic.List[object]]::new()
    $RootFull = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')
    $Runtime  = $PSVersionTable.PSVersion

    if ($Runtime -lt $Min) {
        throw "Este validador requiere ejecutarse en PowerShell $MinimumVersion o superior (actual: $Runtime)."
    }

    # --- Aviso de runtime más nuevo que el piso: la validación estática no es infalible ahí ---
    if ($Runtime -gt $Min) {
        $Issues.Add([pscustomobject]@{
                File = '<entorno>'; Kind = 'RuntimeNotice'; Severity = 'Warning'; Line = $null
                Message = "El runtime actual ($Runtime) es más reciente que el piso ($MinimumVersion). " +
                    "El parseo acepta sintaxis de $Runtime; ejecuta este validador con PowerShell $MinimumVersion para una garantía total."
            })
    }

    $Files = Get-ChildItem -LiteralPath $RootFull -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
        Where-Object {
            $RelPath  = $_.FullName.Substring($RootFull.Length).TrimStart('\', '/')
            $Segments = $RelPath -split '[\\/]'
            -not ($Exclude | Where-Object { $_ -and $Segments -contains $_ })
        } |
        Sort-Object FullName

    foreach ($File in $Files) {
        $Rel     = $File.FullName.Substring($RootFull.Length).TrimStart('\', '/')
        $Content = Get-Content -LiteralPath $File.FullName -Raw
        $Eol     = if ($Content -match "`r`n") { "`r`n" } else { "`n" }

        # 1) Sintaxis -------------------------------------------------
        $Tokens = $null; $ParseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$Tokens, [ref]$ParseErrors)
        foreach ($Err in $ParseErrors) {
            $Issues.Add([pscustomobject]@{
                    File = $Rel; Kind = 'SyntaxError'; Severity = 'Error'
                    Line = $Err.Extent.StartLineNumber; Message = $Err.Message
                })
        }

        # 2) #requires -Version ----------------------------------------
        $RequiresMatches = [regex]::Matches($Content, '(?m)^\s*#requires\s+-Version\s+([\d.]+)')
        foreach ($M in $RequiresMatches) {
            $Declared = [System.Management.Automation.SemanticVersion]$M.Groups[1].Value
            $Line     = Get-ExtensionForgeLineNumber -Text $Content -Offset $M.Index
            if ($Declared -gt $Min) {
                $Issues.Add([pscustomobject]@{
                        File = $Rel; Kind = 'RequiresVersion'; Severity = 'Error'; Line = $Line
                        Message = "#requires -Version $Declared exige una versión superior al piso del proyecto ($MinimumVersion)."
                    })
            }
            elseif ($Declared -lt $Min) {
                $Issues.Add([pscustomobject]@{
                        File = $Rel; Kind = 'RequiresVersion'; Severity = 'Warning'; Line = $Line
                        Message = "#requires -Version $Declared declara un piso inferior al del proyecto ($MinimumVersion)."
                    })
            }
        }

        # 3) Manifiestos de módulo ------------------------------------
        if ($File.Extension -eq '.psd1' -and $ParseErrors.Count -eq 0) {
            try {
                $Data = Import-PowerShellDataFile -LiteralPath $File.FullName -ErrorAction Stop
                if ($Data -is [hashtable] -and ($Data.ContainsKey('RootModule') -or $Data.ContainsKey('ModuleVersion'))) {
                    if ($Data.ContainsKey('PowerShellVersion')) {
                        $Declared = [System.Management.Automation.SemanticVersion]($Data['PowerShellVersion'] -as [string])
                        if ($Declared -gt $Min) {
                            $Issues.Add([pscustomobject]@{
                                    File = $Rel; Kind = 'ManifestVersion'; Severity = 'Error'; Line = $null
                                    Message = "PowerShellVersion = '$($Data['PowerShellVersion'])' exige una versión superior al piso del proyecto ($MinimumVersion)."
                                })
                        }
                        elseif ($Declared -lt $Min) {
                            $Issues.Add([pscustomobject]@{
                                    File = $Rel; Kind = 'ManifestVersion'; Severity = 'Warning'; Line = $null
                                    Message = "PowerShellVersion = '$($Data['PowerShellVersion'])' es inferior al piso del proyecto ($MinimumVersion)."
                                })
                        }
                    }
                }
            }
            catch {
                $Issues.Add([pscustomobject]@{
                        File = $Rel; Kind = 'DataFile'; Severity = 'Error'; Line = $null
                        Message = "No se pudo leer el archivo de datos/manifiesto: $($_.Exception.Message)"
                    })
            }
        }

        # 4) Reglas de características versionadas ----------------------
        if ($ParseErrors.Count -eq 0) {
            $Masked = Get-ExtensionForgeMaskedCode -Content $Content -Tokens $Tokens
            foreach ($Rule in $script:ExtensionForgeCompatibilityRules) {
                foreach ($M in [regex]::Matches($Masked, $Rule.Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                    $Line = Get-ExtensionForgeLineNumber -Text $Masked -Offset $M.Index
                    if ($Rule.ContainsKey('IntroducedIn') -and
                        ([System.Management.Automation.SemanticVersion]$Rule.IntroducedIn) -gt $Min) {
                        $Issues.Add([pscustomobject]@{
                                File = $Rel; Kind = 'FeatureRule'; Severity = 'Error'; Line = $Line
                                Message = "'$($Rule.Name)' se introdujo en PowerShell $($Rule.IntroducedIn), posterior al piso ($MinimumVersion)."
                            })
                    }
                    if ($Rule.ContainsKey('RemovedIn') -and
                        ([System.Management.Automation.SemanticVersion]$Rule.RemovedIn) -le $Min) {
                        $Issues.Add([pscustomobject]@{
                                File = $Rel; Kind = 'FeatureRule'; Severity = 'Error'; Line = $Line
                                Message = "'$($Rule.Name)' dejó de estar disponible en PowerShell $($Rule.RemovedIn); no funciona en el piso ($MinimumVersion)."
                            })
                    }
                }
            }
        }

        # 5) Ausencia de #requires (modo estricto) ----------------------
        if ($Strict -and $File.Extension -in @('.ps1', '.psm1') -and $RequiresMatches.Count -eq 0) {
            $Issues.Add([pscustomobject]@{
                    File = $Rel; Kind = 'MissingRequires'; Severity = 'Warning'; Line = $null
                    Message = "No declara '#requires -Version'; considera añadirlo (usa -Normalize -AddRequires)."
                })
        }

        # 6) Normalización ----------------------------------------------
        if ($Normalize) {
            $NewContent = $Content
            $Changed    = @()

            # 6a) Sube #requires inferiores al piso (nunca los superiores al piso)
            if ($RequiresMatches.Count -gt 0) {
                $Candidate = $NewContent
                for ($i = $RequiresMatches.Count - 1; $i -ge 0; $i--) {
                    $M = $RequiresMatches[$i]
                    if ([System.Management.Automation.SemanticVersion]$M.Groups[1].Value -lt $Min) {
                        $Candidate = $Candidate.Substring(0, $M.Groups[1].Index) +
                            $Min.ToString() +
                            $Candidate.Substring($M.Groups[1].Index + $M.Groups[1].Length)
                    }
                }
                if ($Candidate -ne $NewContent) { $NewContent = $Candidate; $Changed += "subir #requires a $MinimumVersion" }
            }
            # 6b) Añade #requires si se pide y no existe
            elseif ($AddRequires -and $File.Extension -in @('.ps1', '.psm1')) {
                $NewContent = "#requires -Version $($Min.ToString())$Eol$NewContent"
                $Changed += "añadir #requires -Version $MinimumVersion"
            }

            # 6c) Sube PowerShellVersion en manifiestos de módulo (solo si es inferior al piso)
            if ($File.Extension -eq '.psd1') {
                $Candidate = $NewContent
                $PsVersionMatches = @([regex]::Matches($Candidate, "(?m)^(\s*PowerShellVersion\s*=\s*['`"])([^'`"]+)(['`"])"))
                for ($i = $PsVersionMatches.Count - 1; $i -ge 0; $i--) {
                    $M = $PsVersionMatches[$i]
                    $Declared = [System.Management.Automation.SemanticVersion]$M.Groups[2].Value
                    if ($Declared -lt $Min) {
                        $Candidate = $Candidate.Substring(0, $M.Groups[2].Index) +
                            $Min.ToString() +
                            $Candidate.Substring($M.Groups[2].Index + $M.Groups[2].Length)
                    }
                }
                if ($Candidate -ne $NewContent) { $NewContent = $Candidate; $Changed += "subir PowerShellVersion a $MinimumVersion" }
            }

            # 6d) Reescribe nombres cualificados de módulos renombrados
            foreach ($Rule in $script:ExtensionForgeCompatibilityRules) {
                if ($Rule.ContainsKey('Fix') -and $Rule.ContainsKey('RemovedIn') -and
                    ([System.Management.Automation.SemanticVersion]$Rule.RemovedIn) -le $Min) {
                    $Candidate = [regex]::Replace($NewContent, $Rule.Pattern, $Rule.Fix, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    if ($Candidate -ne $NewContent) { $NewContent = $Candidate; $Changed += "reescribir $($Rule.Name)" }
                }
            }

            if ($Changed.Count -gt 0) {
                Write-ExtensionForgeFilePreservingEncoding -FileFullName $File.FullName -Content $NewContent
                $Issues.Add([pscustomobject]@{
                        File = $Rel; Kind = 'Normalized'; Severity = 'Info'; Line = $null
                        Message = "Normalizado: $($Changed -join '; ')."
                    })
            }
        }
    }

    $Issues = @($Issues)
    if ($PassThru) {
        $Issues | ForEach-Object { $_ }
        return
    }

    $HasErrors = @($Issues | Where-Object { $_.Severity -eq 'Error' }).Count -gt 0
    return -not $HasErrors
}

# =====================================================================
# Ejecución como script (no se ejecuta si se hace dot-source para tests)
# =====================================================================
if ($MyInvocation.InvocationName -ne '.') {
    $PassThruResults = @(Test-ExtensionForgePowerShellCompatibility -Path $Path -MinimumVersion $MinimumVersion `
            -Normalize:$Normalize -AddRequires:$AddRequires -Strict:$Strict -Exclude $Exclude -PassThru)

    $Errors   = @($PassThruResults | Where-Object { $_.Severity -eq 'Error' })
    $Warnings = @($PassThruResults | Where-Object { $_.Severity -eq 'Warning' })
    $Infos    = @($PassThruResults | Where-Object { $_.Severity -eq 'Info' })

    Write-Host ''
    Write-Host "  🔎 Compatibilidad PowerShell — piso mínimo: $MinimumVersion (runtime: $($PSVersionTable.PSVersion))" -ForegroundColor Cyan
    Write-Host "     Escaneados: $((Get-ChildItem -LiteralPath $Path -Recurse -File -Include '*.ps1','*.psm1','*.psd1' | Measure-Object).Count) archivos PowerShell en '$Path'" -ForegroundColor DarkGray

    foreach ($Issue in $Errors) {
        $Where = if ($Issue.Line) { " (línea $($Issue.Line))" } else { '' }
        Write-Host "  ❌ $($Issue.File): $($Issue.Message)$Where" -ForegroundColor Red
    }
    foreach ($Issue in $Warnings) {
        $Where = if ($Issue.Line) { " (línea $($Issue.Line))" } else { '' }
        Write-Host "  ⚠️  $($Issue.File): $($Issue.Message)$Where" -ForegroundColor Yellow
    }
    foreach ($Issue in $Infos) {
        Write-Host "  🔧 $($Issue.File): $($Issue.Message)" -ForegroundColor DarkCyan
    }

    Write-Host ''
    if ($Errors.Count -eq 0) {
        Write-Host "  ✅ Todos los scripts son compatibles con PowerShell $MinimumVersion." -ForegroundColor Green
        if ($Warnings.Count -gt 0) {
            Write-Host "     ($($Warnings.Count) aviso(s) no bloqueante(s); usa -Normalize para corregirlos.)" -ForegroundColor DarkYellow
        }
        $Ok = $true
    }
    else {
        Write-Host "  ❌ $($Errors.Count) error(es) de compatibilidad encontrados." -ForegroundColor Red
        $Ok = $false
    }

    if (-not $ReturnOnly) {
        if ($Ok) { exit 0 } else { exit 1 }
    }
    $Ok
}
