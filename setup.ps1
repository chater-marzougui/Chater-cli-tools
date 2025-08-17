param(
    [Parameter(Position = 0)]
    [string]$UserName,

    [switch]$Help
)

$GITHUB_LINK = "https://github.com/your-username/your-repo-name"
$AUTHOR_CREDIT = "Made by Chater Marzougui"
$STAR_MESSAGE = "please give a star at : $GITHUB_LINK"

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
    Write-Host "  .\setup.ps1 <YourName>         # Setup with your name"
    Write-Host "  .\setup.ps1 -Help              # Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 john               # Setup scripts with 'john' prefix"
    Write-Host "  .\setup.ps1 sarah              # Setup scripts with 'sarah' prefix"
    Write-Host ""
    Write-Host "WHAT THIS SCRIPT DOES:" -ForegroundColor Green
    Write-Host "  1. Renames all 'chater-*.ps1' files to '<yourname>-*.ps1'"
    Write-Host "  2. Updates all file content to replace 'chater' with your name"
    Write-Host "  3. Adds attribution comments to all files"
    Write-Host "  4. Creates necessary directories"
    Write-Host "  5. Adds script directories to your system PATH"
    Write-Host "  6. Runs the adapter to create .cmd wrappers"
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

function Create-Directories {
    $directories = @(
        "C:\custom-scripts",
        "C:\custom-scripts\cmd-wrappers", 
        "C:\custom-scripts\common-commands"
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
    Write-Host "✅ Added attribution to: $(Split-Path $FilePath -Leaf)" -ForegroundColor Green
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
        return $true
    }
    
    return $false
}

function Rename-ScriptFiles {
    param([string]$NewUserName)
    
    $scriptFiles = Get-ChildItem -Path "." -Filter "chater-*.ps1"
    $renamedFiles = @()
    
    foreach ($file in $scriptFiles) {
        $newName = $file.Name -replace "^chater-", "$NewUserName-"
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
    $allScriptFiles = Get-ChildItem -Path "." -Filter "*.ps1" | Where-Object { $_.Name -ne "setup.ps1" }
    
    foreach ($file in $allScriptFiles) {
        # Update content (replace chater with new name)
        $contentUpdated = Update-FileContent -FilePath $file.FullName -OldName "chater" -NewName $NewUserName
        
        # Add attribution
        Add-Attribution -FilePath $file.FullName -NewUserName $NewUserName
    }
}

function Run-Adapter {
    param([string]$NewUserName)
    
    $adapterScript = Get-ChildItem -Path "." -Filter "$NewUserName-adapt.ps1" -ErrorAction SilentlyContinue
    
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
    
    # Step 1: Create directories
    Write-Host "📁 Step 1: Creating directories..." -ForegroundColor Blue
    Create-Directories
    Write-Host ""
    
    # Step 2: Rename script files
    Write-Host "📝 Step 2: Renaming script files..." -ForegroundColor Blue
    $renamedFiles = Rename-ScriptFiles -NewUserName $UserName
    Write-Host ""
    
    # Step 3: Update all script content
    Write-Host "🔄 Step 3: Updating script content..." -ForegroundColor Blue
    Update-AllScriptContent -NewUserName $UserName
    Write-Host ""
    
    # Step 4: Add to PATH
    Write-Host "🛣️  Step 4: Adding directories to PATH..." -ForegroundColor Blue
    $pathsAdded = 0
    $pathsToAdd = @(
        "C:\custom-scripts",
        "C:\custom-scripts\cmd-wrappers",
        "C:\custom-scripts\common-commands"
    )
    
    foreach ($path in $pathsToAdd) {
        if (Add-ToPath -PathToAdd $path) {
            $pathsAdded++
        }
    }
    Write-Host ""
    
    # Step 5: Run adapter
    Write-Host "⚙️  Step 5: Creating .cmd wrappers..." -ForegroundColor Blue
    Run-Adapter -NewUserName $UserName
    Write-Host ""
    
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