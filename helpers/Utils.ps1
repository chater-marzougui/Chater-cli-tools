# Common Utilities for Chater-CLI Tools

# Colors Configuration
$Global:Theme = @{
    Title     = "Cyan"
    Success   = "Green"
    Error     = "Red"
    Warning   = "Yellow"
    Info      = "Gray"
    Highlight = "Magenta"
}

# --- Logging Functions ---

function Show-Header {
    param([string]$Title, [string]$Icon = "🚀")
    Write-Host ""
    Write-Host "$Icon $Title" -ForegroundColor $Global:Theme.Title
    Write-Host ("=" * ($Title.Length + 3)) -ForegroundColor $Global:Theme.Title
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $Global:Theme.Success
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Global:Theme.Error
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Global:Theme.Warning
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $Global:Theme.Info
}

# --- Environment Functions ---

function Get-ProjectRoot {
    # Assuming this script is in helpers/, root is one level up
    $scriptPath = $PSScriptRoot
    if ($scriptPath -match "helpers$") {
        return (Split-Path $scriptPath -Parent)
    }
    return $scriptPath
}

function Init-Environment {
    param([string]$RootPath = (Get-ProjectRoot))
    $envPath = Join-Path $RootPath ".env"
    
    if (Test-Path $envPath) {
        return $envPath
    }
    return $null
}

function Get-EnvVariable {
    param([string]$Name, [string]$DefaultValue = $null)
    
    $envPath = Init-Environment
    if ($envPath) {
        $content = Get-Content $envPath | Where-Object { $_ -match "^$Name=" }
        if ($content) {
            $val = $content -replace "^$Name=", ""
            return $val.Trim().Trim('"').Trim("'")
        }
    }
    return $DefaultValue
}

# --- System Functions ---

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# --- Formatting Functions ---

function Format-FileSize {
    param([long]$Size)
    
    if ($Size -lt 1KB) { return "$Size B" }
    elseif ($Size -lt 1MB) { return "{0:F1} KB" -f ($Size / 1KB) }
    elseif ($Size -lt 1GB) { return "{0:F1} MB" -f ($Size / 1MB) }
    else { return "{0:F2} GB" -f ($Size / 1GB) }
}
