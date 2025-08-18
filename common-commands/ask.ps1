# Auto-generated script for: ask
# Original command: chater-ask
# Generated on: 2025-08-17 23:59:08

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$XtraArgs
)

# Original command with additional arguments support
$fullCommand = "chater-ask"
if ($XtraArgs) {
    $fullCommand += " " + ($XtraArgs -join " ")
}

Write-Host "Executing: $fullCommand" -ForegroundColor Cyan
Invoke-Expression $fullCommand
