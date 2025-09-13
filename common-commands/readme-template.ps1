# Auto-generated script for: readme-template
# Original command: cp C:\custom-scripts\helpers\readme.md .
# Generated on: 2025-09-07 08:42:33

# Pass all arguments to the original command
if ($args.Count -gt 0) {
    $argumentString = $args -join ' '
    $fullCommand = "cp C:\custom-scripts\helpers\readme.md . $argumentString"
} else {
    $fullCommand = "cp C:\custom-scripts\helpers\readme.md ."
}

Invoke-Expression $fullCommand
