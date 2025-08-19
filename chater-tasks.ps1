param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [switch]$Help
)

# Configuration
$TasksFile = Join-Path $PSScriptRoot "helpers\tasks.txt"

# Ensure tasks file exists
if (-not (Test-Path $TasksFile)) {
    $parentDir = Split-Path $TasksFile -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    New-Item -Path $TasksFile -ItemType File -Force | Out-Null
    Write-Host "Created new tasks file: $TasksFile" -ForegroundColor Green
}

function Get-Arguments {
    param([string[]]$AllArgs)
    
    $result = @{
        TaskText = ""
        Priority = "normal"
        DueDate = $null
        SortBy = $null
    }
    
    $textParts = @()
    $i = 0
    
    while ($i -lt $AllArgs.Count) {
        $arg = $AllArgs[$i]
        
        switch -Regex ($arg) {
            "^-p$|^--priority$|^--p$" {
                if ($i + 1 -lt $AllArgs.Count) {
                    $result.Priority = $AllArgs[$i + 1].ToLower()
                    $i++
                }
            }
            "^-due$|^--due$|^--d$|^--duedate$|^-d$" {
                if ($i + 1 -lt $AllArgs.Count) {
                    try {
                        $result.DueDate = [DateTime]::Parse($AllArgs[$i + 1])
                    } catch {
                        Write-Host "Warning: Invalid date format '$($AllArgs[$i + 1])'. Use YYYY-MM-DD format." -ForegroundColor Yellow
                    }
                    $i++
                }
            }
            "^--sort$|^--sortby$|^--s$" {
                if ($i + 1 -lt $AllArgs.Count) {
                    $result.SortBy = $AllArgs[$i + 1].ToLower()
                    $i++
                }
            }
            default {
                $textParts += $arg
            }
        }
        $i++
    }

    $result.TaskText = $textParts -join " "
    return $result
}

function Get-PriorityIcon {
    param([string]$Priority)
    
    switch ($Priority) {
        "high" { return "🔴" }
        "medium" { return "🟡" }
        "low" { return "🟢" }
        default { return "⚪" }
    }
}

function Get-PriorityColor {
    param([string]$Priority)
    
    switch ($Priority) {
        "high" { return "Red" }
        "medium" { return "Yellow" }
        "low" { return "Green" }
        default { return "White" }
    }
}

function Get-PriorityValue {
    param([string]$Priority)
    
    switch ($Priority) {
        "high" { return 3 }
        "medium" { return 2 }
        "low" { return 1 }
        default { return 0 }
    }
}

function Format-TaskLine {
    param(
        [string]$TaskText,
        [string]$Priority = "normal",
        [Nullable[DateTime]]$DueDate = $null,
        [DateTime]$AddedDate = (Get-Date)
    )
    
    $priorityIcon = Get-PriorityIcon -Priority $Priority
    $timestamp = $AddedDate.ToString("yyyy-MM-dd HH:mm:ss")
    
    $taskLine = "[ ] $priorityIcon $TaskText"
    
    if ($Priority -ne "normal") {
        $taskLine += " [Priority: $Priority]"
    }

    
    if ($DueDate -ne $null) {
        $dueDateStr = $DueDate.ToString("yyyy-MM-dd")
        $taskLine += " [Due: $dueDateStr]"
    }
    
    $taskLine += " (Added: $timestamp)"
    
    return $taskLine
}

function Get-TaskLine {
    param([string]$TaskLine)
    
    $task = @{
        IsCompleted = $false
        Priority = "normal"
        DueDate = $null
        AddedDate = (Get-Date)
        Text = ""
        OriginalLine = $TaskLine
    }
    
    # Check if completed
    $task.IsCompleted = $TaskLine -match '^\[x\]'
    
    # Extract priority
    if ($TaskLine -match '\[Priority: ([^\]]+)\]') {
        $task.Priority = $matches[1]
    }
    
    # Extract due date
    if ($TaskLine -match '\[Due: ([^\]]+)\]') {
        try {
            $task.DueDate = [DateTime]::Parse($matches[1])
        } catch {
            # Ignore invalid dates
        }
    }
    
    # Extract added date
    if ($TaskLine -match '\(Added: ([^)]+)\)') {
        try {
            $task.AddedDate = [DateTime]::Parse($matches[1])
        } catch {
            # Use current date if parsing fails
        }
    }
    
    # Extract task text (remove all metadata)
    $cleanText = $TaskLine -replace '^\[[x ]\]\s*', ''
    $cleanText = $cleanText -replace '[🔴🟡🟢⚪]\s*', ''
    $cleanText = $cleanText -replace '\s*\[Priority: [^\]]+\]', ''
    $cleanText = $cleanText -replace '\s*\[Due: [^\]]+\]', ''
    $cleanText = $cleanText -replace '\s*\(Added: [^)]+\)', ''
    $task.Text = $cleanText.Trim()
    
    return $task
}

function Add-Task {
    param([string[]]$AllArgs)
    
    $parsed = Get-Arguments -AllArgs $AllArgs

    Write-Host $parsed.dueDate -ForegroundColor Green

    if ([string]::IsNullOrWhiteSpace($parsed.TaskText)) {
        Write-Host "Error: Please provide a task description" -ForegroundColor Red
        Write-Host "Usage: chater-tasks add 'Your task description' [-p high|medium|low] [-due YYYY-MM-DD]"
        return
    }
    
    # Validate priority
    if ($parsed.Priority -notin @("high", "medium", "low", "normal")) {
        Write-Host "Warning: Invalid priority '$($parsed.Priority)'. Using 'normal'." -ForegroundColor Yellow
        $parsed.Priority = "normal"
    }

    # Validate due date
    if ($parsed.DueDate -and $parsed.DueDate -lt (Get-Date)) {
        Write-Host "Warning: Due date cannot be in the past. Using current date." -ForegroundColor Yellow
        $parsed.DueDate = (Get-Date)
    }

    if (-not $parsed.DueDate) {
        $newTask = Format-TaskLine -TaskText $parsed.TaskText -Priority $parsed.Priority
    } else {
        $newTask = Format-TaskLine -TaskText $parsed.TaskText -Priority $parsed.Priority -DueDate $parsed.DueDate
    }
    
    
    # Read existing content
    $existingContent = if (Test-Path $TasksFile) { Get-Content $TasksFile } else { @() }
    
    # Add new task at the top
    $newContent = @($newTask) + $existingContent
    
    # Write back to file
    $newContent | Out-File -FilePath $TasksFile -Encoding UTF8
    
    Write-Host "Task added successfully!" -ForegroundColor Green
    Write-Host "Task: $($parsed.TaskText)" -ForegroundColor $(Get-PriorityColor -Priority $parsed.Priority)
    if ($parsed.Priority -ne "normal") {
        Write-Host "Priority: $($parsed.Priority)" -ForegroundColor $(Get-PriorityColor -Priority $parsed.Priority)
    }
    if ($parsed.DueDate) {
        Write-Host "Due: $($parsed.DueDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
    }
}

function Invoke-TaskSort {
    param(
        [array]$Tasks,
        [string]$SortBy
    )
    
    switch ($SortBy) {
        "priority" {
            return $Tasks | Sort-Object @{Expression={Get-PriorityValue -Priority $_.Priority}; Descending=$true}, @{Expression={$_.AddedDate}; Descending=$false}
        }
        "p" {
            return $Tasks | Sort-Object @{Expression={Get-PriorityValue -Priority $_.Priority}; Descending=$true}, @{Expression={$_.AddedDate}; Descending=$false}
        }
        "due" {
            return $Tasks | Sort-Object @{Expression={if ($_.DueDate) { $_.DueDate } else { [DateTime]::MaxValue }}; Descending=$false}, @{Expression={Get-PriorityValue -Priority $_.Priority}; Descending=$true}
        }
        "d" {
            return $Tasks | Sort-Object @{Expression={if ($_.DueDate) { $_.DueDate } else { [DateTime]::MaxValue }}; Descending=$false}, @{Expression={Get-PriorityValue -Priority $_.Priority}; Descending=$true}
        }
        "added" {
            return $Tasks | Sort-Object @{Expression={$_.AddedDate}; Descending=$false}
        }
        default {
            return $Tasks
        }
    }
}

function Show-Tasks-List {
    param([string[]]$AllArgs)
    
    if (-not (Test-Path $TasksFile) -or (Get-Content $TasksFile).Count -eq 0) {
        Write-Host "No tasks found." -ForegroundColor Yellow
        return
    }

    $parsed = Get-Arguments -AllArgs $AllArgs
    $taskLines = Get-Content $TasksFile
    $tasks = @()
    
    foreach ($line in $taskLines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $tasks += Get-TaskLine -TaskLine $line
        }
    }
    
    # Sort tasks if requested
    if ($parsed.SortBy) {
        $tasks = Invoke-TaskSort -Tasks $tasks -SortBy $parsed.SortBy
    }
    
    Write-Host "`nCurrent Tasks:" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan

    for ($i = 0; $i -lt $tasks.Count; $i++) {
        $taskNumber = $i + 1
        $task = $tasks[$i]
        
        $priorityIcon = Get-PriorityIcon -Priority $task.Priority
        $statusIcon = if ($task.IsCompleted) { "✅" } else { "⏳" }
        
        $displayText = "$taskNumber. $statusIcon $priorityIcon $($task.Text)"
        
        # Add due date info
        if ($task.DueDate) {
            $daysUntilDue = ($task.DueDate.Date - (Get-Date).Date).Days
            if ($daysUntilDue -lt 0) {
                $displayText += " 🔥 OVERDUE by $([Math]::Abs($daysUntilDue)) day(s)"
            } elseif ($daysUntilDue -eq 0) {
                $displayText += " ⚡ Due TODAY"
            } elseif ($daysUntilDue -le 3) {
                $displayText += " ⚠️  Due in $daysUntilDue day(s)"
            } else {
                $displayText += " 📅 Due: $($task.DueDate.ToString('MM-dd'))"
            }
        }
        
        $color = if ($task.IsCompleted) { "DarkGreen" } else { Get-PriorityColor -Priority $task.Priority }
        
        # Special coloring for overdue tasks
        if ($task.DueDate -and ($task.DueDate.Date - (Get-Date).Date).Days -lt 0 -and -not $task.IsCompleted) {
            $color = "Red"
        }
        
        Write-Host $displayText -ForegroundColor $color
    }
    Write-Host ""
}

function Complete-Task {
    param([int]$TaskNumber)
    
    if (-not (Test-Path $TasksFile)) {
        Write-Host "No tasks file found." -ForegroundColor Red
        return
    }
    
    $tasks = Get-Content $TasksFile
    
    if ($TaskNumber -lt 1 -or $TaskNumber -gt $tasks.Count) {
        Write-Host "Invalid task number. Please choose between 1 and $($tasks.Count)" -ForegroundColor Red
        return
    }
    
    $taskIndex = $TaskNumber - 1
    $task = $tasks[$taskIndex]
    
    if ($task -match '^\[ \]') {
        $tasks[$taskIndex] = $task -replace '^\[ \]', '[x]'
        $tasks | Out-File -FilePath $TasksFile -Encoding UTF8
        
        $parsedTask = Get-TaskLine -TaskLine $tasks[$taskIndex]
        Write-Host "✅ Completed: $($parsedTask.Text)" -ForegroundColor Green
    } elseif ($task -match '^\[x\]') {
        Write-Host "Task $TaskNumber is already completed!" -ForegroundColor Yellow
    } else {
        Write-Host "Task $TaskNumber doesn't appear to be in the correct format." -ForegroundColor Red
    }
}

function Reset-Task {
    param([int]$TaskNumber)
    
    if (-not (Test-Path $TasksFile)) {
        Write-Host "No tasks file found." -ForegroundColor Red
        return
    }

    $tasks = Get-Content $TasksFile

    if ($TaskNumber -lt 1 -or $TaskNumber -gt $tasks.Count) {
        Write-Host "Invalid task number. Please choose between 1 and $($tasks.Count)" -ForegroundColor Red
        return
    }
    
    $taskIndex = $TaskNumber - 1
    $task = $tasks[$taskIndex]
    
    if ($task -match '^\[x\]') {
        $tasks[$taskIndex] = $task -replace '[x]', ' '
        $tasks | Out-File -FilePath $TasksFile -Encoding UTF8
        
        $parsedTask = Get-TaskLine -TaskLine $tasks[$taskIndex]
        Write-Host "✅ Uncompleted: $($parsedTask.Text)" -ForegroundColor Green
    } elseif ($task -match '^\[ \]') {
        Write-Host "Task $TaskNumber is already Open!" -ForegroundColor Yellow
    } else {
        Write-Host "Task $TaskNumber doesn't appear to be in the correct format." -ForegroundColor Red
    }
}

function Remove-Task {
    param([int]$TaskNumber)
    
    if (-not (Test-Path $TasksFile)) {
        Write-Host "No tasks file found." -ForegroundColor Red
        return
    }
    
    $tasks = Get-Content $TasksFile
    
    if ($TaskNumber -lt 1 -or $TaskNumber -gt $tasks.Count) {
        Write-Host "Invalid task number. Please choose between 1 and $($tasks.Count)" -ForegroundColor Red
        return
    }
    
    $taskIndex = $TaskNumber - 1
    $removedTaskLine = $tasks[$taskIndex]
    $parsedTask = Get-TaskLine -TaskLine $removedTaskLine
    
    # Remove the task
    $newTasks = $tasks | Where-Object { $_ -ne $removedTaskLine }
    
    if ($newTasks) {
        $newTasks | Out-File -FilePath $TasksFile -Encoding UTF8
    } else {
        # If no tasks left, create empty file
        "" | Out-File -FilePath $TasksFile -Encoding UTF8
    }
    
    Write-Host "Task $TaskNumber removed successfully!" -ForegroundColor Green
    Write-Host "Removed: $($parsedTask.Text)" -ForegroundColor Gray
}

function Clear-CompletedTasks {
    if (-not (Test-Path $TasksFile)) {
        Write-Host "No tasks file found." -ForegroundColor Red
        return
    }
    
    $tasks = Get-Content $TasksFile
    $remainingTasks = $tasks | Where-Object { $_ -notmatch '^\[x\]' }
    
    $completedCount = $tasks.Count - $remainingTasks.Count
    
    if ($completedCount -eq 0) {
        Write-Host "No completed tasks to clear." -ForegroundColor Yellow
        return
    }
    
    if ($remainingTasks) {
        $remainingTasks | Out-File -FilePath $TasksFile -Encoding UTF8
    } else {
        "" | Out-File -FilePath $TasksFile -Encoding UTF8
    }
    
    Write-Host "✨ Cleared $completedCount completed task(s)!" -ForegroundColor Green
}

function Clear-AllTasks {
    if (-not (Test-Path $TasksFile)) {
        Write-Host "No tasks file found." -ForegroundColor Red
        return
    }

    $tasks = Get-Content $TasksFile

    if ($tasks.Count -eq 0) {
        Write-Host "No tasks found." -ForegroundColor Yellow
        return
    }

    # Clear all tasks
    "" | Out-File -FilePath $TasksFile -Encoding UTF8
    Write-Host "✨ Cleared all tasks!" -ForegroundColor Green
}

function Show-Stats {
    if (-not (Test-Path $TasksFile)) {
        Write-Host "No tasks file found." -ForegroundColor Red
        return
    }
    
    $taskLines = Get-Content $TasksFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    
    if ($taskLines.Count -eq 0) {
        Write-Host "No tasks found." -ForegroundColor Yellow
        return
    }
    
    $tasks = @()
    foreach ($line in $taskLines) {
        $tasks += Get-TaskLine -TaskLine $line
    }
    
    $totalTasks = $tasks.Count
    $completedTasks = ($tasks | Where-Object { $_.IsCompleted }).Count
    $pendingTasks = $totalTasks - $completedTasks
    $completionRate = if ($totalTasks -gt 0) { [Math]::Round(($completedTasks / $totalTasks) * 100, 1) } else { 0 }
    
    # Priority breakdown
    $highPriority = ($tasks | Where-Object { $_.Priority -eq "high" -and -not $_.IsCompleted }).Count
    $mediumPriority = ($tasks | Where-Object { $_.Priority -eq "medium" -and -not $_.IsCompleted }).Count
    $lowPriority = ($tasks | Where-Object { $_.Priority -eq "low" -and -not $_.IsCompleted }).Count
    
    # Overdue tasks
    $overdueTasks = ($tasks | Where-Object { 
        $_.DueDate -and 
        $_.DueDate.Date -lt (Get-Date).Date -and 
        -not $_.IsCompleted 
    }).Count
    
    # Due today
    $dueTodayTasks = ($tasks | Where-Object { 
        $_.DueDate -and 
        $_.DueDate.Date -eq (Get-Date).Date -and 
        -not $_.IsCompleted 
    }).Count
    
    Write-Host "`n📊 Task Statistics" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "🧮  Total tasks     : $totalTasks" -ForegroundColor White
    Write-Host "✅  Completed        : $completedTasks" -ForegroundColor Green
    Write-Host "🕐  Pending          : $pendingTasks" -ForegroundColor Yellow
    Write-Host "📈  Completion rate  : $completionRate%" -ForegroundColor Cyan
    Write-Host ""
    
    if ($pendingTasks -gt 0) {
        Write-Host "🎯 Priority Breakdown (Pending):" -ForegroundColor Magenta
        if ($highPriority -gt 0) { Write-Host "   🔴 High     : $highPriority" -ForegroundColor Red }
        if ($mediumPriority -gt 0) { Write-Host "   🟡 Medium   : $mediumPriority" -ForegroundColor Yellow }
        if ($lowPriority -gt 0) { Write-Host "   🟢 Low      : $lowPriority" -ForegroundColor Green }
        Write-Host ""
    }
    
    if ($overdueTasks -gt 0 -or $dueTodayTasks -gt 0) {
        Write-Host "⚠️  Urgent Tasks:" -ForegroundColor Red
        if ($overdueTasks -gt 0) { Write-Host "   🔥 Overdue  : $overdueTasks" -ForegroundColor Red }
        if ($dueTodayTasks -gt 0) { Write-Host "   ⚡ Due today: $dueTodayTasks" -ForegroundColor Yellow }
        Write-Host ""
    }
}

function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host "`n📝 PowerShell Task Manager" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  add <task>           Add a new task" -ForegroundColor White
    Write-Host "  list                 List all tasks" -ForegroundColor White
    Write-Host "  complete <number>    Mark task as completed" -ForegroundColor White
    Write-Host "  done <number>        Alias for complete" -ForegroundColor White
    Write-Host "  remove <number>      Remove a task" -ForegroundColor White
    Write-Host "  delete <number>      Alias for remove" -ForegroundColor White
    Write-Host "  clear                Clear all completed tasks" -ForegroundColor White
    Write-Host "  reset                Clear all tasks" -ForegroundColor White
    Write-Host "  stats                Show task statistics" -ForegroundColor White
    Write-Host "  help                 Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -p, --priority <level>   Set priority (high, medium, low)" -ForegroundColor White
    Write-Host "  -due, --due <date>       Set due date (YYYY-MM-DD)" -ForegroundColor White
    Write-Host "  --sort <criteria>        Sort tasks (priority, due, added)" -ForegroundColor White
    Write-Host ""
    if (-not $isSmall) {
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  chater-tasks add 'Buy groceries' -p high -due 2025-07-25" -ForegroundColor Gray
        Write-Host "  chater-tasks add 'Call mom' -p medium" -ForegroundColor Gray
        Write-Host "  chater-tasks list --sort priority" -ForegroundColor Gray
        Write-Host "  chater-tasks list --sort due" -ForegroundColor Gray
        Write-Host "  chater-tasks complete 1" -ForegroundColor Gray
        Write-Host "  chater-tasks stats" -ForegroundColor Gray
        Write-Host "  chater-tasks clear" -ForegroundColor Gray
        Write-Host "  chater-tasks reset" -ForegroundColor Gray
        Write-Host ""
    }
    Write-Host "Priority Icons:" -ForegroundColor Yellow
    Write-Host "  🔴 High    🟡 Medium    🟢 Low    ⚪ Normal" -ForegroundColor White
    Write-Host ""
}


$helpArgs = @("-h", "--h", "help", "-Help")
if ($Help -or $helpArgs -contains $Command) {
    $isSmall = ($Arguments -contains "--small") -or $Command -eq "--small"
    Show-Help -isSmall $isSmall
    return
}

$completedCommands = @("complete", "done", "do")
$unCompletedCommands = @("undone", "undo")
$removeCommands = @("remove", "delete", "rm", "del")

# Main command processing
switch ($Command.ToLower()) {
    "add" {
        Add-Task -AllArgs $Arguments
    }
    "list" {
        Show-Tasks-List -AllArgs $Arguments
    }
    {$_ -in $completedCommands} {
        if ($Arguments.Count -eq 0 -or -not [int]::TryParse($Arguments[0], [ref]$null)) {
            Write-Host "Error: Please provide a valid task number" -ForegroundColor Red
            Write-Host "Usage: chater-tasks complete <task_number>"
        } else {
            Complete-Task -TaskNumber ([int]$Arguments[0])
        }
    }
    {$_ -in $unCompletedCommands} {
        if ($Arguments.Count -eq 0 -or -not [int]::TryParse($Arguments[0], [ref]$null)) {
            Write-Host "Error: Please provide a valid task number" -ForegroundColor Red
            Write-Host "Usage: chater-tasks undo <task_number>"
        } else {
            Reset-Task -TaskNumber ([int]$Arguments[0])
        }
    }
    {$_ -in $removeCommands} {
        if ($Arguments.Count -eq 0 -or -not [int]::TryParse($Arguments[0], [ref]$null)) {
            Write-Host "Error: Please provide a valid task number" -ForegroundColor Red
            Write-Host "Usage: chater-tasks remove <task_number>"
        } else {
            Remove-Task -TaskNumber ([int]$Arguments[0])
        }
    }
    "clear" {
        Clear-CompletedTasks
    }
    "reset" {
        Clear-AllTasks
    }
    "stats" {
        Show-Stats
    }
    default {
        Show-Tasks-List -AllArgs $Arguments
    }
}