param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$envFilePath = Join-Path $PSScriptRoot ".env"
$scriptDir = (Get-Content $envFilePath | Where-Object { $_ -match "^MAIN_SCRIPTS_PATH=" }) -replace "MAIN_SCRIPTS_PATH=", ""
if (-Not $scriptDir) { $scriptDir = "C:\custom-scripts" } else { $scriptDir = $scriptDir.Trim().Trim('"').Trim("'") }

# Resolve the current script path
$currentScript = $MyInvocation.MyCommand.Path
$currentScriptName = $MyInvocation.MyCommand.Name
$smallHelp = $Arguments -contains "--small"

# Ensure the directory exists
if (-Not (Test-Path $scriptDir)) {
    Write-Error "Directory '$scriptDir' does not exist."
    exit 1
}

Write-Host "`n" -NoNewline
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  SCANNING POWERSHELL SCRIPTS" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# Get all .ps1 files in the directory
if ($Command.StartsWith("-")) {
    switch ($Command) {
        "--small" {
            $smallHelp = $true
            $Command = $null
            if ($Arguments.Count -ge 1) {
                $Command = $Arguments | Where-Object { -not $_.StartsWith("-") } | Select-Object -First 1
            }
        }
        default {
            Write-Error "Unknown command: $Command"
            return
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Command)) {
    $scripts = Get-ChildItem -Path $scriptDir -Filter "*.ps1" | Where-Object { $_.Name -ne "$currentScriptName" }
} else {
    $scripts = Get-ChildItem -Path $scriptDir -Filter "*.ps1" | Where-Object { $_.Name -like "*$Command*" }
}
$totalScripts = $scripts.Count
$currentIndex = 0
$scripts | ForEach-Object {
    $ps1Path = $_.FullName
    $baseName = $_.BaseName
    $currentIndex++

    # Skip this script itself
    if ($ps1Path -eq $currentScript) {
        return
    }

    Write-Host "┌─────────────────────────────────────────────────────────┐" -ForegroundColor Gray
    Write-Host "│ " -ForegroundColor Gray -NoNewline
    Write-Host "[$currentIndex/$totalScripts] " -ForegroundColor Magenta -NoNewline
    Write-Host "Executing: " -ForegroundColor White -NoNewline
    Write-Host "$baseName" -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor Gray
    Write-Host "└─────────────────────────────────────────────────────────┘" -ForegroundColor Gray
    
    try {
        if ($smallHelp) {
            & "$ps1Path" -h --small
        } else {
            & "$ps1Path" -h
        }
    } catch {
        Write-Host "❌ " -ForegroundColor Red -NoNewline
        Write-Warning "Error executing $baseName with -h: $_"
    }
    
    # Add spacing between scripts (except for the last one)
    if ($currentIndex -lt $totalScripts) {
        Write-Host "`n" -NoNewline
    }
}

Write-Host "`n" -NoNewline
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  SCAN COMPLETE" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Cyan
