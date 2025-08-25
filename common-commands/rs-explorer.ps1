# Auto-generated script for: rs-explorer
# Original command: taskkill /IM explorer.exe /F && start explorer.exe
# Generated on: 2025-08-26 00:00:59

# Execute CMD command with arguments
if ($args.Count -gt 0) {
    $argumentString = $args -join ' '
    $fullCommand = "taskkill /IM explorer.exe /F && start explorer.exe $argumentString"
} else {
    $fullCommand = "taskkill /IM explorer.exe /F && start explorer.exe"
}

# Use cmd.exe to execute commands with CMD operators
cmd.exe /c "$fullCommand"
