# Auto-generated script for: newscript
# Original command: chater-adapt | chater-orm
# Generated on: 2025-08-17 06:11:14

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArgs
)

# Original command with additional arguments support
$fullCommand = "chater-adapt | chater-orm"
if ($AdditionalArgs) {
    $fullCommand += " " + ($AdditionalArgs -join " ")
}

Write-Host "Executing: $fullCommand" -ForegroundColor Cyan
Invoke-Expression $fullCommand
