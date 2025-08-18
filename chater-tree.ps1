$Arguments = $args

# Default ignored directories and files
$DefaultIgnored = @(
    "node_modules", ".git", ".svn", ".hg", "bin", "obj", "packages",
    ".vs", ".vscode", "dist", "build", "out", "target", "__pycache__",
    ".pytest_cache", ".mypy_cache", ".tox", "venv", "*.dll", "*.class",
    "bower_components", "coverage", ".nyc_output", "logs", "*.log",
    "tmp", "temp", ".tmp", ".temp", "Thumbs.db", ".DS_Store",
    "*.pyc", "*.pyo", "*.pyd", "*.so"
)

function Show-Help {
    Write-Host ""
    Write-Host "Directory Tree Viewer" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Display a visual tree structure of directories and files."
    Write-Host "  Automatically ignores common build/cache folders and provides filtering options."
    Write-Host "  Perfect for exploring project structure and understanding folder organization."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-tree                         # Show tree for current directory" -ForegroundColor Green
    Write-Host "  chater-tree <path>                  # Show tree for specified path" -ForegroundColor Green
    Write-Host "  chater-tree -d <number>             # Limit depth levels" -ForegroundColor Green
    Write-Host "  chater-tree -f                      # Show files only" -ForegroundColor Green
    Write-Host "  chater-tree -dirs                   # Show directories only" -ForegroundColor Green
    Write-Host "  chater-tree -ext <extensions>       # Filter by file extensions" -ForegroundColor Green
    Write-Host "  chater-tree -ignore <patterns>      # Additional ignore patterns" -ForegroundColor Green
    Write-Host "  chater-tree -all                    # Show all files (ignore default filters)" -ForegroundColor Green
    Write-Host "  chater-tree -size                   # Show file sizes" -ForegroundColor Green
    Write-Host "  chater-tree -h                      # Show this help message" -ForegroundColor Green
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-tree C:\Projects\MyApp" -ForegroundColor Green
    Write-Host "  chater-tree -d 3                    # Show only 3 levels deep" -ForegroundColor Green
    Write-Host "  chater-tree -f -ext .js,.ts,.json   # Show only JS/TS/JSON files" -ForegroundColor Green
    Write-Host "  chater-tree -dirs -d 2               # Show only directories, 2 levels" -ForegroundColor Green
    Write-Host "  chater-tree -ignore cache,temp       # Ignore additional folders" -ForegroundColor Green
    Write-Host "  chater-tree -all -size               # Show everything with file sizes" -ForegroundColor Green
    Write-Host ""
    Write-Host "AUTO-IGNORED ITEMS:" -ForegroundColor Yellow
    Write-Host "  📁 Folders: node_modules, .git, bin, obj, dist, build, __pycache__, venv, etc."
    Write-Host "  📄 Files: *.log, *.pyc, *.class, Thumbs.db, .DS_Store, etc."
    Write-Host ""
}

function Format-FileSize {
    param([long]$Size)
    
    if ($Size -lt 1KB) { return "$Size B" }
    elseif ($Size -lt 1MB) { return "{0:N1} KB" -f ($Size / 1KB) }
    elseif ($Size -lt 1GB) { return "{0:N1} MB" -f ($Size / 1MB) }
    else { return "{0:N1} GB" -f ($Size / 1GB) }
}

function Test-IgnoreItem {
    param(
        [string]$ItemName,
        [string]$ItemPath,
        [bool]$IsDirectory,
        [string[]]$IgnorePatterns,
        [bool]$ShowAll
    )
    
    if ($ShowAll) { return $false }
    
    foreach ($pattern in $IgnorePatterns) {
        # Exact match for directories
        if ($IsDirectory -and $ItemName -eq $pattern) { return $true }
        
        # Wildcard pattern matching for files
        if (-not $IsDirectory -and $ItemName -like $pattern) { return $true }
        
        # Path contains pattern
        if ($ItemPath -like "*$pattern*") { return $true }
    }
    
    return $false
}

$Global:shownItemsCount = 0

function Show-TreeStructure {
    param(
        [string]$RootPath,
        [int]$MaxDepth,
        [bool]$FilesOnly,
        [bool]$DirsOnly,
        [string[]]$Extensions,
        [string[]]$IgnorePatterns,
        [bool]$ShowAll,
        [bool]$ShowSize,
        [string]$Prefix = "",
        [int]$CurrentDepth = 0
    )

    if ($MaxDepth -ne -1 -and $CurrentDepth -ge $MaxDepth) { return }

    try {
        $items = Get-ChildItem -Path $RootPath -Force | Sort-Object @{Expression={$_.PSIsContainer}; Descending=$true}, Name
        $filteredItems = @()
        
        foreach ($item in $items) {
            # Apply ignore filters
            if (Test-IgnoreItem -ItemName $item.Name -ItemPath $item.FullName -IsDirectory $item.PSIsContainer -IgnorePatterns $IgnorePatterns -ShowAll $ShowAll) {
                continue
            }
            
            # Apply type filters
            if ($FilesOnly -and $item.PSIsContainer) { continue }
            if ($DirsOnly -and -not $item.PSIsContainer) { continue }
            
            # Apply extension filters
            if ($Extensions.Count -gt 0 -and -not $item.PSIsContainer) {
                $matchesExtension = $false
                foreach ($ext in $Extensions) {
                    if ($item.Extension -eq $ext -or $item.Name -like "*$ext") {
                        $matchesExtension = $true
                        break
                    }
                }
                if (-not $matchesExtension) { continue }
            }
            
            $filteredItems += $item
        }
        
        $Global:shownItemsCount += $filteredItems.Count

        for ($i = 0; $i -lt $filteredItems.Count; $i++) {
            $item = $filteredItems[$i]
            $isLast = ($i -eq $filteredItems.Count - 1)
            
            # Choose tree characters
            $connector = if ($isLast) { "└── " } else { "├── " }
            $nextPrefix = if ($isLast) { "$Prefix    " } else { "$Prefix│   " }
            
            # Choose icon and color
            if ($item.PSIsContainer) {
                $icon = "📁"
                $color = "Blue"
            } else {
                $icon = switch ($item.Extension) {
                    ".ps1" { "⚡" }
                    ".js" { "🟨" }
                    ".ts" { "🔷" }
                    ".py" { "🐍" }
                    ".json" { "📋" }
                    ".xml" { "📄" }
                    ".md" { "📝" }
                    ".txt" { "📄" }
                    ".log" { "📊" }
                    ".exe" { "⚙️ " }
                    ".env" { "⚙️ " }
                    ".dll" { "🔧" }
                    ".zip" { "📦" }
                    ".png" { "🖼️" }
                    ".jpg" { "🖼️" }
                    ".gif" { "🖼️" }
                    ".css" { "🎨" }
                    ".html" { "🌐" }
                    default { "📄" }
                }
                $color = "White"
            }
            
            # Format size if requested
            $sizeInfo = ""
            if ($ShowSize -and -not $item.PSIsContainer) {
                $sizeInfo = " ($(Format-FileSize $item.Length))"
            }
            
            # Display the item
            Write-Host "$Prefix$connector$icon " -NoNewline
            Write-Host "$($item.Name)$sizeInfo" -ForegroundColor $color
            
            # Recurse into directories
            if ($item.PSIsContainer -and ($MaxDepth -eq -1 -or $CurrentDepth + 1 -lt $MaxDepth)) {
                Show-TreeStructure -RootPath $item.FullName -MaxDepth $MaxDepth -FilesOnly $FilesOnly -DirsOnly $DirsOnly -Extensions $Extensions -IgnorePatterns $IgnorePatterns -ShowAll $ShowAll -ShowSize $ShowSize -Prefix $nextPrefix -CurrentDepth ($CurrentDepth + 1)
            }
        }
    }
    catch {
        Write-Host "$Prefix├── ❌ Access Denied" -ForegroundColor Red
    }
}

# Check for help
if ($Arguments -contains "-h" -or $Arguments -contains "--help" -or $Arguments -contains "help" -or $Arguments -contains "-Help") {
    Show-Help
    return
}

# Parse arguments
$MaxDepth = -1
$FilesOnly = $false
$DirsOnly = $false
$Extensions = @()
$AdditionalIgnore = @()
$ShowAll = $false
$ShowSize = $false
$Path = "."
$StartFrom = 0

if ($Arguments.Count -gt 0 -and (Test-Path $Arguments[0])) {
    $Path = $Arguments[0]
    $StartFrom = 1
}

for ($i = $StartFrom; $i -lt $Arguments.Count; $i++) {
    switch ($Arguments[$i]) {
        "-d" { 
            if ($i + 1 -lt $Arguments.Count) {
                $MaxDepth = [int]$Arguments[$i + 1]
                $i++
            }
        }
        "-depth" { 
            if ($i + 1 -lt $Arguments.Count) {
                $MaxDepth = [int]$Arguments[$i + 1]
                $i++
            }
        }
        "-f" { $FilesOnly = $true }
        "-files" { $FilesOnly = $true }
        "-dirs" { $DirsOnly = $true }
        "-directories" { $DirsOnly = $true }
        "-ext" {
            if ($i + 1 -lt $Arguments.Count) {
                $Extensions = $Arguments[$i + 1].Split(',') | ForEach-Object { $_.Trim() }
                $i++
            }
        }
        "-ignore" {
            if ($i + 1 -lt $Arguments.Count) {
                $AdditionalIgnore = $Arguments[$i + 1].Split(',') | ForEach-Object { $_.Trim() }
                $i++
            }
        }
        "-all" { $ShowAll = $true }
        "-size" { $ShowSize = $true }
        "-s" { $ShowSize = $true }
    }
}

# Validate path
if (-not (Test-Path $Path)) {
    Write-Host ""
    Write-Host "❌ Error: Path '$Path' does not exist" -ForegroundColor Red
    Write-Host ""
    return
}

$resolvedPath = Resolve-Path $Path
$pathInfo = Get-Item $resolvedPath

# Combine ignore patterns
$allIgnorePatterns = $DefaultIgnored + $AdditionalIgnore

# Show header
Write-Host ""
Write-Host "🌳 Directory Tree: " -NoNewline
Write-Host "$($pathInfo.FullName)" -ForegroundColor Green
Write-Host ""

# Handle single file
if (-not $pathInfo.PSIsContainer) {
    $icon = if ($pathInfo.Extension -eq ".ps1") { "⚡" } else { "📄" }
    Write-Host "$icon $($pathInfo.Name)" -ForegroundColor White
    if ($ShowSize) {
        Write-Host "   Size: $(Format-FileSize $pathInfo.Length)" -ForegroundColor Gray
    }
    Write-Host ""
    return
}

# Show tree structure
Show-TreeStructure -RootPath $resolvedPath -MaxDepth $MaxDepth -FilesOnly $FilesOnly -DirsOnly $DirsOnly -Extensions $Extensions -IgnorePatterns $allIgnorePatterns -ShowAll $ShowAll -ShowSize $ShowSize

Write-Host ""

# Show summary
$totalItems = (Get-ChildItem -Path $resolvedPath -Recurse -Force | Measure-Object).Count
Write-Host "📊 Summary: $totalItems items found" -ForegroundColor Cyan
Write-Host "📊 Summary: $Global:shownItemsCount items found" -ForegroundColor Cyan

Write-Host "📊 Summary: $Global:shownItemsCount items shown" -ForegroundColor Cyan
if (-not $ShowAll -and $totalItems -gt $Global:shownItemsCount) {
    Write-Host "   ($($totalItems - $Global:shownItemsCount) items filtered out)" -ForegroundColor Gray
}
Write-Host ""