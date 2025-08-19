param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)
$StartTime = Get-Date
$modelName = "gemini-2.5-flash-lite"

# Configuration
$ConversationHistoryFile = Join-Path $PSScriptRoot "helpers\conv-history.txt"

# Ensure conversation history file exists
if (-not (Test-Path $ConversationHistoryFile)) {
    $parentDir = Split-Path $ConversationHistoryFile -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    New-Item -Path $ConversationHistoryFile -ItemType File -Force | Out-Null
    Write-Host "Created new conversation history file: $ConversationHistoryFile" -ForegroundColor Green
}

# Help function
function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "AI Assistant - Gemini Chat Interface" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Quick command-line interface to ask questions to Google's Gemini AI."
    Write-Host "  Perfect for getting instant answers, code help, explanations, and more."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-ask `"your question here`"" -ForegroundColor Green
    Write-Host "  chater-ask your question without quotes" -ForegroundColor Green
    Write-Host "  chater-ask `"your question`" --p         # Use gemini-2.5-pro model" -ForegroundColor Green
    Write-Host "  chater-ask `"your question`" --f         # Use gemini-2.5-flash model" -ForegroundColor Green
    Write-Host "  chater-ask `"your question`" --m <name>  # Use another model" -ForegroundColor Green
    Write-Host "  chater-ask --clear                       # Clear conversation history" -ForegroundColor Green
    Write-Host "  chater-ask help                        # Show this help message" -ForegroundColor Green
    Write-Host "  chater-ask -h                          # Show this help message" -ForegroundColor Green
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-ask `"What is the difference between PowerShell and CMD?`"" -ForegroundColor Green
    Write-Host "  chater-ask what are the best practices for API design" -ForegroundColor Green
    Write-Host "  chater-ask `"Explain quantum computing`" --p" -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTE:" -ForegroundColor Yellow
    Write-Host "  Requires GEMINI_API_KEY environment variable to be set with your Gemini API key." -ForegroundColor Gray
    Write-Host ""
}


function Add-ContentToHistory {
    param(
        [bool]$isUser = $true,  # Fixed parameter type
        [string]$Content
    )

    # Read existing lines as array
    $existingContent = if (Test-Path $ConversationHistoryFile) { 
        @(Get-Content $ConversationHistoryFile) 
    } else { 
        @() 
    }
    
    # Add new content
    if ($isUser) {
        $existingContent += "User: $Content"
    } else {
        $existingContent += "AI-Model: $Content`n"
    }

    # Write with proper line endings
    $existingContent | Out-File -FilePath $ConversationHistoryFile -Encoding UTF8
}

function Get-ConversationHistory {
    if (Test-Path $ConversationHistoryFile) {
        $content = Get-Content -Path $ConversationHistoryFile
        return $content
    } else {
        return @()
    }
}

function Clear-ConversationHistory {
    if (Test-Path $ConversationHistoryFile) {
        Clear-Content -Path $ConversationHistoryFile
        Write-Host "Conversation history cleared." -ForegroundColor Green
    }
}

function Invoke-GeminiAPI {
    param(
        [string]$Question,
        [string]$ModelName,
        [string]$ApiKey
    )

    $convHistory = Get-ConversationHistory
    $convHistoryText = if ($convHistory) { "Conversation History:`n$($convHistory -join "`n")" } else { "" }

    # Enhanced prompt for better responses
    $enhancedPrompt = @"
Please provide a helpful, accurate, and concise response to the following question. 
If it's a technical question, include practical examples when appropriate.
If it's a coding question, provide clear code examples with explanations.
This will be used in a CLI environment so adapt your response with: 
 - No large code snippets.
 - Use "-" for bullet points.
 - add spaces before and after bullet points.
 - make the response concise and as direct and short as possible.

return only the main response text.
if question is too ambiguous, ask for clarification or more context.
Also the user is a developer, so no serious tone, short answers, provide good response with playful tone, include icons or emojis.
Question: $Question

$convHistoryText
"@

    # Create the request body
    $requestBody = @{
        contents = @(
            @{
                parts = @(
                    @{
                        text = $enhancedPrompt
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10

    # API endpoint
    $apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/${ModelName}:generateContent"
    
    # Headers
    $headers = @{
        "x-goog-api-key" = $ApiKey
        "Content-Type" = "application/json"
    }
    
    try {
        # Make the API call
        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $requestBody -TimeoutSec 30
        
        # Extract the text response
        if ($response.candidates -and $response.candidates[0].content.parts -and $response.candidates[0].content.parts[0].text) {
            # Add user question to conversation history
            Add-ContentToHistory -Content $Question -isUser $true
            $responseText = $response.candidates[0].content.parts[0].text
            Add-ContentToHistory -Content $responseText -isUser $false
            return $responseText
        } else {
            throw "Empty or invalid response from Gemini API"
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        $statusCode = $_.Exception.Response.StatusCode.value__ -as [int]
        
        switch ($statusCode) {
            400 { throw "Bad request - Check your prompt format" }
            401 { throw "Invalid API key - Check your GEMINI_API_KEY environment variable" }
            403 { throw "Access forbidden - Check API key permissions" }
            404 { throw "Model not found - Available models: gemini-2.0-flash-exp, gemini-1.5-pro, gemini-1.5-flash, gemini-1.5-flash-8b. See all models: https://ai.google.dev/gemini-api/docs/models" }
            429 { throw "Rate limit exceeded - Please try again later" }
            500 { throw "Server error - Try again later" }
            default { throw "API Error: $errorMessage" }
        }
    }
}

# Check for help
$helpArgs = @("-h", "--h", "help", "-Help")
if ($Arguments.Count -eq 0 -or ($Arguments.Count -le 2 -and $helpArgs -contains $Arguments[0])) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Parse arguments
$questionParts = @()
$hasProFlag = $false
$hasFlashFlag = $false
$nextArgIsModel = $false
$clearConvHistory = $false

$modelArgs = @("-m", "--model", "-model", "--m")
foreach ($arg in $Arguments) {
    if ($nextArgIsModel) {
        $modelName = $arg
        $nextArgIsModel = $false
        continue
    } elseif ($arg -eq "--p") {
        $hasProFlag = $true
    } elseif ($arg -eq "--f") {
        $hasFlashFlag = $true
    } elseif ($modelArgs -contains $arg) {
        $nextArgIsModel = $true
    }
    elseif ($arg -eq "--clear" -or $arg -eq "-clear") {
        $clearConvHistory = $true
    } else {
        $questionParts += $arg
    }
}

# Set model based on flags (priority: -p > -f > default)
if ($hasProFlag) {
    $modelName = "gemini-2.5-pro"
} elseif ($hasFlashFlag) {
    $modelName = "gemini-2.5-flash"
}

if ($clearConvHistory) {
    Clear-ConversationHistory
}

$Question = $questionParts -join " "

# Validate question length
if ($Question.Length -le 1) {
    Write-Host ""
    Write-Host "Prompt too short - make it bigger" -ForegroundColor Red
    Write-Host ""
    return
}

$apiKey = $null
$envFilePath = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFilePath) {
    $apiKey = (Get-Content $envFilePath | Where-Object { $_ -match "^GEMINI_API_KEY=" }) -replace "GEMINI_API_KEY=", ""
    if (-not $apiKey -or $apiKey.Trim() -eq "") {
        Write-Host ""
        Write-Host "❌ Error: API key not found." -ForegroundColor Red
        Write-Host "Please create a .env file with GEMINI_API_KEY=your_key" -ForegroundColor Yellow
        Write-Host ""
        return
    }
}

try {
    # Show loading indicator and timing
    Write-Host "🤖" -ForegroundColor Cyan
    
    # Make API call
    $response = Invoke-GeminiAPI -Question $Question -ModelName $modelName -ApiKey $apiKey
    
    # Display response
    Write-Host $response
    $Now = Get-Date
    $Total = $Now - $StartTime
    Write-Host "`n⚡ Done in $($Total.TotalSeconds.ToString("0.00"))s using $modelName" -ForegroundColor DarkGray
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}