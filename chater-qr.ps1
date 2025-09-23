param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Configuration
$SavedTextsFile = Join-Path $PSScriptRoot "helpers\qr-saved-texts.json"

# Ensure saved texts file exists
if (-not (Test-Path $SavedTextsFile)) {
    $parentDir = Split-Path $SavedTextsFile -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    @{} | ConvertTo-Json | Out-File -FilePath $SavedTextsFile -Encoding UTF8
    Write-Host "📄 Created new saved texts file: $SavedTextsFile" -ForegroundColor Green
}

# Help function
function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "📱 QR Code Generator" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Generate QR codes for any text, URLs, or saved aliases."
    Write-Host "  Save frequently used text with aliases for quick access."
    Write-Host "  Opens QR codes in your default browser for easy scanning."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-qr `"your text here`"" -ForegroundColor Green
    Write-Host "  chater-qr your text without quotes" -ForegroundColor Green
    Write-Host "  chater-qr `"text`" -s alias                # Save text with alias" -ForegroundColor Green
    Write-Host "  chater-qr `"text`" --save alias            # Save text with alias" -ForegroundColor Green
    Write-Host "  chater-qr alias                           # Generate QR from saved alias" -ForegroundColor Green
    Write-Host "  chater-qr --list                          # List all saved aliases" -ForegroundColor Green
    Write-Host "  chater-qr --remove alias                  # Remove saved alias" -ForegroundColor Green
    Write-Host "  chater-qr help                            # Show this help message" -ForegroundColor Green
    Write-Host "  chater-qr -h                              # Show this help message" -ForegroundColor Green
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-qr `"https://github.com/myrepo`"" -ForegroundColor Green
    Write-Host "  chater-qr `"My WiFi Password: 12345`" -s wifi" -ForegroundColor Green
    Write-Host "  chater-qr wifi                            # Use saved wifi alias" -ForegroundColor Green
    Write-Host "  chater-qr `"Contact: John Doe +1234567890`"" -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTE:" -ForegroundColor Yellow
    Write-Host "  Uses qr-server.com API to generate QR codes. Requires internet connection." -ForegroundColor Gray
    Write-Host ""
}

function Get-SavedTexts {
    if (Test-Path $SavedTextsFile) {
        $content = Get-Content -Path $SavedTextsFile -Raw
        if ($content) {
            return $content | ConvertFrom-Json
        }
    }
    return @{}
}

function Save-Text {
    param(
        [string]$Alias,
        [string]$Text
    )
    
    $savedTexts = Get-SavedTexts
    $savedTexts.$Alias = $Text
    
    $savedTexts | ConvertTo-Json | Out-File -FilePath $SavedTextsFile -Encoding UTF8
    Write-Host "💾 Saved '$Text' as alias '$Alias'" -ForegroundColor Green
}

function Remove-SavedText {
    param(
        [string]$Alias
    )
    
    $savedTexts = Get-SavedTexts
    if ($savedTexts.$Alias) {
        $savedTexts.PSObject.Properties.Remove($Alias)
        $savedTexts | ConvertTo-Json | Out-File -FilePath $SavedTextsFile -Encoding UTF8
        Write-Host "🗑️ Removed alias '$Alias'" -ForegroundColor Green
    } else {
        Write-Host "❌ Alias '$Alias' not found" -ForegroundColor Red
    }
}

function Show-SavedTexts {
    $savedTexts = Get-SavedTexts
    if ($savedTexts.PSObject.Properties.Count -eq 0) {
        Write-Host "📝 No saved aliases found" -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "💾 Saved Aliases:" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($property in $savedTexts.PSObject.Properties) {
        $preview = if ($property.Value.Length -gt 50) { 
            $property.Value.Substring(0, 50) + "..." 
        } else { 
            $property.Value 
        }
        Write-Host "  📎 $($property.Name) → $preview" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Total aliases: $($savedTexts.PSObject.Properties.Count)" -ForegroundColor Gray
    Write-Host ""
}

function New-QRCodeWeb {
    param(
        [string]$Text
    )
    
    # URL encode the text
    $encodedText = [System.Web.HttpUtility]::UrlEncode($Text)
    # Generate QR code URL using qr-server.com
    $qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=400x400&margin=20&data=$encodedText"
    try {
        Start-Process $qrUrl
    }
    catch {
        Write-Host "❌ Error opening QR code: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "🔗 Manual link: $qrUrl" -ForegroundColor Yellow
    }
}

function New-QRCode {
    param (
        [string]$Text
    )

    # Attempt to use qrencode if available
    # Install-Module -Name QrCodes -Scope CurrentUser
    # ConvertTo-QRCode "https://example.com"
    
    try {
        if (Get-Command "ConvertTo-QRCode" -ErrorAction SilentlyContinue) {
            ConvertTo-QRCode -InputObject $Text | Format-QRCode -TopPadding 1 -SidePadding 2
        } else {
            Write-Host "⚠️ 'ConvertTo-QRCode' command not found. Falling back to web-based QR code generation." -ForegroundColor Yellow
            Write-Host "💡 To enable terminal QR codes, install the 'QrCodes' module via:" -ForegroundColor Gray
            Write-Host "   Install-Module -Name QrCodes -Scope CurrentUser" -ForegroundColor Gray
            New-QRCodeWeb -Text $Text
        }
    }
    catch {
        Write-Host "❌ Error generating QR code: $($_.Exception.Message)" -ForegroundColor Red
        New-QRCode-Fallback -Text $Text
    }
}

# Check for help
$helpArgs = @("-h", "--h", "help", "-Help")
if ($Arguments.Count -eq 0 -or ($Arguments.Count -le 2 -and $helpArgs -contains $Arguments[0])) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Load System.Web for URL encoding
Add-Type -AssemblyName System.Web

# Parse arguments
$textParts = @()
$saveFlag = $false
$saveAlias = $null
$listFlag = $false
$removeFlag = $false
$nextArgIsAlias = $false
$nextArgIsRemove = $false
$useWebVersion = $false

$saveArgs = @("-s", "--s", "-save", "--save")
$listArgs = @("-l", "--l", "-list", "--list")
$removeArgs = @("-rm", "--rm", "-remove", "--remove")
$webArgs = @("--web", '-web', '-w')
foreach ($arg in $Arguments) {
    if ($nextArgIsAlias) {
        $saveAlias = $arg
        $nextArgIsAlias = $false
        continue
    } elseif ($nextArgIsRemove) {
        Remove-SavedText -Alias $arg
        return
    } elseif ($listArgs -contains $arg) {
        $listFlag = $true
    } elseif ($removeArgs -contains $arg) {
        $removeFlag = $true
        $nextArgIsRemove = $true
    } elseif ($saveArgs -contains $arg) {
        $saveFlag = $true
        $nextArgIsAlias = $true
    } elseif ($webArgs -contains $arg) {
        $useWebVersion = $true
    } else {
        $textParts += $arg
    }
}

# Handle list flag
if ($listFlag) {
    Show-SavedTexts
    return
}

# Handle remove flag without alias
if ($removeFlag -and -not $nextArgIsRemove) {
    Write-Host "❌ Error: Please specify an alias to remove" -ForegroundColor Red
    Write-Host "Usage: chater-qr --remove <alias>" -ForegroundColor Yellow
    return
}

$inputText = $textParts -join " "

# Validate input
if ($inputText.Length -eq 0) {
    Write-Host ""
    Write-Host "❌ Error: Please provide text to generate QR code" -ForegroundColor Red
    Write-Host "Usage: chater-qr `"your text here`"" -ForegroundColor Yellow
    Write-Host ""
    return
}

# Check if input is a saved alias
$savedTexts = Get-SavedTexts
if ($savedTexts.$inputText -and -not $saveFlag) {
    Write-Host "📎 Using saved alias '$inputText'" -ForegroundColor Cyan
    $actualText = $savedTexts.$inputText
    New-QRCode -Text $actualText
    return
}

# Save text if save flag is provided
if ($saveFlag) {
    if (-not $saveAlias) {
        Write-Host "❌ Error: Please provide an alias to save the text" -ForegroundColor Red
        Write-Host "Usage: chater-qr `"your text`" -s <alias>" -ForegroundColor Yellow
        return
    }
    Save-Text -Alias $saveAlias -Text $inputText
}

# Generate QR code
if ($useWebVersion) {
    New-QRCodeWeb -Text $inputText
} else {
    New-QRCode -Text $inputText
}
