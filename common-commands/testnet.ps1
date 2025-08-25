# Auto-generated script for: testnet
# Original command: ping google.com
# Generated on: 2025-08-26 00:00:59

# Pass all arguments to the original command
if ($args.Count -gt 0) {
    $argumentString = $args -join ' '
    $fullCommand = "ping google.com $argumentString"
} else {
    $fullCommand = "ping google.com"
}

Invoke-Expression $fullCommand
