# Auto-generated script for: ask
# Original command: chater-ask
# Generated on: 2025-08-26 00:00:58

# Pass all arguments to the original command
if ($args.Count -gt 0) {
    $argumentString = $args -join ' '
    $fullCommand = "chater-ask $argumentString"
} else {
    $fullCommand = "chater-ask"
}

Invoke-Expression $fullCommand
