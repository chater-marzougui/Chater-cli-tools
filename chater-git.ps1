param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Message,

    [Parameter(Position = 2)]
    [string]$Repository,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [switch]$Help
)

function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host "Git Automation Script" -ForegroundColor Green
    Write-Host "=====================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Advanced git workflow automation with multiple commands for repository management."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-git [command] [parameters...]"
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor Yellow
    Write-Host "  commit, c     Standard commit workflow (default)"
    Write-Host "  new, init     Initialize new repository and push"
    Write-Host "  clone         Clone repository with optional branch"
    Write-Host "  branch, b     Branch management operations"
    Write-Host "  pull, p       Advanced pull operations"
    Write-Host "  release, r    Create and push release tags"
    Write-Host "  sync          Sync fork with upstream"
    Write-Host "  clean         Cleanup operations"
    Write-Host "  status, s     Enhanced status display"
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "COMMIT COMMAND:" -ForegroundColor Cyan
    Write-Host "  chater-git [commit] ""message"" [options] [branch]"
    Write-Host "  Options: u (upstream), o (origin)"
    Write-Host ""
    Write-Host "NEW REPOSITORY:" -ForegroundColor Cyan
    Write-Host "  chater-git new ""Initial commit"" ""github.com/user/repo.git"" [branch]"
    Write-Host "  chater-git init ""message"" ""user/repo"" [main]"
    Write-Host ""
    Write-Host "CLONE:" -ForegroundColor Cyan
    Write-Host "  chater-git clone ""user/repo"" [branch] [folder]"
    Write-Host "  chater-git clone ""https://github.com/user/repo.git"" [branch]"
    Write-Host ""
    Write-Host "BRANCH MANAGEMENT:" -ForegroundColor Cyan
    Write-Host "  chater-git branch create ""branch-name"" [from-branch]"
    Write-Host "  chater-git branch switch ""branch-name"""
    Write-Host "  chater-git branch delete ""branch-name"" [remote]"
    Write-Host "  chater-git branch list [remote]"
    Write-Host ""
    Write-Host "PULL OPERATIONS:" -ForegroundColor Cyan
    Write-Host "  chater-git pull [branch] [rebase]"
    Write-Host "  chater-git pull upstream main"
    Write-Host ""
    Write-Host "RELEASE:" -ForegroundColor Cyan
    Write-Host "  chater-git release ""v1.0.0"" ""Release message"""
    Write-Host "  chater-git release ""v1.0.0"" (uses tag name as message)"
    Write-Host ""
    Write-Host "SYNC FORK:" -ForegroundColor Cyan
    Write-Host "  chater-git sync [upstream-branch] [local-branch]"
    Write-Host ""
    Write-Host "CLEANUP:" -ForegroundColor Cyan
    Write-Host "  chater-git clean branches (remove merged branches)"
    Write-Host "  chater-git clean cache (clear git cache)"
    Write-Host "  chater-git clean all"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-git ""Bug fix"" u main"
    Write-Host "  chater-git new ""Initial commit"" ""myusername/myrepo"""
    Write-Host "  chater-git clone ""facebook/react"" main"
    Write-Host "  chater-git branch create ""feature/auth"" main"
    Write-Host "  chater-git release ""v2.1.0"" ""Added new features"""
}

function Invoke-CommitWorkflow {
    param(
        [string]$commitMessage,
        [string[]]$args
    )
    
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        Write-Host "Error: Commit message is required!" -ForegroundColor Red
        return
    }

    $pushCommand = "git push"
    $useUpstream = $false
    $useOrigin = $false
    $branch = ""

    foreach ($arg in $args) {
        switch ($arg) {
            "u" { $useUpstream = $true }
            "o" { $useOrigin = $true }
            default { $branch = $arg }
        }
    }

    Write-Host "Adding all files..." -ForegroundColor Cyan
    git add .

    Write-Host "Committing with message: '$commitMessage'" -ForegroundColor Green
    git commit -m "$commitMessage"

    if ($useUpstream) { $pushCommand += " -u" }
    if ($useOrigin) { $pushCommand += " origin" }
    if ($branch -ne "") { $pushCommand += " $branch" }

    Write-Host "Pushing with: $pushCommand" -ForegroundColor Yellow
    Invoke-Expression $pushCommand
}

function Invoke-NewRepository {
    param(
        [string]$commitMessage,
        [string]$repository,
        [string]$branch = "main"
    )
    
    if ([string]::IsNullOrWhiteSpace($commitMessage) -or [string]::IsNullOrWhiteSpace($repository)) {
        Write-Host "Error: Commit message and repository URL are required!" -ForegroundColor Red
        Write-Host "Usage: chater-git new ""Initial commit"" ""user/repo"" [branch]" -ForegroundColor Yellow
        return
    }

    # Format repository URL
    if ($repository -notmatch "^https?://") {
        if ($repository -match "^[\w-]+/[\w-]+$") {
            $repository = "https://github.com/$repository.git"
        } elseif ($repository -notmatch "\.git$") {
            $repository = "https://$repository"
        }
    }

    Write-Host "Initializing new repository..." -ForegroundColor Cyan
    git init

    Write-Host "Adding remote origin: $repository" -ForegroundColor Cyan
    git remote add origin $repository

    Write-Host "Creating and switching to branch: $branch" -ForegroundColor Cyan
    git branch -M $branch

    Write-Host "Adding all files..." -ForegroundColor Cyan
    git add .

    Write-Host "Creating initial commit: '$commitMessage'" -ForegroundColor Green
    git commit -m "$commitMessage"

    Write-Host "Pushing to origin with upstream..." -ForegroundColor Yellow
    git push -u origin $branch

    Write-Host "Repository setup complete!" -ForegroundColor Green
}

function Invoke-CloneRepository {
    param(
        [string]$repository,
        [string]$branch = "",
        [string]$folder = ""
    )
    
    if ([string]::IsNullOrWhiteSpace($repository)) {
        Write-Host "Error: Repository is required!" -ForegroundColor Red
        return
    }

    # Format repository URL
    if ($repository -notmatch "^https?://") {
        if ($repository -match "^[\w-]+/[\w-]+$") {
            $repository = "https://github.com/$repository.git"
        }
    }

    $cloneCommand = "git clone"
    if ($branch -ne "") {
        $cloneCommand += " -b $branch"
    }
    $cloneCommand += " $repository"
    if ($folder -ne "") {
        $cloneCommand += " $folder"
    }

    Write-Host "Cloning repository: $cloneCommand" -ForegroundColor Cyan
    Invoke-Expression $cloneCommand
}

function Invoke-BranchManagement {
    param(
        [string]$operation,
        [string]$branchName = "",
        [string]$fromBranch = "",
        [string]$extra = ""
    )
    
    switch ($operation) {
        "create" {
            if ([string]::IsNullOrWhiteSpace($branchName)) {
                Write-Host "Error: Branch name is required!" -ForegroundColor Red
                return
            }
            if ($fromBranch -ne "") {
                Write-Host "Creating branch '$branchName' from '$fromBranch'..." -ForegroundColor Cyan
                git checkout -b $branchName $fromBranch
            } else {
                Write-Host "Creating branch '$branchName'..." -ForegroundColor Cyan
                git checkout -b $branchName
            }
        }
        "switch" {
            if ([string]::IsNullOrWhiteSpace($branchName)) {
                Write-Host "Error: Branch name is required!" -ForegroundColor Red
                return
            }
            Write-Host "Switching to branch '$branchName'..." -ForegroundColor Cyan
            git checkout $branchName
        }
        "delete" {
            if ([string]::IsNullOrWhiteSpace($branchName)) {
                Write-Host "Error: Branch name is required!" -ForegroundColor Red
                return
            }
            Write-Host "Deleting local branch '$branchName'..." -ForegroundColor Cyan
            git branch -d $branchName
            if ($fromBranch -eq "remote" -or $extra -eq "remote") {
                Write-Host "Deleting remote branch '$branchName'..." -ForegroundColor Cyan
                git push origin --delete $branchName
            }
        }
        "list" {
            if ($branchName -eq "remote") {
                Write-Host "Remote branches:" -ForegroundColor Cyan
                git branch -r
            } else {
                Write-Host "Local branches:" -ForegroundColor Cyan
                git branch
            }
        }
        default {
            Write-Host "Available branch operations: create, switch, delete, list" -ForegroundColor Yellow
        }
    }
}

function Invoke-PullOperation {
    param(
        [string]$branch = "",
        [string]$rebase = ""
    )
    
    $pullCommand = "git pull"
    if ($rebase -eq "rebase") {
        $pullCommand += " --rebase"
    }
    if ($branch -ne "" -and $branch -ne "rebase") {
        if ($branch -eq "upstream") {
            $pullCommand += " upstream main"
        } else {
            $pullCommand += " origin $branch"
        }
    }

    Write-Host "Pulling changes: $pullCommand" -ForegroundColor Cyan
    Invoke-Expression $pullCommand
}

function Invoke-Release {
    param(
        [string]$tag,
        [string]$message = ""
    )
    
    if ([string]::IsNullOrWhiteSpace($tag)) {
        Write-Host "Error: Tag is required!" -ForegroundColor Red
        return
    }

    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = $tag
    }

    Write-Host "Creating release tag '$tag'..." -ForegroundColor Cyan
    git tag -a $tag -m "$message"

    Write-Host "Pushing tag to origin..." -ForegroundColor Yellow
    git push origin $tag

    Write-Host "Release '$tag' created and pushed!" -ForegroundColor Green
}

function Invoke-SyncFork {
    param(
        [string]$upstreamBranch = "main",
        [string]$localBranch = "main"
    )
    
    Write-Host "Fetching from upstream..." -ForegroundColor Cyan
    git fetch upstream

    Write-Host "Switching to $localBranch..." -ForegroundColor Cyan
    git checkout $localBranch

    Write-Host "Merging upstream/$upstreamBranch..." -ForegroundColor Cyan
    git merge upstream/$upstreamBranch

    Write-Host "Pushing to origin..." -ForegroundColor Yellow
    git push origin $localBranch

    Write-Host "Fork synchronized!" -ForegroundColor Green
}

function Invoke-Cleanup {
    param(
        [string]$type = ""
    )
    
    switch ($type) {
        "branches" {
            Write-Host "Removing merged branches..." -ForegroundColor Cyan
            git branch --merged | ForEach-Object { 
                $branch = $_.Trim()
                if ($branch -notmatch "^\*" -and $branch -ne "main" -and $branch -ne "master") {
                    Write-Host "Deleting merged branch: $branch" -ForegroundColor Yellow
                    git branch -d $branch
                }
            }
        }
        "cache" {
            Write-Host "Clearing git cache..." -ForegroundColor Cyan
            git rm -r --cached .
            git add .
        }
        "all" {
            Invoke-Cleanup -type "branches"
            Invoke-Cleanup -type "cache"
        }
        default {
            Write-Host "Available cleanup options: branches, cache, all" -ForegroundColor Yellow
        }
    }
}

function Show-Status {
    Write-Host "Git Status:" -ForegroundColor Green
    git status --short
    Write-Host "`nCurrent Branch:" -ForegroundColor Green
    git branch --show-current
    Write-Host "`nRemote URLs:" -ForegroundColor Green
    git remote -v
    Write-Host "`nRecent Commits:" -ForegroundColor Green
    git log --oneline -5
}

# Main script logic
$helpArgs = @("-h", "--h", "help", "-Help")
if ($Help -or $helpArgs -contains $Command) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Handle different commands
switch ($Command) {
    { $_ -in @("commit", "c") -or [string]::IsNullOrWhiteSpace($_) } {
        # If no command specified, treat first param as message for backward compatibility
        $commitMessage = if ([string]::IsNullOrWhiteSpace($Command)) { $Command } else { $Message }
        $commitArgs = if ([string]::IsNullOrWhiteSpace($Command)) { $Arguments } else { @($Repository) + $Arguments }
        Invoke-CommitWorkflow -commitMessage $commitMessage -args $commitArgs
    }
    { $_ -in @("new", "init") } {
        $branch = if ($Arguments.Count -gt 0) { $Arguments[0] } else { "main" }
        Invoke-NewRepository -commitMessage $Message -repository $Repository -branch $branch
    }
    "clone" {
        $branch = if ($Arguments.Count -gt 0) { $Arguments[0] } else { "" }
        $folder = if ($Arguments.Count -gt 1) { $Arguments[1] } else { "" }
        Invoke-CloneRepository -repository $Message -branch $branch -folder $folder
    }
    { $_ -in @("branch", "b") } {
        $extra = if ($Arguments.Count -gt 0) { $Arguments[0] } else { "" }
        Invoke-BranchManagement -operation $Message -branchName $Repository -fromBranch $extra -extra ($Arguments -join " ")
    }
    { $_ -in @("pull", "p") } {
        Invoke-PullOperation -branch $Message -rebase $Repository
    }
    { $_ -in @("release", "r") } {
        Invoke-Release -tag $Message -message $Repository
    }
    "sync" {
        $localBranch = if ($Arguments.Count -gt 0) { $Arguments[0] } else { "main" }
        Invoke-SyncFork -upstreamBranch $Message -localBranch $localBranch
    }
    "clean" {
        Invoke-Cleanup -type $Message
    }
    { $_ -in @("status", "s") } {
        Show-Status
    }
    default {
        # Default to commit workflow for backward compatibility
        Invoke-CommitWorkflow -commitMessage $Command -args @($Message, $Repository) + $Arguments
    }
}