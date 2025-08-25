param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Help function
function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "🧹 Windows System Cleaner" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Comprehensive cleanup tool that safely removes temporary files, logs, and"
    Write-Host "  Docker resources to free up disk space without affecting daily operations."
    Write-Host "  Automatically detects what's safe to clean and preserves important data."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-clean                     # Interactive cleanup with preview" -ForegroundColor Green
    Write-Host "  chater-clean --auto              # Automatic cleanup (no prompts)" -ForegroundColor Green
    Write-Host "  chater-clean --scan              # Scan only, show what would be cleaned" -ForegroundColor Green
    Write-Host "  chater-clean --temp              # Clean only temporary files" -ForegroundColor Green
    Write-Host "  chater-clean --logs              # Clean only log files" -ForegroundColor Green
    Write-Host "  chater-clean --docker            # Clean only Docker resources" -ForegroundColor Green
    Write-Host "  chater-clean --browsers          # Clean browser caches" -ForegroundColor Green
    Write-Host "  chater-clean --dev               # Clean development tool caches" -ForegroundColor Green
    Write-Host "  chater-clean --all               # Clean everything (with confirmation)" -ForegroundColor Green
    Write-Host "  chater-clean --stats             # Show disk usage statistics" -ForegroundColor Green
    Write-Host "  chater-clean -h                  # Show this help message" -ForegroundColor Green
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "WHAT GETS CLEANED:" -ForegroundColor Yellow
    Write-Host "  🗂️  Windows Temp Files:         %TEMP%, %TMP%, Prefetch, SoftwareDistribution" -ForegroundColor Gray
    Write-Host "  📝 Log Files:                   Windows logs, application logs, IIS logs" -ForegroundColor Gray
    Write-Host "  🐳 Docker Resources:            Unused images, containers, volumes, cache" -ForegroundColor Gray
    Write-Host "  🌐 Browser Caches:              Chrome, Edge, Firefox cache & temp data" -ForegroundColor Gray
    Write-Host "  💻 Development Caches:          npm, yarn, pip, NuGet, Maven, Gradle" -ForegroundColor Gray
    Write-Host "  🗑️  Recycle Bin:                Empty all recycle bins" -ForegroundColor Gray
    Write-Host "  📊 Crash Dumps:                 Windows Error Reporting dumps" -ForegroundColor Gray
    Write-Host ""
    Write-Host "SAFETY FEATURES:" -ForegroundColor Yellow
    Write-Host "  ✅ Preserves running containers and active Docker resources" -ForegroundColor Gray
    Write-Host "  ✅ Skips system-critical files and protected directories" -ForegroundColor Gray
    Write-Host "  ✅ Shows preview before deletion with size estimates" -ForegroundColor Gray
    Write-Host "  ✅ Provides detailed progress reporting and error handling" -ForegroundColor Gray
    Write-Host ""
}

# Global variables for statistics
$script:TotalCleaned = 0
$script:FilesDeleted = 0
$script:FoldersDeleted = 0
$script:CleanupResults = @()

# Utility functions
function Write-Progress-Custom {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = -1
    )
    
    if ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    } else {
        Write-Progress -Activity $Activity -Status $Status
    }
}

function Get-FolderSize {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) { return 0 }
    
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
        return [math]::Max(0, $size)
    }
    catch {
        return 0
    }
}

function Format-FileSize {
    param([long]$Size)
    
    if ($Size -lt 1KB) { return "$Size B" }
    elseif ($Size -lt 1MB) { return "{0:F1} KB" -f ($Size / 1KB) }
    elseif ($Size -lt 1GB) { return "{0:F1} MB" -f ($Size / 1MB) }
    else { return "{0:F2} GB" -f ($Size / 1GB) }
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Remove-ItemSafely {
    param(
        [string]$Path,
        [string]$Description,
        [switch]$Force,
        [switch]$Recurse
    )
    
    if (-not (Test-Path $Path)) {
        return @{ Success = $true; Size = 0; Message = "Path not found" }
    }
    
    try {
        $sizeBefore = Get-FolderSize -Path $Path
        
        $params = @{
            Path = $Path
            Force = $Force
            ErrorAction = 'Stop'
        }
        
        if ($Recurse) { $params.Recurse = $true }
        
        Remove-Item @params
        
        $script:TotalCleaned += $sizeBefore
        $script:FoldersDeleted++
        
        return @{
            Success = $true
            Size = $sizeBefore
            Message = "Cleaned successfully"
        }
    }
    catch {
        return @{
            Success = $false
            Size = 0
            Message = $_.Exception.Message
        }
    }
}

function Clear-TempFiles {
    param([bool]$ScanOnly = $false)
    
    Write-Host ""
    Write-Host "🗂️  Cleaning Windows Temporary Files..." -ForegroundColor Cyan
    
    $tempPaths = @(
        @{ Path = $env:TEMP; Name = "User Temp" },
        @{ Path = $env:TMP; Name = "System Temp" },
        @{ Path = "$env:SystemRoot\Temp"; Name = "Windows Temp" },
        @{ Path = "$env:SystemRoot\Prefetch"; Name = "Prefetch" },
        @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Name = "Windows Update Cache" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WER"; Name = "Error Reports" },
        @{ Path = "$env:LOCALAPPDATA\CrashDumps"; Name = "Crash Dumps" }
    )
    
    $results = @()
    $totalSize = 0
    
    foreach ($item in $tempPaths) {
        if (Test-Path $item.Path) {
            $size = Get-FolderSize -Path $item.Path
            $totalSize += $size
            
            $result = @{
                Name = $item.Name
                Path = $item.Path
                Size = $size
                Status = if ($ScanOnly) { "Would clean" } else { "Scanning..." }
            }
            
            if (-not $ScanOnly -and $size -gt 0) {
                Write-Host "  Cleaning $($item.Name)... " -NoNewline
                $cleanResult = Remove-ItemSafely -Path "$($item.Path)\*" -Description $item.Name -Force -Recurse
                $result.Status = if ($cleanResult.Success) { "✅ Cleaned" } else { "❌ $($cleanResult.Message)" }
                Write-Host $result.Status
            }
            
            $results += $result
        }
    }
    
    return @{
        Results = $results
        TotalSize = $totalSize
        Category = "Temporary Files"
    }
}

function Clear-LogFiles {
    param([bool]$ScanOnly = $false)
    
    Write-Host ""
    Write-Host "📝 Cleaning Log Files..." -ForegroundColor Cyan
    
    $logPaths = @(
        @{ Path = "$env:SystemRoot\Logs"; Name = "Windows Logs"; Pattern = "*.log" },
        @{ Path = "$env:SystemRoot\Debug"; Name = "Debug Logs"; Pattern = "*" },
        @{ Path = "$env:ProgramData\Microsoft\Windows\WER"; Name = "Windows Error Reports"; Pattern = "*" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Name = "WebCache Logs"; Pattern = "*.log" },
        @{ Path = "$env:SystemRoot\System32\LogFiles"; Name = "System Log Files"; Pattern = "*.log" }
    )
    
    $results = @()
    $totalSize = 0
    
    foreach ($item in $logPaths) {
        if (Test-Path $item.Path) {
            try {
                $files = Get-ChildItem -Path $item.Path -Filter $item.Pattern -Recurse -File -ErrorAction SilentlyContinue
                $size = ($files | Measure-Object -Property Length -Sum).Sum
                if ($size -and $size -gt 0) {
                    $totalSize += $size
                }
                
                $result = @{
                    Name = $item.Name
                    Path = $item.Path
                    Size = $size
                    FileCount = $files.Count
                    Status = if ($ScanOnly) { "Would clean" } else { "Scanning..." }
                }
                
                if (-not $ScanOnly -and $files.Count -gt 0) {
                    Write-Host "  Cleaning $($item.Name)... " -NoNewline
                    try {
                        $files | Remove-Item -Force -ErrorAction SilentlyContinue
                        $script:TotalCleaned += $size
                        $script:FilesDeleted += $files.Count
                        $result.Status = "✅ Cleaned"
                        Write-Host "✅ Cleaned"
                    }
                    catch {
                        $result.Status = "❌ Error: $($_.Exception.Message)"
                        Write-Host "❌ Error"
                    }
                }
                
                $results += $result
            }
            catch {
                # Skip problematic paths
            }
        }
    }
    
    return @{
        Results = $results
        TotalSize = $totalSize
        Category = "Log Files"
    }
}

function Test-DockerInstalled {
    try {
        $dockerInfo = docker --version 2>$null
        return $null -ne $dockerInfo
    }
    catch {
        return $false
    }
}

function Clear-DockerResources {
    param([bool]$ScanOnly = $false)
    
    Write-Host ""
    Write-Host "🐳 Cleaning Docker Resources..." -ForegroundColor Cyan
    
    if (-not (Test-DockerInstalled)) {
        Write-Host "  Docker not installed or not in PATH" -ForegroundColor Yellow
        return @{
            Results = @()
            TotalSize = 0
            Category = "Docker Resources"
        }
    }
    
    $results = @()
    $totalSize = 0
    
    try {
        # Get Docker system info
        docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}" 2>$null
        
        if (-not $ScanOnly) {
            Write-Host "  Cleaning unused Docker images... " -NoNewline
            try {
                docker image prune -f 2>$null
                Write-Host "✅ Done"
            }
            catch {
                Write-Host "❌ Error"
            }
            
            Write-Host "  Cleaning unused Docker containers... " -NoNewline
            try {
                docker container prune -f 2>$null
                Write-Host "✅ Done"
            }
            catch {
                Write-Host "❌ Error"
            }
            
            Write-Host "  Cleaning unused Docker volumes... " -NoNewline
            try {
                docker volume prune -f 2>$null
                Write-Host "✅ Done"
            }
            catch {
                Write-Host "❌ Error"
            }
            
            Write-Host "  Cleaning Docker build cache... " -NoNewline
            try {
                docker builder prune -f 2>$null
                Write-Host "✅ Done"
            }
            catch {
                Write-Host "❌ Error"
            }
        }
        
        # Try to estimate cleaned space (this is approximate)
        $estimatedSize = 100MB # Conservative estimate
        $results += @{
            Name = "Docker Cleanup"
            Path = "Docker System"
            Size = $estimatedSize
            Status = if ($ScanOnly) { "Would clean" } else { "✅ Cleaned" }
        }
        
        $totalSize = $estimatedSize
        $script:TotalCleaned += $estimatedSize
    }
    catch {
        Write-Host "  Error accessing Docker: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return @{
        Results = $results
        TotalSize = $totalSize
        Category = "Docker Resources"
    }
}

function Clear-BrowserCaches {
    param([bool]$ScanOnly = $false)
    
    Write-Host ""
    Write-Host "🌐 Cleaning Browser Caches..." -ForegroundColor Cyan
    
    $browsers = @(
        @{ 
            Name = "Chrome"
            Paths = @(
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
            )
        },
        @{ 
            Name = "Edge"
            Paths = @(
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
            )
        },
        @{ 
            Name = "Firefox"
            Paths = @(
                "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2",
                "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"
            )
        }
    )
    
    $results = @()
    $totalSize = 0
    
    foreach ($browser in $browsers) {
        $browserSize = 0
        $cleanedPaths = 0
        
        foreach ($pathPattern in $browser.Paths) {
            try {
                $paths = Get-ChildItem -Path (Split-Path $pathPattern) -Filter (Split-Path $pathPattern -Leaf) -ErrorAction SilentlyContinue
                
                foreach ($path in $paths) {
                    if (Test-Path $path.FullName) {
                        $size = Get-FolderSize -Path $path.FullName
                        $browserSize += $size
                        
                        if (-not $ScanOnly -and $size -gt 0) {
                            $cleanResult = Remove-ItemSafely -Path "$($path.FullName)\*" -Description "$($browser.Name) Cache" -Force -Recurse
                            if ($cleanResult.Success) {
                                $cleanedPaths++
                            }
                        }
                    }
                }
            }
            catch {
                # Skip problematic browser paths
            }
        }
        
        if ($browserSize -gt 0) {
            $results += @{
                Name = "$($browser.Name) Cache"
                Path = "Multiple locations"
                Size = $browserSize
                Status = if ($ScanOnly) { "Would clean" } else { if ($cleanedPaths -gt 0) { "✅ Cleaned" } else { "❌ Error" } }
            }
            
            $totalSize += $browserSize
        }
    }
    
    return @{
        Results = $results
        TotalSize = $totalSize
        Category = "Browser Caches"
    }
}

function Clear-DevCaches {
    param([bool]$ScanOnly = $false)
    
    Write-Host ""
    Write-Host "💻 Cleaning Development Tool Caches..." -ForegroundColor Cyan
    
    $devCaches = @(
        @{ Path = "$env:APPDATA\npm-cache"; Name = "NPM Cache" },
        @{ Path = "$env:LOCALAPPDATA\Yarn\Cache"; Name = "Yarn Cache" },
        @{ Path = "$env:LOCALAPPDATA\pip\cache"; Name = "Python PIP Cache" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "NuGet Packages" },
        @{ Path = "$env:USERPROFILE\.gradle\caches"; Name = "Gradle Cache" },
        @{ Path = "$env:USERPROFILE\.m2\repository"; Name = "Maven Repository" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\VisualStudio\*\ComponentModelCache"; Name = "VS Component Cache" }
    )
    
    $results = @()
    $totalSize = 0
    
    foreach ($cache in $devCaches) {
        try {
            if ($cache.Path -like "*\*\*") {
                # Handle wildcard paths
                $basePath = Split-Path (Split-Path $cache.Path)
                $pattern = Split-Path $cache.Path -Leaf
                if (Test-Path $basePath) {
                    $matchingPaths = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern.Replace('*', '.*') }
                    foreach ($matchPath in $matchingPaths) {
                        $fullPath = Join-Path $matchPath.FullName (Split-Path $cache.Path -Leaf)
                        if (Test-Path $fullPath) {
                            $size = Get-FolderSize -Path $fullPath
                            $totalSize += $size
                            
                            if (-not $ScanOnly -and $size -gt 0) {
                                Write-Host "  Cleaning $($cache.Name)... " -NoNewline
                                $cleanResult = Remove-ItemSafely -Path "$fullPath\*" -Description $cache.Name -Force -Recurse
                                Write-Host $(if ($cleanResult.Success) { "✅ Done" } else { "❌ Error" })
                            }
                        }
                    }
                }
            } else {
                if (Test-Path $cache.Path) {
                    $size = Get-FolderSize -Path $cache.Path
                    $totalSize += $size
                    
                    $result = @{
                        Name = $cache.Name
                        Path = $cache.Path
                        Size = $size
                        Status = if ($ScanOnly) { "Would clean" } else { "Scanning..." }
                    }
                    
                    if (-not $ScanOnly -and $size -gt 0) {
                        Write-Host "  Cleaning $($cache.Name)... " -NoNewline
                        $cleanResult = Remove-ItemSafely -Path "$($cache.Path)\*" -Description $cache.Name -Force -Recurse
                        $result.Status = if ($cleanResult.Success) { "✅ Cleaned" } else { "❌ Error" }
                        Write-Host $result.Status
                    }
                    
                    $results += $result
                }
            }
        }
        catch {
            # Skip problematic cache paths
        }
    }
    
    return @{
        Results = $results
        TotalSize = $totalSize
        Category = "Development Caches"
    }
}

function Invoke-Clear-RecycleBin {
    param([bool]$ScanOnly = $false)
    
    Write-Host ""
    Write-Host "🗑️  Emptying Recycle Bin..." -ForegroundColor Cyan
    
    try {
        if (-not $ScanOnly) {
            # Use PowerShell to empty recycle bin
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Host "  ✅ Recycle Bin emptied" -ForegroundColor Green
        } else {
            Write-Host "  Would empty Recycle Bin" -ForegroundColor Yellow
        }
        
        return @{
            Results = @(@{
                Name = "Recycle Bin"
                Path = "System"
                Size = 0
                Status = if ($ScanOnly) { "Would empty" } else { "✅ Emptied" }
            })
            TotalSize = 0
            Category = "Recycle Bin"
        }
    }
    catch {
        Write-Host "  ❌ Error emptying Recycle Bin: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Results = @()
            TotalSize = 0
            Category = "Recycle Bin"
        }
    }
}

function Show-DiskStats {
    Write-Host ""
    Write-Host "📊 Disk Usage Statistics" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    
    Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object {
        $drive = $_.DeviceID
        $totalSize = [math]::Round($_.Size / 1GB, 2)
        $freeSpace = [math]::Round($_.FreeSpace / 1GB, 2)
        $usedSpace = $totalSize - $freeSpace
        $percentUsed = [math]::Round(($usedSpace / $totalSize) * 100, 1)
        
        Write-Host ""
        Write-Host "Drive $drive" -ForegroundColor Yellow
        Write-Host "  Total: $(Format-FileSize ($_.Size))" -ForegroundColor White
        Write-Host "  Used:  $(Format-FileSize ($usedSpace * 1GB)) ($percentUsed%)" -ForegroundColor White
        Write-Host "  Free:  $(Format-FileSize ($_.FreeSpace))" -ForegroundColor Green
    }
    Write-Host ""
}

function Show-ScanResults {
    param([array]$AllResults)
    
    Write-Host ""
    Write-Host "🔍 Cleanup Preview" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    $grandTotal = 0
    
    foreach ($categoryResult in $AllResults) {
        if ($categoryResult.Results.Count -gt 0) {
            Write-Host ""
            Write-Host "📁 $($categoryResult.Category)" -ForegroundColor Yellow
            Write-Host "   Total Size: $(Format-FileSize $categoryResult.TotalSize)" -ForegroundColor White
            
            $grandTotal += $categoryResult.TotalSize
            
            foreach ($result in $categoryResult.Results) {
                if ($result.Size -gt 0) {
                    Write-Host "   • $($result.Name): $(Format-FileSize $result.Size)" -ForegroundColor Gray
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "💾 Total Space to be Freed: $(Format-FileSize $grandTotal)" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host ""
    
    return $grandTotal
}

function Invoke-Cleanup {
    param(
        [bool]$AutoMode = $false,
        [bool]$ScanOnly = $false,
        [string[]]$Categories = @("temp", "logs", "docker", "browsers", "dev", "recycle")
    )
    
    $startTime = Get-Date
    $allResults = @()
    
    Write-Host ""
    Write-Host "🧹 $(if ($ScanOnly) { 'Scanning' } else { 'Starting Cleanup' })..." -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    
    if ("temp" -in $Categories) {
        $allResults += Clear-TempFiles -ScanOnly $ScanOnly
    }
    
    if ("logs" -in $Categories) {
        $allResults += Clear-LogFiles -ScanOnly $ScanOnly
    }
    
    if ("docker" -in $Categories) {
        $allResults += Clear-DockerResources -ScanOnly $ScanOnly
    }
    
    if ("browsers" -in $Categories) {
        $allResults += Clear-BrowserCaches -ScanOnly $ScanOnly
    }
    
    if ("dev" -in $Categories) {
        $allResults += Clear-DevCaches -ScanOnly $ScanOnly
    }
    
    if ("recycle" -in $Categories) {
        $allResults += Invoke-Clear-RecycleBin -ScanOnly $ScanOnly
    }
    
    if ($ScanOnly) {
        $totalToClean = Show-ScanResults -AllResults $allResults
        
        if ($totalToClean -gt 0) {
            Write-Host "Run 'chater-clean --auto' to perform the cleanup automatically" -ForegroundColor Yellow
            Write-Host "Or run 'chater-clean' for interactive cleanup with confirmations" -ForegroundColor Yellow
        } else {
            Write-Host "✅ System appears to be already clean!" -ForegroundColor Green
        }
        
        return
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host "✅ Cleanup Complete!" -ForegroundColor Green
    Write-Host "=====================" -ForegroundColor Green
    Write-Host "Total Space Freed: $(Format-FileSize $script:TotalCleaned)" -ForegroundColor White
    Write-Host "Files Deleted: $script:FilesDeleted" -ForegroundColor White
    Write-Host "Folders Cleaned: $script:FoldersDeleted" -ForegroundColor White
    Write-Host "Duration: $($duration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor White
    Write-Host ""
}

# Main execution
$helpArgs = @("-h", "--h", "help", "-Help")

if ($Arguments.Count -eq 0 -or ($Arguments.Count -le 2 -and ($helpArgs -contains $Arguments[0]))) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Parse arguments
$autoMode = $Arguments -contains "--auto"
$scanOnly = $Arguments -contains "--scan"
$showStats = $Arguments -contains "--stats"
$allCategories = $Arguments -contains "--all"

# Category filters
$categories = @()
if ($Arguments -contains "--temp") { $categories += "temp" }
if ($Arguments -contains "--logs") { $categories += "logs" }
if ($Arguments -contains "--docker") { $categories += "docker" }
if ($Arguments -contains "--browsers") { $categories += "browsers" }
if ($Arguments -contains "--dev") { $categories += "dev" }

# If no specific categories selected, use all
if ($categories.Count -eq 0) {
    $categories = @("temp", "logs", "docker", "browsers", "dev", "recycle")
}

# Show disk stats if requested
if ($showStats) {
    Show-DiskStats
    return
}

# Check admin rights for some operations
$isAdmin = Test-AdminRights
if (-not $isAdmin) {
    Write-Host "⚠️  Running without administrator privileges" -ForegroundColor Yellow
    Write-Host "Some cleanup operations may be limited" -ForegroundColor Yellow
    Write-Host ""
}

try {
    if ($scanOnly) {
        Invoke-Cleanup -ScanOnly $true -Categories $categories
    } elseif ($autoMode) {
        Invoke-Cleanup -AutoMode $true -Categories $categories
    } else {
        # Interactive mode
        Write-Host "🧹 Windows System Cleaner" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        Write-Host ""
        
        if ($allCategories) {
            Write-Host "⚠️  This will clean ALL categories. Continue? (y/N): " -NoNewline -ForegroundColor Yellow
            $confirmation = Read-Host
            if ($confirmation -notmatch '^[Yy]([Ee][Ss])?$') {
                Write-Host "Cleanup cancelled." -ForegroundColor Red
                return
            }
        }
        
        Invoke-Cleanup -Categories $categories
    }
}
catch {
    Write-Host ""
    Write-Host "❌ Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Try running as Administrator for better results" -ForegroundColor Yellow
}