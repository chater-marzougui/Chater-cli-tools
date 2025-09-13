param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Help function
function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "Environment Variable Manager" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Simple environment variable manager for the current directory."
    Write-Host "  Stores variables in a local .env file for project-specific configuration."
    Write-Host "  Perfect for managing API keys, paths, and other settings per project."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-env set <name> <value>    # Set or Update an environment variable" -ForegroundColor Green
    Write-Host "  chater-env get <name>            # Get an environment variable" -ForegroundColor Green
    Write-Host "  chater-env delete <name>         # Delete an environment variable" -ForegroundColor Green
    Write-Host "  chater-env list                  # List all stored variables" -ForegroundColor Green
    Write-Host "  chater-env create		           # Creates empty .env file" -ForegroundColor Green
    Write-Host "  chater-env -h                    # Show this help message" -ForegroundColor Green
    Write-Host "  chater-env help                  # Show this help message" -ForegroundColor Green
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-env set API_KEY `"your-secret-key-here`"" -ForegroundColor Green
    Write-Host "  chater-env get API_KEY" -ForegroundColor Green
    Write-Host "  chater-env list" -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTE:" -ForegroundColor Yellow
    Write-Host "  Add .env to your .gitignore to keep secrets safe!" -ForegroundColor Gray
    Write-Host ""
}

function Get-EnvFilePath {
    return Join-Path (Get-Location) ".env"
}

function Create_Env {
    $envFile = Get-EnvFilePath
    
    if (Test-Path $envFile) {
        Write-Host "❌ Error: .env file already exists" -ForegroundColor Red
        Write-Host "Location: $envFile" -ForegroundColor Gray
        return
    }
    
    New-Item -Path $envFile -ItemType File | Out-Null
    Write-Host "✅ Created .env file" -ForegroundColor Green
    Write-Host "Location: $envFile" -ForegroundColor Gray
}

function Create-EnvExample {
    $envFile = Get-EnvFilePath
    if (-not (Test-Path $envFile)) {
        Write-Host "❌ Error: No .env file found in current directory" -ForegroundColor Red
        return
    }

    $exampleFile = Join-Path (Get-Location) ".env.example"
    $envVars = Read-EnvFile

    $lines = @()
    $lines += "# Example environment file"
    $lines += "# Generated from .env on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += ""

    foreach ($key in ($envVars.Keys | Sort-Object)) {
        # Convert API_KEY -> "api key"
        $friendly = $key.ToLower() -replace "_", " "
        $placeholder = "your $friendly"

        $lines += "$key=`"$placeholder`""
    }

    $lines | Out-File -FilePath $exampleFile -Encoding UTF8
    Write-Host "✅ Created .env.example file" -ForegroundColor Green
    Write-Host "Location: $exampleFile" -ForegroundColor Gray
}

function Read-EnvFile {
    $envFile = Get-EnvFilePath
    $envVars = @{}
    
    if (Test-Path $envFile) {
        $content = Get-Content $envFile -ErrorAction SilentlyContinue
        foreach ($line in $content) {
            if ($line -and $line.Trim() -and -not $line.StartsWith("#")) {
                if ($line -match "^([^=]+)=(.*)$") {
                    $name = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    # Remove quotes if present
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or 
                        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }
                    $envVars[$name] = $value
                }
            }
        }
    }
    
    return $envVars
}

function Write-EnvFile {
    param([hashtable]$EnvVars)
    
    $envFile = Get-EnvFilePath
    $lines = @()
    
    # Read existing file to preserve comments and structure
    if (Test-Path $envFile) {
        $existingContent = Get-Content $envFile -ErrorAction SilentlyContinue
        $existingVarNames = @{}
        
        # First pass: identify existing variables
        foreach ($line in $existingContent) {
            if ($line -and $line.Trim() -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=") {
                $existingVarNames[$matches[1].Trim()] = $true
            }
        }
        
        # Second pass: preserve structure and update/keep variables
        foreach ($line in $existingContent) {
            if ($line.StartsWith("#") -or $line.Trim() -eq "") {
                # Keep comments and empty lines
                $lines += $line
            } elseif ($line -match "^([^=]+)=") {
                $varName = $matches[1].Trim()
                if ($EnvVars.ContainsKey($varName)) {
                    # Update existing variable
                    $value = $EnvVars[$varName]
                    if ($value -match '\s|[&|<>^]') {
                        $lines += "$varName=`"$value`""
                    } else {
                        $lines += "$varName=$value"
                    }
                    # Mark as processed
                    $EnvVars.Remove($varName)
                }
                # If variable not in EnvVars, it's being deleted (skip the line)
            } else {
                # Keep other lines as-is
                $lines += $line
            }
        }
        
        # Add any new variables that weren't in the original file
        if ($EnvVars.Count -gt 0) {
            if ($lines.Count -gt 0 -and $lines[-1].Trim() -ne "") {
                $lines += ""
            }
            $sortedKeys = $EnvVars.Keys | Sort-Object
            foreach ($key in $sortedKeys) {
                $value = $EnvVars[$key]
                if ($value -match '\s|[&|<>^]') {
                    $lines += "$key=`"$value`""
                } else {
                    $lines += "$key=$value"
                }
            }
        }
    } else {
        # File doesn't exist, create new with header
        $lines += "# Environment variables for $(Split-Path (Get-Location) -Leaf)"
        $lines += "# Generated by chater-env on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $lines += ""
        
        $sortedKeys = $EnvVars.Keys | Sort-Object
        foreach ($key in $sortedKeys) {
            $value = $EnvVars[$key]
            if ($value -match '\s|[&|<>^]') {
                $lines += "$key=`"$value`""
            } else {
                $lines += "$key=$value"
            }
        }
    }
    
    $lines | Out-File -FilePath $envFile -Encoding UTF8
}

function Set-EnvVariable {
    param(
        [string]$Name,
        [string]$Value
    )
    
    if (-not $Name) {
        Write-Host "❌ Error: Variable name is required" -ForegroundColor Red
        Write-Host "Usage: chater-env set <name> <value>" -ForegroundColor Yellow
        return
    }
    
    if (-not $Value) {
        Write-Host "❌ Error: Variable value is required" -ForegroundColor Red
        Write-Host "Usage: chater-env set <name> <value>" -ForegroundColor Yellow
        return
    }
    
    $envVars = Read-EnvFile
    $envVars[$Name] = $Value
    Write-EnvFile -EnvVars $envVars
    
    Write-Host "✅ Set $Name = $Value" -ForegroundColor Green
    
    $envFile = Get-EnvFilePath
    Write-Host "Stored in: $envFile" -ForegroundColor Gray
}

function Get-FuzzyMatches {
    param(
        [string]$SearchTerm,
        [array]$Candidates
    )
    
    return $Candidates | Where-Object { $_ -ilike "*$SearchTerm*" }
}

function Get-EnvVariable {
    param([string]$Name)
    
    if (-not $Name) {
        Write-Host "❌ Error: Variable name is required" -ForegroundColor Red
        Write-Host "Usage: chater-env get <name>" -ForegroundColor Yellow
        return
    }
    
    $envVars = Read-EnvFile

    # First, try exact match
    if ($envVars.ContainsKey($Name)) {
        Write-Host "$Name = $($envVars[$Name])" -ForegroundColor Green
        return
    }
    
    $matchedVars = Get-FuzzyMatches -SearchTerm $Name -Candidates $envVars.Keys
    
    if ($matchedVars.Count -eq 0) {
        Write-Host "❌ No similar variables found" -ForegroundColor Red
        Write-Host "Use 'chater-env list' to see all available variables" -ForegroundColor Yellow
        return
    }

    if ($matchedVars.Count -eq 1) {
        $match = if($matchedVars.GetType() -eq [string]) { $matchedVars } else { $matchedVars[0] }
        Write-Host "$match=$($envVars[$match])" -ForegroundColor Green
        "$match=$($envVars[$match])" | Set-Clipboard
        Write-Host "✅ Copied to clipboard" -ForegroundColor DarkGray
        return
    }
    
    foreach ($match in $matchedVars | Select-Object -First 5) {
        Write-Host "$match=$($envVars[$match])" -ForegroundColor Green
    }
    
    if ($matchedVars.Count -gt 5) {
        Write-Host "  ... and $($matchedVars.Count - 5) more matches" -ForegroundColor Gray
    }
}

function Remove-EnvVariable {
    param(
        [string]$Name,
        [switch]$Force
    )
    
    if (-not $Name) {
        Write-Host "❌ Error: Variable name is required" -ForegroundColor Red
        Write-Host "Usage: chater-env delete <name> [-Force]" -ForegroundColor Yellow
        return
    }
    
    $envVars = Read-EnvFile
    
    # Check if variable exists (exact match first)
    if ($envVars.ContainsKey($Name)) {
        $currentValue = $envVars[$Name] 
        if (-not $Force) {
            Write-Host "⚠️  About to delete: $Name = $currentValue" -ForegroundColor Yellow
            $confirmation = Read-Host "Are you sure? (y/N)"
            
            if ($confirmation -notmatch '^[Yy]([Ee][Ss])?$') {
                Write-Host "❌ Deletion cancelled" -ForegroundColor Red
                return
            }
        }
        
        $envVars.Remove($Name)
        Write-EnvFile -EnvVars $envVars
        Write-Host "✅ Deleted variable '$Name'" -ForegroundColor Green
        "$Name=$currentValue" | Set-Clipboard
        Write-Host "✅ Copied to clipboard if deleted by mistake" -ForegroundColor DarkGray
        return
    }

    Write-Host "❌ No variable found with name '$Name'" -ForegroundColor Red
}

function Show-EnvVariables {
    $envVars = Read-EnvFile
    $envFile = Get-EnvFilePath
    
    if ($envVars.Count -eq 0) {
        Write-Host "No environment variables found in current directory" -ForegroundColor Yellow
        Write-Host "Use 'chater-env set <name> <value>' to add variables" -ForegroundColor Gray
        return
    }
    
    Write-Host ""
    Write-Host "Environment Variables ($($envVars.Count))" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Location: $envFile" -ForegroundColor Gray
    Write-Host ""
    
    # Find the longest key name for alignment
    $maxKeyLength = ($envVars.Keys | Measure-Object -Property Length -Maximum).Maximum
    
    $sortedKeys = $envVars.Keys | Sort-Object
    foreach ($key in $sortedKeys) {
        $paddedKey = $key.PadRight($maxKeyLength)
        $value = $envVars[$key]
        
        # Truncate long values
        if ($value.Length -gt 50) {
            $value = $value.Substring(0, 47) + "..."
        }
        
        Write-Host "  $paddedKey = " -NoNewline -ForegroundColor Yellow
        Write-Host "$value" -ForegroundColor White
    }
    Write-Host ""
}


$helpArgs = @("-h", "--h", "help", "-Help")
# Check for help
if ($Arguments.Count -eq 0 -or ($Arguments.Count -le 2 -and ($helpArgs -contains $Arguments[0]))) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Parse command
$command = $Arguments[0].ToLower()

try {
    switch ($command) {
        "set" {
            if ($Arguments.Count -lt 3) {
                Write-Host "❌ Error: Missing arguments" -ForegroundColor Red
                Write-Host "Usage: chater-env set <name> <value>" -ForegroundColor Yellow
                return
            }
            $name = $Arguments[1]
            $value = ($Arguments[2..($Arguments.Count-1)]) -join " "
            Set-EnvVariable -Name $name -Value $value
        }
        
        "get" {
            if ($Arguments.Count -lt 2) {
                Write-Host "❌ Error: Missing variable name" -ForegroundColor Red
                Write-Host "Usage: chater-env get <name>" -ForegroundColor Yellow
                return
            }
            Get-EnvVariable -Name $Arguments[1]
        }
        
        "list" {
            Show-EnvVariables
        }

        {$_ -match "^(delete|remove)$"} {
            if ($Arguments.Count -lt 2) {
                Write-Host "❌ Error: Missing variable name" -ForegroundColor Red
                Write-Host "Usage: chater-env delete <name>" -ForegroundColor Yellow
                return
            }
            $forceArgs = @("-force", "--force", "-f", "--f")
            $force = $forceArgs -contains $Arguments[-1]
            Remove-EnvVariable -Name $Arguments[1] -Force:$force
        }

        "create" {
            if ($Arguments.Count -eq 1) {
                Create_Env
            }
            elseif ($Arguments.Count -ge 2 -and ($Arguments[1] -in @("example","-e","--e"))) {
                Create-EnvExample
            }
            else {
                Write-Host "❌ Error: Unknown option for create: $($Arguments[1])" -ForegroundColor Red
                Write-Host "Usage: chater-env create [example|-e|--e]" -ForegroundColor Yellow
            }
        }

            
        default {
            Write-Host "❌ Error: Unknown command '$command'" -ForegroundColor Red
            Write-Host "Available commands: set, get, list" -ForegroundColor Yellow
            Write-Host "Use 'chater-env help' for more information" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}