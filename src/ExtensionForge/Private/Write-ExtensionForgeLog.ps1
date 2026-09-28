<#
.SYNOPSIS
    Escribe una entrada de registro JSONL y estandariza la salida por consola.
.DESCRIPTION
    Registra en logs/dev.log (o logs/production.log) una línea JSON por evento.
    Usa UTF-8 sin BOM para no corromper el JSONL al hacer append.
#>
function Write-ExtensionForgeLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$Action = 'Global',
        [string]$Environment = 'Development',
        [string]$Browser = 'All',
        [string]$WorkspacePath = "$PWD"
    )

    $LogsDir = Join-Path $WorkspacePath 'logs'
    $LogFile = if ($Environment -eq 'Production') { 'production.log' } else { 'dev.log' }
    $LogPath = Join-Path $LogsDir $LogFile

    if (-not (Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }

    $entry = [ordered]@{
        Timestamp   = (Get-Date).ToString('o')
        Level       = $Level
        Action      = $Action
        Environment = $Environment
        Browser     = $Browser
        Message     = $Message
    }
    $json = $entry | ConvertTo-Json -Compress -Depth 5

    # Append en UTF-8 sin BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($LogPath, $json + [Environment]::NewLine, $utf8NoBom)

    switch ($Level) {
        'INFO'    { Write-Host "[$Action] $Message" -ForegroundColor Cyan }
        'SUCCESS' { Write-Host "[$Action] $Message" -ForegroundColor Green }
        'WARN'    { Write-Warning "[$Action] $Message" }
        'ERROR'   { Write-Error "[$Action] $Message" }
    }
}
