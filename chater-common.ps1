$Arguments = $args

$envFilePath = Join-Path $PSScriptRoot ".env"
$scriptDir = (Get-Content $envFilePath | Where-Object { $_ -match "^MainScriptsPath=" }) -replace "MainScriptsPath=", ""
if (-Not $scriptDir) { $scriptDir = "C:\custom-scripts" } else { $scriptDir = $scriptDir.Trim().Trim('"').Trim("'") }
$commonScriptDir = "$scriptDir\common-commands"
$wrapperDir = "$scriptDir\cmd-wrappers"

function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "PowerShell Script Maker" -ForegroundColor Green
    Write-Host "==============================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  If a command is used on daily basis you can make a script to run it with a shortcut."
    Write-Host "  This helps to avoid typing long commands repeatedly."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-common -c <Long> -t <Short>      # Create a script for the specified command"
    Write-Host "  chater-common -f <Path> -t <Short>      # Create a cli shortcut for the specified file"
    Write-Host "  chater-common -l <command>              # List all available commands"
    Write-Host "  chater-common -rm <command>             # Delete the script for the specified command"
    Write-Host "  chater-common -u <command>              # Edit the script for the specified command"
    Write-Host "  chater-common h                         # Show this help message"
    Write-Host ""
    if ($isSmall) {
        List_Commands
        return
    }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-common -c gitpush -t 'git add . && git commit -m ""Auto commit"" && git push'"
    Write-Host "  chater-common -c deploy -t 'docker build -t myapp . && docker run -p 8080:80 myapp'"
    Write-Host "  chater-common -l"
    Write-Host "  chater-common -rm gitpush"
    Write-Host ""
    Write-Host "Note: This file will run the chater-adapt script to create .cmd wrappers for the commands."
    List_Commands
}

function Test-Command {
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Ensure_DirectoryExists {
    if (-not (Test-Path $commonScriptDir)) {
        try {
            New-Item -ItemType Directory -Path $commonScriptDir -Force | Out-Null
            Write-Host "Created directory: $commonScriptDir" -ForegroundColor Green
        }
        catch {
            Write-Host "Error creating directory: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

function Create_Command {
    param(
        [string]$commandName,
        [string]$targetCommand
    )
    
    if ([string]::IsNullOrWhiteSpace($commandName) -or [string]::IsNullOrWhiteSpace($targetCommand)) {
        Write-Host "Error: Both command name and target command are required." -ForegroundColor Red
        Write-Host "Usage: chater-common -c <command> -t <target>" -ForegroundColor Yellow
        return
    }

    Ensure_DirectoryExists

    if (-not (Test-Command $commandName)) {
        Write-Host "Error: Command '$commandName' not found." -ForegroundColor Red
        return
    }

    if (Test-Command $targetCommand) {
        Write-Host "Error: Target command '$targetCommand' already exists." -ForegroundColor Red
        return
    }

    $scriptPath = Join-Path $commonScriptDir "$targetCommand.ps1"

    # Create script content with parameter support
    $scriptContent = @"
# Auto-generated script for: $targetCommand
# Original command: $commandName
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Original command with additional arguments support
`$fullCommand = "$commandName"
Invoke-Expression `$fullCommand @args
"@

    try {
        Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8
        # Run chater-adapt to create .cmd wrappers
        Write-Host "✅ Script created successfully: $scriptPath" -ForegroundColor Green
        & "chater-adapt" -d $commonScriptDir
        Write-Host "  $commandName → $targetCommand" -ForegroundColor White
    }
    catch {
        Write-Host "Error creating script: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Create_FileShortcut {
    param(
        [string]$commandName,
        [string]$targetCommand
    )

    if ([string]::IsNullOrWhiteSpace($commandName) -or [string]::IsNullOrWhiteSpace($targetCommand)) {
        Write-Host "Error: Both full file path and target command are required." -ForegroundColor Red
        Write-Host "Usage: chater-common -f <path> -t <target>" -ForegroundColor Yellow
        return
    }

    Ensure_DirectoryExists

    if (-not (Test-Path $commandName)) {
        Write-Host "Error: File path '$commandName' does not exist." -ForegroundColor Red
        return
    }

    
    if (Test-Command $targetCommand) {
        Write-Host "Error: Target command '$targetCommand' already exists." -ForegroundColor Red
        return
    }

    $scriptPath = Join-Path $commonScriptDir "$targetCommand.ps1"

    # Create script content with parameter support
    $scriptContent = @"
# Auto-generated script for: $targetCommand
# Original file path: $commandName
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

`$fullCommand = "$commandName"
& `$fullCommand
"@


    try {
        Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8
        # Run chater-adapt to create .cmd wrappers
        Write-Host "✅ Script created successfully: $scriptPath" -ForegroundColor Green
        & "chater-adapt" -d $commonScriptDir
        Write-Host "  $commandName → $targetCommand" -ForegroundColor White
    }
    catch {
        Write-Host "Error creating script: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function List_Commands {
    Ensure_DirectoryExists
    
    $scripts = Get-ChildItem -Path $commonScriptDir -Filter "*.ps1" -ErrorAction SilentlyContinue
    
    if ($scripts.Count -eq 0) {
        Write-Host "No custom commands found in: $commonScriptDir" -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "Available Custom Commands:" -ForegroundColor Green
    Write-Host "===========================" -ForegroundColor Green
    Write-Host ""
    
    foreach ($script in $scripts) {
        $commandName = $script.BaseName
        $scriptPath = $script.FullName
        
        try {
            # Read the script content to extract the original command
            $content = Get-Content $scriptPath -Raw
            $originalCommandMatch = [regex]::Match($content, '# Original command: (.+)')
            $originalFilePathMatch = [regex]::Match($content, '# Original file path: (.+)')

            if ($originalCommandMatch.Success) {
                $originalCommand = $originalCommandMatch.Groups[1].Value.Trim()
                Write-Host "⚡  $commandName" -ForegroundColor Cyan -NoNewline
                Write-Host " → " -ForegroundColor White -NoNewline
                Write-Host "$originalCommand" -ForegroundColor Gray
            } 
            elseif($originalFilePathMatch.Success) {
                $originalFilePath = $originalFilePathMatch.Groups[1].Value.Trim()
                Write-Host "📄  $commandName" -ForegroundColor Cyan -NoNewline
                Write-Host " → " -ForegroundColor White -NoNewline
                Write-Host "$originalFilePath" -ForegroundColor Gray
            } 
            else {
                Write-Host "⚠️  $commandName" -ForegroundColor Cyan -NoNewline
                Write-Host " → " -ForegroundColor White -NoNewline
                Write-Host "[Command not found in script]" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  $commandName" -ForegroundColor Cyan -NoNewline
            Write-Host " → " -ForegroundColor White -NoNewline
            Write-Host "[Error reading script]" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Total commands: $($scripts.Count)" -ForegroundColor Green
}

function Remove-Command {
    param([string]$targetCommand)

    if ([string]::IsNullOrWhiteSpace($targetCommand)) {
        Write-Host "Error: Command name is required." -ForegroundColor Red
        Write-Host "Usage: chater-common -rm <command>" -ForegroundColor Yellow
        return
    }
    
    $scriptPath = Join-Path $commonScriptDir "$targetCommand.ps1"
    $scriptCmdPath = Join-Path $wrapperDir "$targetCommand.cmd"
    
    if (Test-Path $scriptCmdPath) {
        Remove-Item $scriptCmdPath -Force
        Write-Host "✅ Cmd Wrapper '$targetCommand.cmd' removed successfully." -ForegroundColor Green
    }

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Command '$targetCommand' not found." -ForegroundColor Yellow
        return
    }
    
    try {
        Remove-Item $scriptPath -Force
        Write-Host "✅ Command '$targetCommand' removed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Error removing command: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Edit-Command {
    param([string]$commandName)
    
    if ([string]::IsNullOrWhiteSpace($targetCommand)) {
        Write-Host "Error: Command name is required." -ForegroundColor Red
        Write-Host "Usage: chater-common -u <command>" -ForegroundColor Yellow
        return
    }

    $scriptPath = Join-Path $commonScriptDir "$targetCommand.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Command '$targetCommand' not found." -ForegroundColor Yellow
        return
    }
    
    try {
        # Try to open with default editor (notepad as fallback)
        if (Get-Command code -ErrorAction SilentlyContinue) {
            Start-Process code $scriptPath
        } elseif (Get-Command notepad++ -ErrorAction SilentlyContinue) {
            Start-Process notepad++ $scriptPath
        } else {
            Start-Process notepad $scriptPath
        }
        Write-Host "✓ Opening '$targetCommand' for editing..." -ForegroundColor Green
    }
    catch {
        Write-Host "Error opening editor: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main script logic

$helpArgs = @("-h", "--h", "help", "-Help")
if ($helpArgs -contains $Arguments[0]) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Parse arguments
$action = $null
$commandName = $null
$targetCommand = $null

for ($i = 0; $i -lt $Arguments.Length; $i++) {
    switch ($Arguments[$i]) {
        "-c" {
            $action = "create"
            if ($i + 1 -lt $Arguments.Length) {
                $commandName = $Arguments[$i + 1]
                $i++
            }
        }
        { $_ -in @("-f", "--file", "-file", "--f") } {
            $action = "fileshortcut"
            if ($i + 1 -lt $Arguments.Length) {
                $commandName = $Arguments[$i + 1]
                $i++
            }
        }
        "-t" {
            if ($i + 1 -lt $Arguments.Length) {
                $targetCommand = $Arguments[$i + 1]
                $i++
            }
        }
        { $_ -in @("-l", "list") } {
            $action = "list"
        }
        "-rm" {
            $action = "remove"
            if ($i + 1 -lt $Arguments.Length) {
                $targetCommand = $Arguments[$i + 1]
                $i++
            }
        }
        "-u" {
            $action = "update"
            if ($i + 1 -lt $Arguments.Length) {
                $targetCommand = $Arguments[$i + 1]
                $i++
            }
        }
    }
}

if ($Arguments.Count -eq 2 -and $null -eq $action) {
    $action = "create"
    $commandName = $Arguments[0]
    $targetCommand = $Arguments[1]
}


if ($Arguments.Count -eq 3 -and $action -eq "fileshortcut" -and ($null -eq $targetCommand -or $null -eq $commandName)) {
    $action = "fileshortcut"
    $commandName = $Arguments[0]
    $targetCommand = $Arguments[1]
}
# Execute based on action
switch ($action) {
    "create" {
        Create_Command -commandName $commandName -targetCommand $targetCommand
    }
    "fileshortcut" {
        Create_FileShortcut -commandName $commandName -targetCommand $targetCommand
    }
    "list" {
        List_Commands
    }
    "remove" {
        Remove-Command -targetCommand $targetCommand
    }
    "update" {
        Edit-Command -targetCommand $targetCommand
    }
    default {
        Write-Host "Invalid usage. Use -h for help." -ForegroundColor Red
        Show-Help
    }
}