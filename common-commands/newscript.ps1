# Auto-generated script for: newscript
# Original command: chater-adapt | chater-bom
# Generated on: 2025-08-26 00:00:59

# Pass all arguments to the original command
if ($args.Count -gt 0) {
    $argumentString = $args -join ' '
    $fullCommand = "chater-adapt | chater-bom $argumentString"
} else {
    $fullCommand = "chater-adapt | chater-bom"
}

Invoke-Expression $fullCommand
