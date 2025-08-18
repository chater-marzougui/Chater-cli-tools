param(
    [Parameter(Position = 0)]
    [string]$Message,

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
    Write-Host "  This script automates the git workflow by adding all files, committing with a message,"
    Write-Host "  and pushing to the repository with various options."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-git ""commit message"" [options] [branch]"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  u          Set upstream (-u flag for git push)"
    Write-Host "  o          Push to origin"
    Write-Host "  h, -Help   Show this help message"
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  [message]  Commit message (first parameter)"
    Write-Host "  [branch]   Specify the branch name to push to"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-git ""Initial commit"""
    Write-Host "  chater-git ""Bug fix"" u main"
    Write-Host "  chater-git ""Feature update"" o u origin"
}


$helpArgs = @("-h", "--h", "help", "-Help")
if ($Help -or $helpArgs -contains $Message) {
    $isSmall = ($Arguments -contains "--small") -or $MainCommand -eq "--small"
    Show-Help -isSmall $isSmall
    return
}

if ([string]::IsNullOrWhiteSpace($Message)) {
    Write-Host "Error: Commit message is required!" -ForegroundColor Red
    Write-Host "Use -Help to see usage information." -ForegroundColor Yellow
    return
}

$pushCommand = "git push"
$useUpstream = $false
$useOrigin = $false
$branch = ""

foreach ($arg in $Arguments) {
    switch ($arg) {
        "u" { $useUpstream = $true }
        "o" { $useOrigin = $true }
        default { $branch = $arg }
    }
}

Write-Host "Adding all files..." -ForegroundColor Cyan
git add .

Write-Host "Committing with message: '$Message'" -ForegroundColor Green
git commit -m "$Message"

if ($useUpstream) {
    $pushCommand += " -u"
}
if ($useOrigin) {
    $pushCommand += " origin"
}
if ($branch -ne "") {
    $pushCommand += " $branch"
}

Write-Host "Pushing with: $pushCommand" -ForegroundColor Yellow
Invoke-Expression $pushCommand