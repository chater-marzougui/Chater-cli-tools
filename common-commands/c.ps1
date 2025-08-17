# Auto-generated script for: c
# Original command: cls
# Generated on: 2025-08-17 00:44:13

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArgs
)

# Original command with additional arguments support
$fullCommand = "cls"
if ($AdditionalArgs) {
    $fullCommand += " " + ($AdditionalArgs -join " ")
}

Write-Host "Executing: $fullCommand" -ForegroundColor Cyan
Invoke-Expression $fullCommand
