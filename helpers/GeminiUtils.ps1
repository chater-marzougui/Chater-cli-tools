# Gemini AI Utilities for Chater-CLI Tools

# Import Core Utils if not already present
if (-not (Get-Command "Show-Header" -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\Utils.ps1"
}

# Helper to ensure file existence
function Assert-FileExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        $parentDir = Split-Path $Path -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        New-Item -Path $Path -ItemType File -Force | Out-Null
    }
}

function Get-HistoryFile {
    return Join-Path (Get-ProjectRoot) "helpers\conv-history.txt"
}

function Get-TokenFile {
    return Join-Path (Get-ProjectRoot) "helpers\token-usage.json"
}

function Get-ConversationHistory {
    $historyFile = Get-HistoryFile
    if (Test-Path $historyFile) {
        return Get-Content -Path $historyFile
    }
    return @()
}

function Add-ContentToHistory {
    param(
        [bool]$isUser = $true,
        [string]$Content
    )
    $historyFile = Get-HistoryFile
    Assert-FileExists $historyFile
    
    $newLine = if ($isUser) { "User: $Content" } else { "AI-Model: $Content`n" }
    Add-Content -Path $historyFile -Value $newLine -Encoding UTF8
}

function Update-TokenUsage {
    param(
        [string]$ModelName,
        [int]$TokenCount,
        [bool]$IsStream = $false
    )
    
    $tokenFile = Get-TokenFile
    Assert-FileExists $tokenFile
    $usage = @{}
    
    try {
        $content = Get-Content $tokenFile -Raw
        if (-not [string]::IsNullOrWhiteSpace($content)) {
            $jsonObj = $content | ConvertFrom-Json
            $jsonObj.PSObject.Properties | ForEach-Object {
                $usage[$_.Name] = @{
                    totalTokens = $_.Value.totalTokens
                    totalRequests = $_.Value.totalRequests
                    streamRequests = $_.Value.streamRequests
                    normalRequests = $_.Value.normalRequests
                    lastUsed = $_.Value.lastUsed
                }
            }
        }
    } catch {
        $usage = @{}
    }
    
    if (-not $usage.ContainsKey($ModelName)) {
        $usage[$ModelName] = @{
            totalTokens = 0
            totalRequests = 0
            streamRequests = 0
            normalRequests = 0
            lastUsed = ""
        }
    }
    
    $usage[$ModelName].totalTokens += $TokenCount
    $usage[$ModelName].totalRequests += 1
    $usage[$ModelName].lastUsed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    if ($IsStream) { $usage[$ModelName].streamRequests += 1 } else { $usage[$ModelName].normalRequests += 1 }
    
    $outputObj = New-Object PSObject
    foreach ($key in $usage.Keys) {
        $outputObj | Add-Member -MemberType NoteProperty -Name $key -Value ([PSCustomObject]$usage[$key])
    }
    
    $outputObj | ConvertTo-Json -Depth 3 | Set-Content $tokenFile -Encoding UTF8
}

function Invoke-GeminiAPI {
    param(
        [string]$Question,
        [string]$ModelName,
        [string]$ApiKey
    )

    $convHistory = Get-ConversationHistory
    $convHistoryText = if ($convHistory) { "Conversation History:`n$($convHistory -join "`n")" } else { "" }

    $enhancedPrompt = @"
Please provide a helpful, accurate, and concise response to the following question. 
If it's a technical question, include practical examples when appropriate.
This will be used in a CLI environment so adapt your response with: 
 - No large code snippets.
 - Use "-" for bullet points.
 - Add spaces before and after bullet points.
 - Make the response concise and as direct and short as possible.
 - Return only the main response text.

Question: $Question

$convHistoryText
"@

    $requestBody = @{
        contents = @( @{ parts = @( @{ text = $enhancedPrompt } ) } )
    } | ConvertTo-Json -Depth 10

    $apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/${ModelName}:generateContent"
    $headers = @{ "x-goog-api-key" = $ApiKey; "Content-Type" = "application/json" }
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $requestBody -TimeoutSec 30
        
        if ($response.candidates -and $response.candidates[0].content.parts) {
            Add-ContentToHistory -Content $Question -isUser $true
            $responseText = $response.candidates[0].content.parts[0].text
            Add-ContentToHistory -Content $responseText -isUser $false
            
            $tokenCount = $response.usageMetadata.promptTokenCount + $response.usageMetadata.candidatesTokenCount
            if ($response.usageMetadata.thoughtsTokenCount) { $tokenCount += $response.usageMetadata.thoughtsTokenCount }
            
            return $responseText, $tokenCount
        }
        throw "Empty response from Gemini API"
    }
    catch {
        $e = $_.Exception
        if ($e.Response) {
             throw "API Error ($($e.Response.StatusCode)): $($e.Message)"
        }
        throw "API Error: $($e.Message)"
    }
}
