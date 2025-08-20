param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)



$envFilePath = Join-Path $PSScriptRoot ".env"
$scriptDir = (Get-Content $envFilePath | Where-Object { $_ -match "^MainScriptsPath=" }) -replace "MainScriptsPath=", ""
if (-Not $scriptDir) { $scriptDir = "C:\custom-scripts" } else { $scriptDir = $scriptDir.Trim().Trim('"').Trim("'") }
$secretsFilePath = Join-Path $scriptDir "helpers\.secrets"

# Help function
function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "🔐 Secret & API Key Manager" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Secure manager for API keys, tokens, and sensitive data."
    Write-Host "  Stores encrypted secrets in a local .secrets file for general use across system."
    Write-Host "  Perfect for managing API keys, database passwords, and other sensitive configuration."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-secrets set <name> <value>       # Set a secret" -ForegroundColor Green
    Write-Host "  chater-secrets get <name>               # Get a secret value" -ForegroundColor Green
    Write-Host "  chater-secrets list                     # List all secret names" -ForegroundColor Green
    Write-Host "  chater-secrets delete <name>            # Delete a specific secret" -ForegroundColor Green
    Write-Host "  chater-secrets clear                    # Clear all secrets" -ForegroundColor Green
    Write-Host "  chater-secrets export                   # Export secrets to .env format" -ForegroundColor Green
    Write-Host "  chater-secrets import                   # Import from .env file" -ForegroundColor Green
    Write-Host "  chater-secrets -h                       # Show this help message" -ForegroundColor Green
    Write-Host "  chater-secrets help                     # Show this help message" -ForegroundColor Green
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-secrets set OPENAI_API_KEY `"sk-1234567890abcdef`"" -ForegroundColor Green
    Write-Host "  chater-secrets set DB_PASSWORD `"my-secure-password`"" -ForegroundColor Green
    Write-Host "  chater-secrets get OPENAI_API_KEY" -ForegroundColor Green
    Write-Host "  chater-secrets list" -ForegroundColor Green
    Write-Host "  chater-secrets delete DB_PASSWORD" -ForegroundColor Green
    Write-Host "  chater-secrets export" -ForegroundColor Green
    Write-Host ""
    Write-Host "SECURITY FEATURES:" -ForegroundColor Yellow
    Write-Host "  🔒 Encrypted storage using Windows DPAPI" -ForegroundColor Gray
    Write-Host "  🚫 Values never displayed in plaintext during list" -ForegroundColor Gray
    Write-Host "  📁 Separate .secrets file (add to .gitignore)" -ForegroundColor Gray
    Write-Host "  🔐 User-specific encryption (only you can decrypt)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTE:" -ForegroundColor Yellow
    Write-Host "  Add .secrets to your .gitignore to keep secrets safe!" -ForegroundColor Red
    Write-Host ""
}

Add-Type -AssemblyName System.Security

function Protect-String {
    param([string]$PlainText)
    
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
        $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [Convert]::ToBase64String($encryptedBytes)
    }
    catch {
        Write-Host "❌ Error encrypting data: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Unprotect-String {
    param([string]$EncryptedText)
    
    try {
        $encryptedBytes = [Convert]::FromBase64String($EncryptedText)
        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
    }
    catch {
        Write-Host "❌ Error decrypting data: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Read-SecretsFile {
    $secretsFile = $secretsFilePath
    $secrets = @{}
    
    if (Test-Path $secretsFile) {
        try {
            $content = Get-Content $secretsFile -ErrorAction SilentlyContinue
            foreach ($line in $content) {
                if ($line -and $line.Trim() -and -not $line.StartsWith("#")) {
                    if ($line -match "^([^=]+)=(.*)$") {
                        $name = $matches[1].Trim()
                        $encryptedValue = $matches[2].Trim()
                        $secrets[$name] = $encryptedValue
                    }
                }
            }
        }
        catch {
            Write-Host "❌ Error reading secrets file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $secrets
}

function Write-SecretsFile {
    param([hashtable]$Secrets)
    
    $secretsFile = $secretsFilePath
    $lines = @()
    
    # Add header comment
    $lines += "# Encrypted secrets for $(Split-Path (Get-Location) -Leaf)"
    $lines += "# Generated by chater-secrets on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "# WARNING: This file contains encrypted data - do not edit manually!"
    $lines += ""
    
    # Sort secrets alphabetically and write them
    $sortedKeys = $Secrets.Keys | Sort-Object
    foreach ($key in $sortedKeys) {
        $encryptedValue = $Secrets[$key]
        $lines += "$key=$encryptedValue"
    }
    
    try {
        $lines | Out-File -FilePath $secretsFile -Encoding UTF8
    }
    catch {
        Write-Host "❌ Error writing secrets file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-Secret {
    param(
        [string]$Name,
        [string]$Value
    )
    
    if (-not $Name) {
        Write-Host "❌ Error: Secret name is required" -ForegroundColor Red
        Write-Host "Usage: chater-secrets set <name> <value>" -ForegroundColor Yellow
        return
    }
    
    if (-not $Value) {
        Write-Host "❌ Error: Secret value is required" -ForegroundColor Red
        Write-Host "Usage: chater-secrets set <name> <value>" -ForegroundColor Yellow
        return
    }
    
    $encryptedValue = Protect-String -PlainText $Value
    if (-not $encryptedValue) {
        return
    }
    
    $secrets = Read-SecretsFile
    $isUpdate = $secrets.ContainsKey($Name)
    $secrets[$Name] = $encryptedValue
    Write-SecretsFile -Secrets $secrets
    
    if ($isUpdate) {
        Write-Host "✅ Updated secret: $Name" -ForegroundColor Green
    } else {
        Write-Host "✅ Added secret: $Name" -ForegroundColor Green
    }
    
    $secretsFile = $secretsFilePath
    Write-Host "Stored in: $secretsFile" -ForegroundColor Gray
}

function Get-Secret {
   param([string]$Name)
   
   if (-not $Name) {
       Write-Host "❌ Error: Secret name is required" -ForegroundColor Red
       Write-Host "Usage: chater-secret get <n>" -ForegroundColor Yellow
       return
   }
   
   $secrets = Read-SecretsFile
   
   # Exact match first
   if ($secrets.ContainsKey($Name)) {
       $encryptedValue = $secrets[$Name]
       $decryptedValue = Unprotect-String -EncryptedText $encryptedValue
       
       if ($decryptedValue) {
           Write-Host "$Name = $decryptedValue" -ForegroundColor Green
       }
       return
   }
   
   # Fuzzy search - case insensitive partial matching
   $fuzzyMatches = @()
   $searchPattern = $Name.ToLower()
   
   foreach ($secretName in $secrets.Keys) {
       if ($secretName.ToLower().Contains($searchPattern)) {
           $fuzzyMatches += $secretName
       }
   }
   
   if ($fuzzyMatches.Count -eq 0) {
       Write-Host "❌ Secret '$Name' not found" -ForegroundColor Red
       Write-Host "Use 'chater-secret list' to see available secrets" -ForegroundColor Yellow
       return
   }
   
   if ($fuzzyMatches.Count -eq 1) {
       # Single match found
       $matchedName = $fuzzyMatches[0]
       $encryptedValue = $secrets[$matchedName]
       $decryptedValue = Unprotect-String -EncryptedText $encryptedValue

       if ($decryptedValue) {
           Write-Host "🎯 Found match: " -NoNewline -ForegroundColor Yellow
           Write-Host "$matchedName = $decryptedValue" -ForegroundColor Green
       }
       return
   }
   
   # Multiple matches - show selection menu
   Write-Host "🔍 Multiple matches found for '$Name':" -ForegroundColor Yellow
   Write-Host ""
   
   for ($i = 0; $i -lt $fuzzyMatches.Count; $i++) {
       Write-Host "  [$($i + 1)] " -NoNewline -ForegroundColor Cyan
       Write-Host "$($fuzzyMatches[$i])" -ForegroundColor White
   }
   
   Write-Host ""
   Write-Host "Select a secret (1-$($fuzzyMatches.Count)) or press Enter to cancel: " -NoNewline -ForegroundColor Yellow
   
   $selection = Read-Host
   
   # Handle empty input (cancel)
   if ([string]::IsNullOrWhiteSpace($selection)) {
       Write-Host "❌ Selection cancelled" -ForegroundColor Yellow
       return
   }
   
   # Validate and process selection
   try {
       $index = [int]$selection - 1
       
       if ($index -ge 0 -and $index -lt $fuzzyMatches.Count) {
           $selectedName = $fuzzyMatches[$index]
           $encryptedValue = $secrets[$selectedName]
           $decryptedValue = Unprotect-String -EncryptedText $encryptedValue

           if ($decryptedValue) {
               Write-Host ""
               Write-Host "$selectedName = $decryptedValue" -ForegroundColor Green
           }
       } else {
           Write-Host "❌ Invalid selection. Please choose a number between 1 and $($matches.Count)" -ForegroundColor Red
       }
   }
   catch {
       Write-Host "❌ Invalid input. Please enter a number between 1 and $($matches.Count)" -ForegroundColor Red
   }
}

function Show-Secrets {
    $secrets = Read-SecretsFile
    $secretsFile = $secretsFilePath
    
    if ($secrets.Count -eq 0) {
        Write-Host "No secrets found in current directory" -ForegroundColor Yellow
        Write-Host "Use 'chater-secrets set <name> <value>' to add secrets" -ForegroundColor Gray
        return
    }
    
    Write-Host ""
    Write-Host "🔐 Stored Secrets ($($secrets.Count))" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    Write-Host "Location: $secretsFile" -ForegroundColor Gray
    Write-Host ""
    
    # Group secrets by common patterns
    $apiKeys = @()
    $tokens = @()
    $passwords = @()
    $others = @()
    
    $sortedKeys = $secrets.Keys | Sort-Object
    foreach ($key in $sortedKeys) {
        if ($key -match "API_KEY|APIKEY") {
            $apiKeys += $key
        }
        elseif ($key -match "TOKEN|SECRET") {
            $tokens += $key
        }
        elseif ($key -match "PASSWORD|PASS|PWD") {
            $passwords += $key
        }
        else {
            $others += $key
        }
    }
    
    # Display grouped secrets
    if ($apiKeys.Count -gt 0) {
        Write-Host "  🔑 API Keys:" -ForegroundColor Yellow
        foreach ($key in $apiKeys) {
            Write-Host "     $key" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($tokens.Count -gt 0) {
        Write-Host "  🎫 Tokens & Secrets:" -ForegroundColor Yellow
        foreach ($key in $tokens) {
            Write-Host "     $key" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($passwords.Count -gt 0) {
        Write-Host "  🔒 Passwords:" -ForegroundColor Yellow
        foreach ($key in $passwords) {
            Write-Host "     $key" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($others.Count -gt 0) {
        Write-Host "  📋 Other Secrets:" -ForegroundColor Yellow
        foreach ($key in $others) {
            Write-Host "     $key" -ForegroundColor White
        }
        Write-Host ""
    }
    
    Write-Host "Use 'chater-secrets get <name>' to retrieve a secret value" -ForegroundColor Gray
}

function Remove-Secret {
    param([string]$Name)
    
    if (-not $Name) {
        Write-Host "❌ Error: Secret name is required" -ForegroundColor Red
        Write-Host "Usage: chater-secrets delete <name>" -ForegroundColor Yellow
        return
    }
    
    $secrets = Read-SecretsFile
    
    if ($secrets.ContainsKey($Name)) {
        $secrets.Remove($Name)
        Write-SecretsFile -Secrets $secrets
        Write-Host "✅ Deleted secret: $Name" -ForegroundColor Green
    } else {
        Write-Host "❌ Secret '$Name' not found" -ForegroundColor Red
        Write-Host "Use 'chater-secrets list' to see available secrets" -ForegroundColor Yellow
    }
}

function Clear-Secrets {
    $secretsFile = $secretsFilePath
    
    if (-not (Test-Path $secretsFile)) {
        Write-Host "No secrets file found" -ForegroundColor Yellow
        return
    }
    
    $secrets = Read-SecretsFile
    if ($secrets.Count -eq 0) {
        Write-Host "No secrets to clear" -ForegroundColor Yellow
        return
    }
    
    Write-Host "⚠️  This will delete ALL $($secrets.Count) secrets permanently!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'yes' to confirm"
    
    if ($confirmation -eq "yes") {
        Remove-Item $secretsFile -Force
        Write-Host "✅ All secrets cleared" -ForegroundColor Green
    } else {
        Write-Host "❌ Operation cancelled" -ForegroundColor Yellow
    }
}

function Export-Secrets {
    $secrets = Read-SecretsFile
    
    if ($secrets.Count -eq 0) {
        Write-Host "No secrets to export" -ForegroundColor Yellow
        return
    }
    
    $envFile = Join-Path (Get-Location) ".env"
    $lines = @()
    
    # Add header
    $lines += "# Exported secrets from chater-secrets"
    $lines += "# Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += ""
    
    # Decrypt and export each secret
    $sortedKeys = $secrets.Keys | Sort-Object
    foreach ($key in $sortedKeys) {
        $encryptedValue = $secrets[$key]
        $decryptedValue = Unprotect-String -EncryptedText $encryptedValue
        
        if ($decryptedValue) {
            # Quote values that contain spaces or special characters
            if ($decryptedValue -match '\s|[&|<>^]') {
                $lines += "$key=`"$decryptedValue`""
            } else {
                $lines += "$key=$decryptedValue"
            }
        }
    }
    
    try {
        $lines | Out-File -FilePath $envFile -Encoding UTF8
        Write-Host "✅ Exported $($secrets.Count) secrets to .env file" -ForegroundColor Green
        Write-Host "Location: $envFile" -ForegroundColor Gray
        Write-Host ""
        Write-Host "⚠️  WARNING: .env file contains plaintext secrets!" -ForegroundColor Red
        Write-Host "   Make sure it's in your .gitignore file" -ForegroundColor Red
    }
    catch {
        Write-Host "❌ Error exporting secrets: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Import-Secrets {
    $envFile = Join-Path (Get-Location) ".env"
    
    if (-not (Test-Path $envFile)) {
        Write-Host "❌ No .env file found in current directory" -ForegroundColor Red
        Write-Host "Location expected: $envFile" -ForegroundColor Gray
        return
    }
    
    try {
        $content = Get-Content $envFile
        $importCount = 0
        $secrets = Read-SecretsFile
        
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
                    
                    # Encrypt and store
                    $encryptedValue = Protect-String -PlainText $value
                    if ($encryptedValue) {
                        $secrets[$name] = $encryptedValue
                        $importCount++
                    }
                }
            }
        }
        
        if ($importCount -gt 0) {
            Write-SecretsFile -Secrets $secrets
            Write-Host "✅ Imported $importCount secrets from .env file" -ForegroundColor Green
            
            Write-Host ""
            Write-Host "🔒 SECURITY RECOMMENDATION:" -ForegroundColor Yellow
            Write-Host "   Consider deleting the .env file now that secrets are encrypted:" -ForegroundColor Gray
            Write-Host "   Remove-Item .env" -ForegroundColor Cyan
        } else {
            Write-Host "❌ No valid environment variables found in .env file" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error importing from .env: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main script execution
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
                Write-Host "Usage: chater-secrets set <name> <value>" -ForegroundColor Yellow
                return
            }
            $name = $Arguments[1]
            $value = ($Arguments[2..($Arguments.Count-1)]) -join " "
            Set-Secret -Name $name -Value $value
        }
        
        "get" {
            if ($Arguments.Count -lt 2) {
                Write-Host "❌ Error: Missing secret name" -ForegroundColor Red
                Write-Host "Usage: chater-secrets get <name>" -ForegroundColor Yellow
                return
            }
            Get-Secret -Name $Arguments[1]
        }
        
        "list" {
            Show-Secrets
        }
        
        "delete" {
            if ($Arguments.Count -lt 2) {
                Write-Host "❌ Error: Missing secret name" -ForegroundColor Red
                Write-Host "Usage: chater-secrets delete <name>" -ForegroundColor Yellow
                return
            }
            Remove-Secret -Name $Arguments[1]
        }
        
        "clear" {
            Clear-Secrets
        }
        
        "export" {
            Export-Secrets
        }
        
        "import" {
            Import-Secrets
        }
        
        default {
            Write-Host "❌ Error: Unknown command '$command'" -ForegroundColor Red
            Write-Host "Available commands: set, get, list, delete, clear, export, import" -ForegroundColor Yellow
            Write-Host "Use 'chater-secrets help' for more information" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}