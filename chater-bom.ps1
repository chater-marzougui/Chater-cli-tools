# PowerShell script to convert .ps1 files from UTF-8 to UTF-8 with BOM
# Scans current directory for .ps1 files and converts their encoding
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [switch]$Help,
    
    [Alias("d")]
    [string]$Directory
)


$envFilePath = Join-Path $PSScriptRoot ".env"
$scriptDir = (Get-Content $envFilePath | Where-Object { $_ -match "^MAIN_SCRIPTS_PATH=" }) -replace "MAIN_SCRIPTS_PATH=", ""
if (-Not $scriptDir) { $scriptDir = "C:\custom-scripts" } else { $scriptDir = $scriptDir.Trim().Trim('"').Trim("'") }

function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "PowerShell UTF-8 BOM Converter" -ForegroundColor Green
    Write-Host "==============================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Converts PowerShell script files (.ps1) from UTF-8 encoding to UTF-8 with BOM"
    Write-Host "  (Byte Order Mark). This ensures proper character encoding recognition and prevents"
    Write-Host "  encoding-related issues when scripts contain special characters or are executed"
    Write-Host "  across different systems and editors."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-bom                   # Convert all .ps1 files in $scriptDir"
    Write-Host "  chater-bom -d <directory>    # Convert all .ps1 files in target directory"
    Write-Host "  chater-bom h                 # Show this help message"
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "WHAT IS BOM (Byte Order Mark)?" -ForegroundColor Yellow
    Write-Host "  • A special marker at the beginning of text files"
    Write-Host "  • Identifies the encoding format (UTF-8, UTF-16, etc.)"
    Write-Host "  • Helps applications correctly interpret special characters"
    Write-Host "  • Prevents encoding mismatches between different systems"
    Write-Host "  • Essential for PowerShell scripts with non-ASCII characters"
}


$helpArgs = @("-h", "--h", "help", "-Help")
if ($Help -or $helpArgs -contains $Command) {
    $isSmall = ($Arguments -contains "--small") -or $Command -eq "--small"
    Show-Help -isSmall $isSmall
    return
}

# Use provided directory or default to script directory
$targetDir = if ($Directory) { $Directory } else { $scriptDir }

# Validate directory exists
if (-not (Test-Path -Path $targetDir -PathType Container)) {
    Write-Error "Directory not found: $targetDir"
    return
}

# Find all .ps1 files in target directory
$ps1Files = Get-ChildItem -Path $targetDir -Filter "*.ps1" -File

if ($ps1Files.Count -eq 0) {
    Write-Warning "No .ps1 files found in directory: $targetDir"
    return
}

$filesToConvert = @()

foreach ($file in $ps1Files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $alreadyHasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

    if (-not $alreadyHasBom) {
        $filesToConvert += $file
    }
}

if ($filesToConvert.Count -eq 0) {
    Write-Host "All .ps1 files already have BOM." -ForegroundColor Yellow
    return
}

Write-Host "Found $($filesToConvert.Count) .ps1 file(s) to process in '$targetDir':" -ForegroundColor Yellow

# Process each .ps1 file
foreach ($file in $filesToConvert) {
    try {
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Read the file content as UTF-8
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        
        # Write the content back as UTF-8 with BOM
        $utf8WithBom = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8WithBom)
        
        Write-Host " ✅ Successfully converted: $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to convert $($file.Name): $($_.Exception.Message)"
    }
}

Write-Host "All .ps1 files in '$targetDir' have been converted to UTF-8 with BOM." -ForegroundColor Green