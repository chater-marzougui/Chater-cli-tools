# Auto-generated script for: testnet
# Original command: ping google.com
# Generated on: 2025-08-17 00:51:32

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArgs
)

# Original command with additional arguments support
$fullCommand = "ping google.com"
if ($AdditionalArgs) {
    $fullCommand += " " + ($AdditionalArgs -join " ")
}

Write-Host "Executing: $fullCommand" -ForegroundColor Cyan
Invoke-Expression $fullCommand
