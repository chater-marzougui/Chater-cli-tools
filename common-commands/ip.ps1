# Auto-generated script for: ip
# Original command: chater-ip
# Generated on: 2025-08-26 00:00:58

# Pass all arguments to the original command
if ($args.Count -gt 0) {
    $argumentString = $args -join ' '
    $fullCommand = "chater-ip $argumentString"
} else {
    $fullCommand = "chater-ip"
}

Invoke-Expression $fullCommand
