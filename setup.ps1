param(
    [Parameter(Position = 0)]
    [string]$UserName,

    [Parameter(Position = 1)]
    [string]$CustomPath,

    [switch]$Help
)

$GITHUB_LINK = "https://github.com/chater-marzougui/Chater-cli-tools"
$AUTHOR_CREDIT = "Made by Chater Marzougui"
$STAR_MESSAGE = "please give a star at : $GITHUB_LINK"

$envFilePath = Join-Path $PSScriptRoot ".env"
$scriptDir = (Get-Content $envFilePath | Where-Object { $_ -match "^MAIN_SCRIPTS_PATH=" }) -replace "MAIN_SCRIPTS_PATH=", ""
if (-Not $scriptDir) { $scriptDir = "C:\custom-scripts" } else { $scriptDir = $scriptDir.Trim().Trim('"').Trim("'") }

function Show-Help {
    Write-Host ""
    Write-Host "PowerShell Scripts Setup - Bootstrap Installer" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Sets up the PowerShell scripts collection for your system."
    Write-Host "  Renames all scripts to use your name, adds proper attribution,"
    Write-Host "  and configures the environment paths."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 <YourName>                    # Setup with your name (interactive folder selection)"
    Write-Host "  .\setup.ps1 <YourName> <CustomPath>       # Setup with your name and custom folder"
    Write-Host "  .\setup.ps1 -Help                         # Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 john                          # Setup with interactive folder selection"
    Write-Host "  .\setup.ps1 sarah D:\my-scripts           # Setup with custom folder"
    Write-Host "  .\setup.ps1 alex 'C:\Program Files\Scripts'  # Setup with folder containing spaces"
    Write-Host ""
    Write-Host "WHAT THIS SCRIPT DOES:" -ForegroundColor Green
    Write-Host "  0. Creates .env from example.env and configures paths"
    Write-Host "  1. Renames all 'chater-*.ps1' files to '<yourname>-*.ps1'"
    Write-Host "  2. Updates all file content to replace 'chater' with your name"
    Write-Host "  3. Creates necessary directories"
    Write-Host "  4. Adds script directories to your system PATH"
    Write-Host "  5. Runs the adapter to create .cmd wrappers"
    Write-Host ""
    Write-Host "REQUIREMENTS:" -ForegroundColor Red
    Write-Host "  • Run as Administrator (required for PATH modification)"
    Write-Host "  • PowerShell Execution Policy set to allow scripts"
    Write-Host ""
}

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-ToPath {
    param([string]$PathToAdd)
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($currentPath -notlike "*$PathToAdd*") {
        $newPath = $currentPath + ";" + $PathToAdd
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "✅ Added to PATH: $PathToAdd" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠️  Already in PATH: $PathToAdd" -ForegroundColor Yellow
        return $false
    }
}

function Create_Directories {
    $directories = @(
        $scriptDir,
        "$scriptDir\cmd-wrappers",
        "$scriptDir\common-commands",
        "$scriptDir\helpers"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "✅ Created directory: $dir" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Directory already exists: $dir" -ForegroundColor Yellow
        }
    }
}

function Add-Attribution {
    param(
        [string]$FilePath,
        [string]$NewUserName
    )
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    
    # Check if attribution already exists
    if ($content -match "#\s*$([regex]::Escape($AUTHOR_CREDIT))") {
        Write-Host "⚠️  Attribution already exists in: $(Split-Path $FilePath -Leaf)" -ForegroundColor Yellow
        return
    }
    
    # Add attribution at the top
    $attribution = @"
# $AUTHOR_CREDIT
# $STAR_MESSAGE

"@
    
    $newContent = $attribution + $content
    Set-Content -Path $FilePath -Value $newContent -Encoding UTF8
}

function Update-FileContent {
    param(
        [string]$FilePath,
        [string]$OldName,
        [string]$NewName
    )
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    
    # Replace all instances of the old name with new name (case-insensitive)
    $pattern = [regex]::Escape($OldName)
    $updatedContent = $content -replace "(?i)\b$pattern\b", $NewName
    
    if ($content -ne $updatedContent) {
        Set-Content -Path $FilePath -Value $updatedContent -Encoding UTF8
        Write-Host "✅ Updated content in: $(Split-Path $FilePath -Leaf)" -ForegroundColor Green
    }
}

function Rename-ScriptFiles {
    param([string]$NewUserName)

    $scriptFiles = Get-ChildItem -Path $scriptDir -Filter "chater*.ps1"
    $renamedFiles = @()
    
    foreach ($file in $scriptFiles) {
        $newName = $file.Name -replace "^chater", "$NewUserName"
        $newPath = Join-Path $file.DirectoryName $newName
        
        if (Test-Path $newPath) {
            Write-Host "⚠️  File already exists: $newName" -ForegroundColor Yellow
            continue
        }
        
        try {
            Rename-Item -Path $file.FullName -NewName $newName
            Write-Host "✅ Renamed: $($file.Name) → $newName" -ForegroundColor Green
            $renamedFiles += $newPath
        }
        catch {
            Write-Host "❌ Failed to rename $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $renamedFiles
}

function Update-AllScriptContent {
    param([string]$NewUserName)
    
    # Get all .ps1 files in current directory
    $allScriptFiles = Get-ChildItem -Path $scriptDir -Filter "*.ps1" | Where-Object { $_.Name -ne "setup.ps1" }

    foreach ($file in $allScriptFiles) {
        # Update content (replace chater with new name)
        Update-FileContent -FilePath $file.FullName -OldName "chater" -NewName $NewUserName
        
        # Add attribution
        Add-Attribution -FilePath $file.FullName -NewUserName $NewUserName
    }
}

function Copy-ScriptsToDestination {
    $sourceDir = $PSScriptRoot
    $destinationDir = $scriptDir
    
    Write-Host "📋 Copying files from $sourceDir to $destinationDir..." -ForegroundColor Blue
    
    # Get all files except setup.ps1
    $filesToCopy = Get-ChildItem -Path $sourceDir -File | Where-Object { $_.Name -ne "setup.ps1" }
    
    foreach ($file in $filesToCopy) {
        $destPath = Join-Path $destinationDir $file.Name
        try {
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            Write-Host "✅ Copied: $($file.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to copy $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Initialize-EnvFile {
    param([string]$PreferredPath)
    
    $exampleEnvPath = Join-Path $PSScriptRoot "example.env"
    $envPath = Join-Path $PSScriptRoot ".env"
    
    # Check if example.env exists
    if (-not (Test-Path $exampleEnvPath)) {
        Write-Host "❌ Error: example.env file not found" -ForegroundColor Red
        return $null
    }
    
    # Create .env from example.env if it doesn't exist
    if (-not (Test-Path $envPath)) {
        Copy-Item -Path $exampleEnvPath -Destination $envPath
        Write-Host "✅ Created .env from example.env" -ForegroundColor Green
    }
    
    # Read current .env content
    $envContent = Get-Content $envPath
    
    # Update MAIN_SCRIPTS_PATH if provided
    if ($PreferredPath) {
        $updatedContent = @()
        $pathUpdated = $false
        
        foreach ($line in $envContent) {
            if ($line -match "^MAIN_SCRIPTS_PATH=") {
                $updatedContent += "MAIN_SCRIPTS_PATH=$PreferredPath"
                $pathUpdated = $true
            } else {
                $updatedContent += $line
            }
        }
        
        # If MAIN_SCRIPTS_PATH line wasn't found, add it
        if (-not $pathUpdated) {
            $updatedContent += "MAIN_SCRIPTS_PATH=$PreferredPath"
        }
        
        # Write updated content back to .env
        $updatedContent | Out-File -FilePath $envPath -Encoding UTF8
        Write-Host "✅ Updated .env with custom path: $PreferredPath" -ForegroundColor Green
        return
    }
    
    # Return current path from .env
    $currentPath = ($envContent | Where-Object { $_ -match "^MAIN_SCRIPTS_PATH=" }) -replace "MAIN_SCRIPTS_PATH=", ""
    if ($currentPath) {
        return $currentPath.Trim().Trim('"').Trim("'")
    }
    
    return "C:\custom-scripts"
}

function Run_Adapter {
    param([string]$NewUserName)

    $adapterScript = Get-ChildItem -Path $scriptDir -Filter "$NewUserName-adapt.ps1" -ErrorAction SilentlyContinue

    if ($adapterScript) {
        Write-Host ""
        Write-Host "🔄 Running adapter to create .cmd wrappers..." -ForegroundColor Cyan
        try {
            & $adapterScript.FullName
            Write-Host "✅ Adapter completed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Adapter failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  Adapter script not found: $NewUserName-adapt.ps1" -ForegroundColor Yellow
    }
}

function Initialize-VersionFile {
    $versionFilePath = Join-Path $scriptDir "helpers\version.json"
    if (-not (Test-Path $versionFilePath)) {
        Write-Host "🆕 Creating version.json file..." -ForegroundColor Blue    
        # Initialize version file
        $versionData = @{
            version = "0.1.0"
            commit = (git rev-parse HEAD 2>$null) -or "unknown"
            date = (Get-Date).ToString("yyyy-MM-dd")
            user_customized = $true
        }
        $versionPath = Join-Path $scriptDir "helpers/version.json"
        $versionData | ConvertTo-Json -Depth 2 | Set-Content -Path $versionPath -Encoding UTF8
        Write-Host ""
    } else {
        Write-Host "⚠️  version.json already exists, skipping creation." -ForegroundColor Yellow
    }
}

function Main {
    Write-Host ""
    Write-Host "🚀 PowerShell Scripts Setup - Bootstrap Installer" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Validate input
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        Write-Host "❌ Error: Username is required" -ForegroundColor Red
        Show-Help
        return
    }
    
    # Validate username format
    if ($UserName -notmatch "^[a-zA-Z][a-zA-Z0-9]*$") {
        Write-Host "❌ Error: Username must start with a letter and contain only letters and numbers" -ForegroundColor Red
        return
    }
    
    # Check if running as admin
    if (-not (Test-IsAdmin)) {
        Write-Host "❌ Error: This script must be run as Administrator" -ForegroundColor Red
        Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        return
    }
    
    Write-Host "👤 Setting up scripts for user: $UserName" -ForegroundColor Green
    Write-Host ""

    #Step 0: Initialize Folders
    $scriptDir = if ($CustomPath) { $CustomPath } else { $scriptDir }

    Write-Host "📁 Step 0: Creating directories and env..." -ForegroundColor Blue
    Create_Directories 
    Initialize-EnvFile -PreferredPath $scriptDir

    # Step 1: Copy scripts to destination
    Write-Host "📁 Step 1: Copying scripts to destination..." -ForegroundColor Blue
    Copy-ScriptsToDestination
    Write-Host ""

    # Step 2: Rename script files
    Write-Host "📝 Step 2: Renaming script files..." -ForegroundColor Blue
    Rename-ScriptFiles -NewUserName $UserName
    Write-Host ""
    
    # Step 3: Update all script content
    Write-Host "🔄 Step 3: Updating script content..." -ForegroundColor Blue
    Update-AllScriptContent -NewUserName $UserName
    Write-Host ""
    
    # Step 4: Add to PATH
    Write-Host "🛣️  Step 4: Adding directories to PATH..." -ForegroundColor Blue
    $pathsAdded = 0
    $pathsToAdd = @(
        "$scriptDir",
        "$scriptDir\cmd-wrappers",
        "$scriptDir\common-commands",
        "$scriptDir\helpers"
    )
    
    foreach ($path in $pathsToAdd) {
        if (Add-ToPath -PathToAdd $path) {
            $pathsAdded++
        }
    }
    Write-Host ""
    
    # Step 5: Run adapter
    Write-Host "⚙️  Step 5: Creating .cmd wrappers..." -ForegroundColor Blue
    Run_Adapter -NewUserName $UserName
    Write-Host ""

    # Step 6: Creating version.json if not exists
    Initialize-VersionFile
    
    # Final summary
    Write-Host "🎉 Setup Complete!" -ForegroundColor Green
    Write-Host "=================" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Directories created and added to PATH" -ForegroundColor Green
    Write-Host "✅ Scripts renamed and updated for user: $UserName" -ForegroundColor Green
    Write-Host "✅ Attribution added to all files" -ForegroundColor Green
    Write-Host "✅ .cmd wrappers created" -ForegroundColor Green
    Write-Host ""
    
    if ($pathsAdded -gt 0) {
        Write-Host "⚠️  IMPORTANT: Restart your terminal/PowerShell to use the new commands" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🌟 If you found this useful, please give it a star at:" -ForegroundColor Cyan
    Write-Host "   $GITHUB_LINK" -ForegroundColor White
    Write-Host ""
    Write-Host "📖 Try running: $UserName-help or $UserName (without parameters) to see available commands" -ForegroundColor Gray
    Write-Host ""
}

# Handle help parameter
if ($Help -or $UserName -eq "h" -or $UserName -eq "-h" -or $UserName -eq "help") {
    Show-Help
    return
}

# Run main function
Main