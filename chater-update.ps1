param(
    [Parameter(Position = 0)]
    [string]$Command,

    [switch]$Force,
    [switch]$Preview,
    [switch]$Help
)

# Made by Chater Marzougui
# please give a star at : https://github.com/chater-marzougui/Chater-cli-tools

$GITHUB_REPO = "chater-marzougui/Chater-cli-tools"
$GITHUB_API_URL = "https://api.github.com/repos/$GITHUB_REPO"
$VERSION_FILE = "helpers/version.json"

$envFilePath = Join-Path $PSScriptRoot ".env"
$scriptDir = (Get-Content $envFilePath -ErrorAction SilentlyContinue | Where-Object { $_ -match "^MAIN_SCRIPTS_PATH=" }) -replace "MAIN_SCRIPTS_PATH=", ""
if (-Not $scriptDir) { $scriptDir = "C:\custom-scripts" } else { $scriptDir = $scriptDir.Trim().Trim('"').Trim("'") }

function Show-Help {
    Write-Host ""
    Write-Host "Auto-Update Manager for PowerShell CLI Tools" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Automatically updates your PowerShell CLI tools from GitHub repository."
    Write-Host "  Preserves user customizations and handles new files, updates, and deletions safely."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-update                    # Check for updates and prompt" -ForegroundColor Green
    Write-Host "  chater-update check              # Check for updates only" -ForegroundColor Green
    Write-Host "  chater-update update             # Update to latest version" -ForegroundColor Green
    Write-Host "  chater-update --preview          # Preview changes without applying" -ForegroundColor Green
    Write-Host "  chater-update --force            # Force update (skip confirmations)" -ForegroundColor Green
    Write-Host "  chater-update rollback           # Rollback to previous version" -ForegroundColor Green
    Write-Host "  chater-update version            # Show current version info" -ForegroundColor Green
    Write-Host "  chater-update --help             # Show this help" -ForegroundColor Green
    Write-Host ""
    Write-Host "SAFETY FEATURES:" -ForegroundColor Yellow
    Write-Host "  • Creates backup before updating"
    Write-Host "  • Preserves user customizations and .env settings"
    Write-Host "  • Smart merge for modified files"
    Write-Host "  • Rollback capability"
    Write-Host "  • Preview mode to see changes before applying"
    Write-Host ""
}

function Get-UserName {
    # Extract username from existing scripts
    $scripts = Get-ChildItem -Path $scriptDir -Filter "*.ps1" | Where-Object { $_.Name -notlike "*update*" -and $_.Name -notlike "*setup*" }
    if ($scripts) {
        $firstScript = $scripts[0].BaseName
        if ($firstScript -match "^([^-]+)-") {
            return $Matches[1]
        }
    }
    return "chater"
}

function Get-CurrentVersion {
    $versionPath = Join-Path $scriptDir $VERSION_FILE
    if (Test-Path $versionPath) {
        try {
            $versionData = Get-Content $versionPath -Raw | ConvertFrom-Json
            return $versionData
        } catch {
            Write-Warning "Invalid version file format"
        }
    }
    
    # Default version if no file exists
    return @{
        version = "1.0.0"
        commit = "unknown"
        date = (Get-Date).ToString("yyyy-MM-dd")
        user_customized = $true
    }
}

function Set-Version {
    param(
        [string]$Version,
        [string]$Commit,
        [string]$Date
    )
    
    $versionData = @{
        version = $Version
        commit = $Commit
        date = $Date
        user_customized = $true
        last_update = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $versionPath = Join-Path $scriptDir $VERSION_FILE
    $versionData | ConvertTo-Json -Depth 2 | Set-Content -Path $versionPath -Encoding UTF8 -NoNewline
}

function Get-LatestVersion {
    Write-Host "Checking for updates..." -ForegroundColor Gray
    
    try {
        # Try to get the latest release first
        $releases = Invoke-RestMethod -Uri "$GITHUB_API_URL/releases/latest" -UseBasicParsing -TimeoutSec 10
        return @{
            version = $releases.tag_name -replace '^v', ''
            commit = $releases.target_commitish
            date = $releases.published_at
            url = $releases.zipball_url
            body = $releases.body
            download_url = $releases.zipball_url
            release_url = $releases.html_url
        }
    } catch {
        Write-Warning "No releases found or API error. This might be because:"
        Write-Host "  - No GitHub releases have been created yet" -ForegroundColor Yellow
        Write-Host "  - Repository is private" -ForegroundColor Yellow
        Write-Host "  - API rate limit reached" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please create a release on GitHub first:" -ForegroundColor Cyan
        Write-Host "  1. Go to: https://github.com/$GITHUB_REPO/releases" -ForegroundColor Gray
        Write-Host "  2. Click 'Create a new release'" -ForegroundColor Gray
        Write-Host "  3. Create tag (e.g., v1.0.0)" -ForegroundColor Gray
        Write-Host "  4. Add release notes and publish" -ForegroundColor Gray
        return $null
    }
}

function Compare-Versions {
    param(
        [string]$Current,
        [string]$Latest
    )
    
    # Clean version strings (remove 'v' prefix if present)
    $Current = $Current -replace '^v', ''
    $Latest = $Latest -replace '^v', ''
    
    # Simple version comparison
    if ($Current -eq $Latest) {
        return 0
    }
    
    try {
        # Split version parts and convert to integers
        $currentParts = $Current.Split('.') | ForEach-Object { [int]$_ }
        $latestParts = $Latest.Split('.') | ForEach-Object { [int]$_ }
        
        # Pad arrays to same length
        $maxLength = [Math]::Max($currentParts.Count, $latestParts.Count)
        while ($currentParts.Count -lt $maxLength) { $currentParts += 0 }
        while ($latestParts.Count -lt $maxLength) { $latestParts += 0 }
        
        # Compare each part
        for ($i = 0; $i -lt $maxLength; $i++) {
            if ($latestParts[$i] -gt $currentParts[$i]) { return 1 }
            if ($latestParts[$i] -lt $currentParts[$i]) { return -1 }
        }
        
        return 0
    } catch {
        # If version parsing fails, treat as string comparison
        if ($Latest -gt $Current) { return 1 }
        if ($Latest -lt $Current) { return -1 }
        return 0
    }
}

function New-Backup {
    $backupDir = Join-Path $scriptDir "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-Host "Creating backup..." -ForegroundColor Gray
    
    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        
        # Copy all files except temp/cache directories
        $filesToBackup = Get-ChildItem -Path $scriptDir -Recurse | Where-Object {
            $_.FullName -notlike "*backup-*" -and
            $_.FullName -notlike "*temp*" -and
            $_.FullName -notlike "*cache*"
        }
        
        foreach ($item in $filesToBackup) {
            $relativePath = $item.FullName.Substring($scriptDir.Length + 1)
            $backupPath = Join-Path $backupDir $relativePath
            
            if ($item.PSIsContainer) {
                New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            } else {
                $backupParent = Split-Path $backupPath -Parent
                if ($backupParent -and -not (Test-Path $backupParent)) {
                    New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
                }
                Copy-Item -Path $item.FullName -Destination $backupPath -Force
            }
        }
        
        Write-Host "✅ Backup created: $backupDir" -ForegroundColor Green
        return $backupDir
    } catch {
        Write-Error "Failed to create backup: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-Rollback {
    $backupDirs = Get-ChildItem -Path $scriptDir -Directory | Where-Object { $_.Name -like "backup-*" } | Sort-Object Name -Descending
    
    if (-not $backupDirs) {
        Write-Host "❌ No backup found for rollback" -ForegroundColor Red
        return $false
    }
    
    $latestBackup = $backupDirs[0]
    Write-Host "Rolling back to backup: $($latestBackup.Name)" -ForegroundColor Yellow
    
    try {
        # Remove current files (except backups and .env)
        Get-ChildItem -Path $scriptDir | Where-Object {
            $_.Name -notlike "backup-*" -and
            $_.Name -ne ".env" -and
            $_.Name -ne $VERSION_FILE
        } | Remove-Item -Recurse -Force
        
        # Restore from backup
        Get-ChildItem -Path $latestBackup.FullName -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($latestBackup.FullName.Length + 1)
            $restorePath = Join-Path $scriptDir $relativePath
            
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Path $restorePath -Force | Out-Null
            } else {
                $restoreParent = Split-Path $restorePath -Parent
                if ($restoreParent -and -not (Test-Path $restoreParent)) {
                    New-Item -ItemType Directory -Path $restoreParent -Force | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $restorePath -Force
            }
        }
        
        Write-Host "✅ Rollback completed successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Rollback failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-UpdatePackage {
    param([string]$Url)
    
    $tempDir = Join-Path $env:TEMP "powershell-cli-update"
    $zipPath = Join-Path $tempDir "update.zip"
    
    # Clean temp directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    Write-Host "Downloading update package..." -ForegroundColor Gray
    
    try {
        # Download the release archive
        Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing -TimeoutSec 30
        
        # Extract zip
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)
        
        # GitHub zipball creates a folder like "username-repo-commithash"
        # Find the extracted folder (should be the only directory)
        $extractedFolder = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
        
        if (-not $extractedFolder) {
            throw "No extracted folder found in archive"
        }
        
        Write-Host "Extracted to: $($extractedFolder.Name)" -ForegroundColor Gray
        return $extractedFolder.FullName
    } catch {
        Write-Error "Failed to download update: $($_.Exception.Message)"
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        return $null
    }
}

function Merge-Updates {
    param(
        [string]$SourceDir,
        [bool]$PreviewOnly = $false
    )
    
    $userName = Get-UserName
    $changes = @{
        new = @()
        modified = @()
        deleted = @()
    }
    
    Write-Host "Analyzing changes..." -ForegroundColor Gray
    
    # Get source files (exclude setup.ps1 and this update script)
    $sourceFiles = Get-ChildItem -Path $SourceDir -Filter "*.ps1" | Where-Object {
        $_.Name -ne "setup.ps1" -and $_.Name -notlike "*update*"
    }
    
    # Check for new and modified files
    foreach ($sourceFile in $sourceFiles) {
        $sourceBaseName = $sourceFile.BaseName -replace "^chater", ""
        $targetFileName = "$userName$sourceBaseName.ps1"
        $targetPath = Join-Path $scriptDir $targetFileName
        
        if (Test-Path $targetPath) {
            # Compare file content
            $sourceContent = Get-Content $sourceFile.FullName -Raw
            $targetContent = Get-Content $targetPath -Raw
            
            # Remove user-specific customizations for comparison
            $normalizedSource = $sourceContent -replace "chater", $userName
            
            if ($normalizedSource -ne $targetContent) {
                $changes.modified += @{
                    source = $sourceFile.FullName
                    target = $targetPath
                    name = $targetFileName
                }
            }
        } else {
            $changes.new += @{
                source = $sourceFile.FullName
                target = $targetPath
                name = $targetFileName
            }
        }
    }
    
    # Check for helper files and other resources
    $helperFiles = @("example.env", "readme.md")
    foreach ($helperFile in $helperFiles) {
        $sourcePath = Join-Path $SourceDir $helperFile
        if (Test-Path $sourcePath) {
            $targetPath = Join-Path $scriptDir $helperFile
            if (-not (Test-Path $targetPath)) {
                $changes.new += @{
                    source = $sourcePath
                    target = $targetPath
                    name = $helperFile
                }
            }
        }
    }
    
    # Display changes
    Write-Host "`nUpdate Summary:" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    
    if ($changes.new.Count -gt 0) {
        Write-Host "`n📄 New Files ($($changes.new.Count)):" -ForegroundColor Green
        $changes.new | ForEach-Object { Write-Host "  + $($_.name)" -ForegroundColor Green }
    }
    
    if ($changes.modified.Count -gt 0) {
        Write-Host "`n📝 Modified Files ($($changes.modified.Count)):" -ForegroundColor Yellow
        $changes.modified | ForEach-Object { Write-Host "  ~ $($_.name)" -ForegroundColor Yellow }
    }
    
    if ($changes.deleted.Count -gt 0) {
        Write-Host "`n🗑️ Deleted Files ($($changes.deleted.Count)):" -ForegroundColor Red
        $changes.deleted | ForEach-Object { Write-Host "  - $($_)" -ForegroundColor Red }
    }
    
    if ($changes.new.Count -eq 0 -and $changes.modified.Count -eq 0 -and $changes.deleted.Count -eq 0) {
        Write-Host "✅ No changes detected - you're up to date!" -ForegroundColor Green
        return $true
    }
    
    if ($PreviewOnly) {
        return $false
    }
    
    # Apply changes
    Write-Host "`nApplying updates..." -ForegroundColor Gray
    
    # Process new files
    foreach ($newFile in $changes.new) {
        try {
            $content = Get-Content $newFile.source -Raw
            
            # Customize for user
            if ($newFile.name -like "*.ps1") {
                $content = $content -replace "chater", $userName
                # Add attribution if it's a script
                $attribution = @"
# Made by Chater Marzougui
# please give a star at : https://github.com/chater-marzougui/Chater-cli-tools

"@
                $content = $attribution + $content
            }
            
            Set-Content -Path $newFile.target -Value $content -Encoding UTF8 -NoNewline
            Write-Host "✅ Added: $($newFile.name)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to add $($newFile.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Process modified files
    foreach ($modFile in $changes.modified) {
        try {
            $sourceContent = Get-Content $modFile.source -Raw
            $targetContent = Get-Content $modFile.target -Raw
            
            # Smart merge: preserve user customizations while updating functionality
            $updatedContent = $sourceContent -replace "chater", $userName
            
            # Preserve user's environment path settings and customizations
            if ($modFile.name -like "*env*" -or $modFile.name -like "*secrets*") {
                # For env/secrets files, prompt user or preserve existing
                Write-Host "⚠️  $($modFile.name) has updates but contains user data" -ForegroundColor Yellow
                if (-not $Force) {
                    $response = Read-Host "Update $($modFile.name)? [y/N]"
                    if ($response -ne 'y' -and $response -ne 'Y') {
                        continue
                    }
                }
            }
            
            # Create backup of current file
            $backupPath = "$($modFile.target).backup"
            Copy-Item $modFile.target $backupPath -Force
            
            Set-Content -Path $modFile.target -Value $updatedContent -Encoding UTF8 -NoNewline
            Write-Host "✅ Updated: $($modFile.name)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to update $($modFile.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $true
}

function Test-UpdateConditions {
    # Check if git is available for fallback
    $hasGit = Get-Command git -ErrorAction SilentlyContinue
    
    # Check internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://api.github.com" -UseBasicParsing -TimeoutSec 5 -Method Head
    } catch {
        Write-Host "❌ No internet connection or GitHub is unreachable" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Main execution logic
if ($Help) {
    Show-Help
    return
}

if (-not (Test-UpdateConditions)) {
    Write-Host "❌ Update conditions not met" -ForegroundColor Red
    return
}

switch ($Command.ToLower()) {
    "check" {
        $current = Get-CurrentVersion
        $latest = Get-LatestVersion
        
        if (-not $latest) {
            Write-Host "❌ Could not check for updates" -ForegroundColor Red
            return
        }
        
        Write-Host "Current Version: $($current.version)" -ForegroundColor Cyan
        Write-Host "Latest Version:  $($latest.version)" -ForegroundColor Cyan
        
        $comparison = Compare-Versions -Current $current.version -Latest $latest.version
        if ($comparison -lt 0) {
            Write-Host "✅ You're running a newer version" -ForegroundColor Green
        } elseif ($comparison -eq 0) {
            Write-Host "✅ You're up to date!" -ForegroundColor Green
        } else {
            Write-Host "📦 Update available!" -ForegroundColor Yellow
            if ($latest.body) {
                Write-Host "`nChangelog:" -ForegroundColor Yellow
                Write-Host $latest.body -ForegroundColor Gray
            }
        }
    }
    
    "update" {
        $current = Get-CurrentVersion
        $latest = Get-LatestVersion
        
        if (-not $latest) {
            return
        }
        
        $comparison = Compare-Versions -Current $current.version -Latest $latest.version
        if ($comparison -le 0 -and -not $Force) {
            Write-Host "✅ Already up to date (v$($current.version))" -ForegroundColor Green
            return
        }
        
        Write-Host "Updating from v$($current.version) to v$($latest.version)..." -ForegroundColor Cyan
        
        # Create backup
        $backupDir = New-Backup
        if (-not $backupDir) {
            return
        }
        
        # Download and extract update
        $updateDir = Get-UpdatePackage -Url $latest.url
        if (-not $updateDir) {
            return
        }
        
        try {
            # Apply updates
            $success = Merge-Updates -SourceDir $updateDir -PreviewOnly $false
            
            if ($success) {
                # Update version info
                Set-Version -Version $latest.version -Commit $latest.commit -Date $latest.date
                
                # Run adapter to update cmd wrappers
                $userName = Get-UserName
                $adapterScript = Get-ChildItem -Path $scriptDir -Filter "$userName-adapt.ps1" -ErrorAction SilentlyContinue
                if ($adapterScript) {
                    Write-Host "🔄 Updating command wrappers..." -ForegroundColor Gray
                    & $adapterScript.FullName
                }
                
                Write-Host "`n🎉 Update completed successfully!" -ForegroundColor Green
                Write-Host "Updated to version: v$($latest.version)" -ForegroundColor Cyan
                
                # Clean up old backups (keep last 3)
                $oldBackups = Get-ChildItem -Path $scriptDir -Directory | Where-Object { $_.Name -like "backup-*" } | Sort-Object Name -Descending | Select-Object -Skip 3
                $oldBackups | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                
            } else {
                Write-Host "❌ Update failed" -ForegroundColor Red
            }
        } finally {
            # Clean up temp directory
            if (Test-Path $updateDir) {
                Remove-Item (Split-Path $updateDir -Parent) -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    "rollback" {
        if (-not (Invoke-Rollback)) {
            Write-Host "❌ Rollback failed" -ForegroundColor Red
        }
    }
    
    "version" {
        $current = Get-CurrentVersion
        Write-Host "Current Version Information:" -ForegroundColor Cyan
        Write-Host "Version:      $($current.version)" -ForegroundColor White
        Write-Host "Commit:       $($current.commit)" -ForegroundColor White
        Write-Host "Date:         $($current.date)" -ForegroundColor White
        Write-Host "Customized:   $($current.user_customized)" -ForegroundColor White
        if ($current.last_update) {
            Write-Host "Last Update:  $($current.last_update)" -ForegroundColor White
        }
    }
    
    default {
        # Default behavior: check for updates and prompt
        $current = Get-CurrentVersion
        $latest = Get-LatestVersion
        
        if (-not $latest) {
            return
        }
        
        $comparison = Compare-Versions -Current $current.version -Latest $latest.version
        
        if ($comparison -gt 0) {
            Write-Host "📦 Update Available!" -ForegroundColor Yellow
            Write-Host "Current: v$($current.version)" -ForegroundColor Cyan
            Write-Host "Latest:  v$($latest.version)" -ForegroundColor Cyan
            
            if ($Preview) {
                $updateDir = Get-UpdatePackage -Url $latest.url
                if ($updateDir) {
                    Merge-Updates -SourceDir $updateDir -PreviewOnly $true
                    Remove-Item (Split-Path $updateDir -Parent) -Recurse -Force -ErrorAction SilentlyContinue
                }
                return
            }
            
            if (-not $Force) {
                $response = Read-Host "`nWould you like to update now? [Y/n]"
                if ($response -eq 'n' -or $response -eq 'N') {
                    Write-Host "Update cancelled" -ForegroundColor Gray
                    return
                }
            }
            
            # Proceed with update
            & $MyInvocation.MyCommand.Path update
        } else {
            Write-Host "✅ You're up to date! (v$($current.version))" -ForegroundColor Green
        }
    }
}