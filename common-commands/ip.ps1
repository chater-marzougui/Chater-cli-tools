# Auto-generated script for: ip
# Original command: chater-ip
# Generated on: 2025-08-17 10:53:43

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$XtraArgs
)

# Original command with additional arguments support
$fullCommand = "chater-ip"
if ($XtraArgs) {
    Write-Host "Adding additional arguments: $($XtraArgs -join ', ')" -ForegroundColor Yellow
    $fullCommand += " " + ($XtraArgs -join " ")
}

Write-Host "Executing: $fullCommand" -ForegroundColor Cyan
Invoke-Expression $fullCommand
