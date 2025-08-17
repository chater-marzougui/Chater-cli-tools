param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [switch]$Help,
    
    [Alias("d")]
    [string]$Directory
)

function Show-Help {
    Write-Host ""
    Write-Host "PowerShell Script Adapter" -ForegroundColor DarkMagenta
    Write-Host "=========================" -ForegroundColor DarkMagenta
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Automatically creates .cmd wrapper files for PowerShell scripts (.ps1) in main directory."
    Write-Host "  This allows PowerShell scripts to be executed directly from Command Prompt or batch files"
    Write-Host "  without needing to specify the full PowerShell execution syntax."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\chater-adapt                 # Run the adapter"
    Write-Host "  .\chater-adapt -d <directory>  # Specify a directory"
    Write-Host "  .\chater-adapt h               # Show this help message"
}

if ($Help -or $Command -eq "h" -or $Command -eq "-h") {
    Show-Help
    return
}

$scriptDir = "C:\custom-scripts"
$wrapperDir = "C:\custom-scripts\cmd-wrappers"
$targetDir = if ($Directory) { $Directory } else { $scriptDir }

function Adapt {
    
    # Ensure the directory exists
    if (-Not (Test-Path $targetDir)) {
        Write-Error "Directory '$targetDir' does not exist."
        exit 1
    }

    # Get all .ps1 files in the directory
    $ps1Files = Get-ChildItem -Path $targetDir -Filter "*.ps1"

    if ($ps1Files.Count -eq 0) {
        Write-Host "No .ps1 files found in directory: $targetDir" -ForegroundColor Yellow
        return
    }

    $wrappedFiles = @()

    foreach ($ps1File in $ps1Files) {
        $ps1Path = $ps1File.FullName
        $baseName = $ps1File.BaseName
        $cmdPath = Join-Path $wrapperDir "$baseName.cmd"

        if (-Not (Test-Path $cmdPath)) {
            # Create the .cmd wrapper
            $wrapper = "@echo off`npowershell -ExecutionPolicy Bypass -File `"$ps1Path`" %*"
            Set-Content -Path $cmdPath -Value $wrapper -Encoding ASCII

            $wrappedFiles += $cmdPath
        }
    }
    if ($wrappedFiles.Count -eq 0) {
        Write-Host "All wrapper files already exist." -ForegroundColor Yellow
    } else {
        foreach ($cmdPath in $wrappedFiles) {
            Write-Host "✅ Created wrapper: $cmdPath"
        }
    }
}

Adapt