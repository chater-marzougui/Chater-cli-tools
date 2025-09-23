[string[]]$Arguments = $args
# Colors for output
$Colors = @{
    Title = "Cyan"
    Success = "Green" 
    Error = "Red"
    Warning = "Yellow"
    Info = "Gray"
    Highlight = "Magenta"
}

$EnvFilePath = Join-Path $PSScriptRoot ".env"

function Get-EnvVariable {
    param([string]$Name)
    
    if (Test-Path $EnvFilePath) {
        $content = Get-Content $EnvFilePath | Where-Object { $_ -match "^$Name=" }
        if ($content) {
            return $content -replace "^$Name=", ""
        }
    }
    return $null
}

# Get script directory
$ScriptsDir = Get-EnvVariable "MAIN_SCRIPTS_PATH"
$HelpersDir = Join-Path $ScriptsDir "helpers"
$logsDir = Join-Path $ScriptsDir "logs"
$STDOUTFile = Join-Path $logsDir "STDOUT.txt"
$STDERRFile = Join-Path $logsDir "STDERR.txt"

function Show-Help {
    param (
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "🌐 Local Server & Tunnel Manager" -ForegroundColor $Colors.Title
    Write-Host "================================" -ForegroundColor $Colors.Title
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor $Colors.Warning
    Write-Host "  Serve local content using Python HTTP server, LocalTunnel, ngrok, or Serveo."
    Write-Host "  Perfect for quick file sharing, web development, and exposing local services."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor $Colors.Warning
    Write-Host "  chater-serve [port] [domain] [option] [directory]" -ForegroundColor $Colors.Success
    Write-Host "  chater-serve -p <port> -d <domain> <option>       # With flags" -ForegroundColor $Colors.Success
    Write-Host "  chater-serve --setup <option>                     # Setup specific service" -ForegroundColor $Colors.Success
    Write-Host "  chater-serve -h                                   # Show this help" -ForegroundColor $Colors.Success
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor $Colors.Warning
    Write-Host "  python      Local Python HTTP server (default)" -ForegroundColor $Colors.Success
    Write-Host "  tunnel      LocalTunnel - custom subdomain" -ForegroundColor $Colors.Success
    Write-Host "  --lt        Alias for tunnel" -ForegroundColor $Colors.Success
    Write-Host "  ngrok       Ngrok - secure tunneling" -ForegroundColor $Colors.Success
    Write-Host "  --n         Alias for ngrok" -ForegroundColor $Colors.Success
    Write-Host "  serveo      Serveo - SSH tunneling" -ForegroundColor $Colors.Success
    Write-Host "  --serveo    Alias for serveo" -ForegroundColor $Colors.Success
    Write-Host ""
    Write-Host "FLAGS:" -ForegroundColor $Colors.Warning
    Write-Host "  -p, --port <port>      Specify port number" -ForegroundColor $Colors.Success
    Write-Host "  -d, --domain <domain>  Specify domain/subdomain" -ForegroundColor $Colors.Success
    Write-Host "  -qr                    Include QR code generation" -ForegroundColor $Colors.Success
    Write-Host "  -lt-logs               Show LocalTunnel request logs" -ForegroundColor $Colors.Success
    Write-Host ""
    if (-not $isSmall) {
        Write-Host "EXAMPLES:" -ForegroundColor $Colors.Warning
        Write-Host "  chater-serve 3000                          # Python server on port 3000" -ForegroundColor $Colors.Success
        Write-Host "  chater-serve -p 8080 -d myapp tunnel       # LocalTunnel with flags" -ForegroundColor $Colors.Success
        Write-Host "  chater-serve 8080 myapp --lt               # LocalTunnel shorthand" -ForegroundColor $Colors.Success
        Write-Host "  chater-serve 5000 ngrok                    # Ngrok tunnel" -ForegroundColor $Colors.Success
        Write-Host "  chater-serve 4000 myserver serveo          # Serveo tunnel" -ForegroundColor $Colors.Success
        Write-Host "  chater-serve 3000 python ./dist            # Python server with directory" -ForegroundColor $Colors.Success
        Write-Host "  chater-serve --setup tunnel                # Setup LocalTunnel" -ForegroundColor $Colors.Success
        Write-Host ""
    }
    Write-Host "REQUIREMENTS:" -ForegroundColor $Colors.Warning
    Write-Host "  🐍 Python:      Built-in with Windows/most systems" -ForegroundColor $Colors.Info
    Write-Host "  🚇 LocalTunnel: Node.js + npm install -g localtunnel" -ForegroundColor $Colors.Info
    Write-Host "  🔒 Ngrok:       Download from https://ngrok.com + auth token" -ForegroundColor $Colors.Info
    Write-Host "  📡 Serveo:      SSH client (built-in on most systems)" -ForegroundColor $Colors.Info
    Write-Host ""
}

function Test-Command {
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

if(-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

function Setup-Python {
    Write-Host "🐍 Checking up Python HTTP Server..." -ForegroundColor $Colors.Info
    
    if (Test-Command "python3") {
        Write-Host "✅ Python3 is already installed and ready!" -ForegroundColor $Colors.Success
    }
    elseif (Test-Command "python") {
        Write-Host "✅ Python is available!" -ForegroundColor $Colors.Success
    }
    else {
        Write-Host "❌ Python is not installed!" -ForegroundColor $Colors.Error
        Write-Host "Please install Python from: https://python.org/downloads" -ForegroundColor $Colors.Warning
    }
    return
}

function Setup-LocalTunnel {
    Write-Host "🚇 Setting up LocalTunnel..." -ForegroundColor $Colors.Info
    
    # Check Node.js
    if (-not (Test-Command "node")) {
        Write-Host "❌ Node.js is not installed!" -ForegroundColor $Colors.Error
        Write-Host "Please install Node.js from: https://nodejs.org" -ForegroundColor $Colors.Warning
        return
    }
    
    Write-Host "✅ Node.js found" -ForegroundColor $Colors.Success
    
    # Check if LocalTunnel is installed globally
    try {
        $result = npm list -g localtunnel 2>$null
        if ($result -match "localtunnel@") {
            Write-Host "✅ LocalTunnel is already installed!" -ForegroundColor $Colors.Success
            return
        }
    }
    catch {}
    
    Write-Host "📦 Installing LocalTunnel globally..." -ForegroundColor $Colors.Info
    try {
        npm install -g localtunnel
        Write-Host "✅ LocalTunnel installed successfully!" -ForegroundColor $Colors.Success
        return
    }
    catch {
        Write-Host "❌ Failed to install LocalTunnel: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        return
    }
}

function Setup-Ngrok {
    Write-Host "🔒 Setting up ngrok..." -ForegroundColor $Colors.Info
    
    # Ensure helpers directory exists
    if (-not (Test-Path $HelpersDir)) {
        New-Item -ItemType Directory -Path $HelpersDir -Force | Out-Null
    }
    
    $ngrokPath = Join-Path $HelpersDir "ngrok.exe"
    
    # Check if ngrok.exe exists
    if (-not (Test-Path $ngrokPath)) {
        Write-Host "❌ ngrok.exe not found in $HelpersDir" -ForegroundColor $Colors.Error
        Write-Host "Please:" -ForegroundColor $Colors.Warning
        Write-Host "  1. Download ngrok from: https://ngrok.com/downloads/windows" -ForegroundColor $Colors.Info
        Write-Host "  2. Extract ngrok.exe to: $HelpersDir" -ForegroundColor $Colors.Info
        Write-Host "  3. Create a free account at ngrok.com to get your auth token" -ForegroundColor $Colors.Info
        return
    }
    
    Write-Host "✅ ngrok.exe found" -ForegroundColor $Colors.Success
    
    # Check auth token
    $authToken = Get-EnvVariable "NGROK_AUTH_TOKEN"
    if (-not $authToken) {
        Write-Host "❌ NGROK_AUTH_TOKEN not found in .env file" -ForegroundColor $Colors.Error
        Write-Host "Please:" -ForegroundColor $Colors.Warning
        Write-Host "  1. Create a free account at https://ngrok.com" -ForegroundColor $Colors.Info
        Write-Host "  2. Get your auth token from the dashboard" -ForegroundColor $Colors.Info
        Write-Host "  3. Add NGROK_AUTH_TOKEN=your_token to .env file" -ForegroundColor $Colors.Info
        return
    }
    
    # Set auth token
    try {
        & $ngrokPath authtoken $authToken
        Write-Host "✅ ngrok configured with auth token!" -ForegroundColor $Colors.Success
        return
    }
    catch {
        Write-Host "❌ Failed to configure ngrok: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        return
    }
}

function Get-LocalIP {
    # Prefer Wi-Fi or Ethernet, ignore virtual adapters
    $adapter = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
               Where-Object { 
                   $_.IPAddress -notlike "169.*" -and 
                   $_.IPAddress -ne "127.0.0.1" -and 
                   $_.InterfaceAlias -notlike "vEthernet*" -and
                   $_.InterfaceAlias -notlike "Loopback*" -and
                   $_.InterfaceAlias -notlike "*Virtual*" 
               } |
               Sort-Object InterfaceMetric |
               Select-Object -First 1

    if ($adapter) {
        return $adapter.IPAddress
    } else {
        Write-Host "❌ Could not retrieve local IPv4." -ForegroundColor Red
    }
}

function Start-PythonServer {
    param([string]$Port, [string]$Subdomain, [string]$Directory, [bool]$QR)
    
    if ($Subdomain -and $Subdomain -ne "") {
        Write-Host "⚠️  Subdomain will be supported soon. For now using localhost" -ForegroundColor $Colors.Warning
    }

    Write-Host "🐍 Starting Python HTTP Server on port $Port..." -ForegroundColor $Colors.Info
    Write-Host "📂 Serving files from: $Directory" -ForegroundColor $Colors.Info
    Write-Host "🌐 Local URL: http://localhost:$Port" -ForegroundColor $Colors.Highlight
    Write-Host "🌐 Local IP URL: http://$(Get-LocalIP):$Port" -ForegroundColor $Colors.Highlight
    Write-Host "🛑 Press Ctrl+C to stop" -ForegroundColor $Colors.Warning
    Write-Host ""
    
    try {
        if (Test-Command "python") {
            if($QR) {& chater-qr "http://$(Get-LocalIP):$Port"}
            python -m http.server $Port --directory $Directory
        }
        elseif (Test-Command "python3") {
            if($QR) {& chater-qr "http://$(Get-LocalIP):$Port"}
            python3 -m http.server $Port --directory $Directory
        }
        else {
            throw "Python not found"
        }
    }
    catch {
        Write-Host "❌ Failed to start Python server: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Write-Host "💡 Try running: chater-serve --setup python" -ForegroundColor $Colors.Info
    }
}

function Start-LocalTunnel {
    param([string]$Port, [string]$Subdomain, [bool]$PrintRequests, [bool]$QR)

    if (-not (Test-Command "lt")) {
        Write-Host "❌ LocalTunnel not found!" -ForegroundColor $Colors.Error
        Write-Host "💡 Try running: chater-serve --setup tunnel" -ForegroundColor $Colors.Info
        return
    }

    $tunnelArgs = @("lt", "--port", $Port)

    if ($Subdomain -and $Subdomain -ne "") {
        $tunnelArgs += @("--subdomain", $Subdomain)
    }
    
    if ($PrintRequests) {
        $tunnelArgs += "--print-requests"
    }
    
    Write-Host "🛑 Press Ctrl+C to stop" -ForegroundColor $Colors.Warning
    Write-Host ""
    
    try {
        if (Test-Path $STDOUTFile) { Remove-Item $STDOUTFile -Force }
        if (Test-Path $STDERRFile) { Remove-Item $STDERRFile -Force }
        $process = Start-Process "npx" -ArgumentList $tunnelArgs `
        -RedirectStandardOutput $STDOUTFile -RedirectStandardError $STDERRFile `
        -NoNewWindow -PassThru

        # Wait until it outputs the public URL
        $publicUrl = $null
        $lastLineCount = 0
        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 100
            if (Test-Path $STDOUTFile) {
                $lines = Get-Content $STDOUTFile
                if($lines -and $lines.GetType().Name -eq "String") {
                    if ($lastLineCount -eq 1) {
                        continue;
                    }
                    $lastLineCount = 1
                    if ($lines -match "your url is: (https?://[^\s]+)") {
                        $publicUrl = $matches[1]
                        Write-Host "✅ LocalTunnel URL: $publicUrl" -ForegroundColor Green
                        if ($QR) {
                            Write-Host "📱 Generating QR code for: $publicUrl" -ForegroundColor Cyan
                            & chater-qr $publicUrl
                        }
                    }
                }
                elseif ($lines) {
                    $newLines = $lines[$lastLineCount..($lines.Count)]
                    $lastLineCount = $lines.Count

                    foreach ($line in $newLines) {
                        Write-Host "[lt] $line" -ForegroundColor Green
                    }
                }
            }
        }
    }
    catch {
        Write-Host "❌ Failed to start LocalTunnel: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Write-Host "💡 Try running: chater-serve --setup tunnel" -ForegroundColor $Colors.Info
    }
}

function Start-Ngrok {
    param([string]$Port, [bool]$QR)

    $ngrokPath = Join-Path $HelpersDir "ngrok.exe"
    
    if (-not (Test-Path $ngrokPath)) {
        Write-Host "❌ ngrok.exe not found!" -ForegroundColor $Colors.Error
        Write-Host "💡 Try running: chater-serve --setup ngrok" -ForegroundColor $Colors.Info
        return
    }

    try {
        $configCheck = & ngrok config check 2>&1
        if ($configCheck -notmatch "Valid configuration file") {
            Write-Host "❌ ngrok configuration is invalid" -ForegroundColor $Colors.Error
            Write-Host "💡 Try running: chater-serve --setup ngrok" -ForegroundColor $Colors.Info
            return
        }
    }
    catch {
        Write-Host "❌ Failed to check ngrok configuration: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        return
    }

    Write-Host "🔒 Starting ngrok tunnel on port $Port..." -ForegroundColor $Colors.Info
    Write-Host "🌐 Ngrok will provide a random public URL" -ForegroundColor $Colors.Info
    Write-Host "🛑 Press Ctrl+C to stop" -ForegroundColor $Colors.Warning
    Write-Host ""
    
    try {
        $job = Start-Job -ScriptBlock {
            param([bool]$isQR)
            if(-not $isQR) {
                return
            }
            Start-Sleep -Seconds 2

            $ngrokApi = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -ErrorAction Stop
            $publicUrl = $ngrokApi.tunnels[0].public_url

            if ($publicUrl) {
                Write-Host "📱 Generating QR code for: $publicUrl" -ForegroundColor $Colors.Info
                & chater-qr $publicUrl --web
            }
        } -ArgumentList $QR

        
        & $ngrokPath http $Port
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "❌ Failed to start ngrok: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Write-Host "💡 Try running: chater-serve --setup ngrok" -ForegroundColor $Colors.Info
    }
}

function Start-Serveo {
    param([string]$Port, [string]$Subdomain, [bool]$QR)

    if (Test-Path $STDOUTFile) { Remove-Item $STDOUTFile -Force }
    if (Test-Path $STDERRFile) { Remove-Item $STDERRFile -Force }

    $tunnelArgs = @("-R")

    if ($Subdomain -and $Subdomain -ne "") {
        $tunnelArgs += "$Subdomain:80:localhost:$Port"
        Write-Host "🚇 Starting Serveo on port $Port with subdomain '$Subdomain'..." -ForegroundColor $Colors.Info
        Write-Host "🌐 Public URL: https://$Subdomain.serveo.net" -ForegroundColor $Colors.Highlight
    }
    else {
        $tunnelArgs += "80:localhost:$Port"
    }

    $tunnelArgs += "serveo.net"

    Write-Host "🛑 Press Ctrl+C to stop" -ForegroundColor $Colors.Warning
    try {
        $process = Start-Process "ssh" -ArgumentList $tunnelArgs -RedirectStandardOutput $STDOUTFile -RedirectStandardError $STDERRFile -NoNewWindow -PassThru

        # Register cleanup on process exit
        $eventJob = Register-ObjectEvent -InputObject $process -EventName Exited -Action {
            Start-Sleep -Seconds 1
            if (Test-Path $STDOUTFile) { Remove-Item $STDOUTFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path $STDERRFile) { Remove-Item $STDERRFile -Force -ErrorAction SilentlyContinue }
        }

        # Read the file as raw bytes to handle control characters properly
        $stream = [System.IO.File]::Open($STDOUTFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $reader = New-Object System.IO.StreamReader($stream)
        $position = 0
        
        # Also monitor stderr
        $errorStream = [System.IO.File]::Open($STDERRFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $errorReader = New-Object System.IO.StreamReader($errorStream)
        $errorPosition = 0
        
        while (-not $process.HasExited) {
            # Check for errors
            $errorStream.Seek($errorPosition, [System.IO.SeekOrigin]::Begin) | Out-Null
            $errorContent = $errorReader.ReadToEnd()
            $errorPosition = $errorStream.Position
            
            if ($errorContent -and $errorContent.Trim().Length -gt 0) {
                $time = Get-Date -Format "HH:mm:ss"
                [console]::WriteLine("[$time] ERROR: $($errorContent.Trim())")
                if($Subdomain) {
                    [console]::WriteLine("❌ Subdomains with serveo need to be configured")
                }
                $process | Stop-Process -Force -ErrorAction SilentlyContinue
                break
            }
            
            # Read new content from stdout
            $stream.Seek($position, [System.IO.SeekOrigin]::Begin) | Out-Null
            $newContent = $reader.ReadToEnd()
            $position = $stream.Position
            
            if ($newContent -and $newContent.Trim().Length -gt 0) {
                # Clean up ANSI escape sequences and control characters
                $cleanContent = $newContent -replace '\x1b\[[0-9;]*[A-Za-z]', '' -replace '\x08', ''
                
                # Split by carriage return and process each "line"
                $lines = $cleanContent -split "`r" | Where-Object { $_.Trim().Length -gt 0 }
                foreach ($line in $lines) {
                    $trimmedLine = $line.Trim()
                    
                    if ($trimmedLine -match "Forwarding HTTP traffic from (https?://[^\s]+)") {
                        [console]::WriteLine("")
                        Write-Host "✅ LocalTunnel URL: $($matches[1])" -ForegroundColor Green
                        [console]::WriteLine("")
                        if ($QR) {
                            & chater-qr $matches[1] 2>$null
                        }
                    }
                    elseif ($trimmedLine.Length -gt 5 -and -not $trimmedLine.StartsWith('K')) {
                        # Write each message on a new line with timestamp
                        $time = Get-Date -Format "HH:mm:ss"
                        [System.Console]::WriteLine("[$time] $trimmedLine")
                    }
                }
            }
            
            Start-Sleep -Milliseconds 100
        }
    }
    catch {
        Write-Host "❌ Failed to start Serveo: $($_.Exception.Message)" -ForegroundColor $Colors.Error
    }
    finally {
        # Cleanup resources
        try {
            if ($reader) { $reader.Close(); $reader.Dispose() }
            if ($stream) { $stream.Close(); $stream.Dispose() }
            if ($errorReader) { $errorReader.Close(); $errorReader.Dispose() }
            if ($errorStream) { $errorStream.Close(); $errorStream.Dispose() }
            if ($eventJob) { $eventJob | Remove-Job -Force }
            if ($process -and -not $process.HasExited) { $process | Stop-Process -Force -ErrorAction SilentlyContinue }
            if (Test-Path $STDOUTFile) { Remove-Item $STDOUTFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path $STDERRFile) { Remove-Item $STDERRFile -Force -ErrorAction SilentlyContinue }
        } catch {}
    }
}

# Parse arguments function
function ParseArguments {
    $result = @{
        Option = "python"
        Port = $null
        Domain = $null
        Directory = $null
        PrintRequests = $false
        IsSetup = $false
        SetupOption = $null
        ShowHelp = $false
        ShowSmallHelp = $false
        QR = $false
    }

    # Help check
    $helpArgs = @("-h", "--h", "help", "-help", "--help", "h")
    if ($Arguments.Count -eq 0 -or ($Arguments.Count -le 2 -and $Arguments[0].ToLower() -in $helpArgs)) {
        $isSmall = ($Arguments -contains "--small")
        $result.ShowHelp = $true
        $result.ShowSmallHelp = $isSmall
        return $result
    }
    
    # Setup check
    $setupArgs = @("--s", "--setup", "-s", "-setup", "s", "setup")
    if ($Arguments.Where({ $_ -in $setupArgs }).Count -gt 0) {
        $result.IsSetup = $true
        $possibleOptions = @("python", "tunnel", "ngrok", "--n", "--lt")
        $result.SetupOption = ($Arguments | Where-Object { $_.ToLower() -in $possibleOptions })
        return $result
    }
    
    # Process arguments
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]

        switch -Regex ($arg) {
            '^(-p|--p|p|--port|port|-port)$' {
                if ($i + 1 -lt $Arguments.Count) {
                    $result.Port = $Arguments[$i + 1]
                    $i++ # Skip next argument as it's the port value
                }
                break
            }
            '^(-d|d|--d|--domain|domain|-domain)$' {
                if ($i + 1 -lt $Arguments.Count) {
                    $result.Domain = $Arguments[$i + 1]
                    $i++ # Skip next argument as it's the domain value
                }
                break
            }
            '^(python|tunnel|-lt|--lt|ngrok|-n|--n|serveo|-serveo|--serveo)$' {
                switch -Regex ($arg.ToLower()) {
                    "^(tunnel|-lt|--lt)" { $result.Option = "tunnel" }
                    "^(ngrok|-n|--n)" { $result.Option = "ngrok" }
                    "^(serveo|-serveo|--serveo)" { $result.Option = "serveo" }
                    default { $result.Option = "python" }
                }
                break
            }
            '^(--qr|-qr)$' {
                $result.QR = $true
                break
            }
            '^-lt-logs$' {
                $result.PrintRequests = $true
                break
            }
            '^\d+$' {
                # It's a port number
                if (-not $result.Port) {
                    $result.Port = $arg
                }
                break
            }
            default {
                # Check if it's a directory path
                if (Test-Path $arg -PathType Container) {
                    $result.Directory = $arg
                }
                # Check if it's a domain (not a recognized option and not a path)
                elseif (-not $result.Domain -and $arg -notmatch '^(-|--|/)') {
                    $result.Domain = $arg
                }
            }
        }
    }
    return $result
}

# Main execution
$parsed = ParseArguments

if ($parsed.ShowHelp) {
    Show-Help -isSmall $parsed.ShowSmallHelp
    return
}

if ($parsed.IsSetup) {
    switch ($parsed.SetupOption) {
        "python" { Setup-Python }
        { $_ -in @("tunnel", "--lt") } { Setup-LocalTunnel }
        { $_ -in @("ngrok", "--n") } { Setup-Ngrok }
        default {
            Write-Host "❌ Unknown setup option: $($parsed.SetupOption)" -ForegroundColor $Colors.Error
            Write-Host "Available options: python, tunnel, ngrok" -ForegroundColor $Colors.Info
        }
    }
    return
}

# Set default port if not specified
if (-not $parsed.Port) {
    Write-Host "❌ Port not specified" -ForegroundColor $Colors.Error
    return
}

# Validate port
if (-not ($parsed.Port -match '^\d+$') -or [int]$parsed.Port -lt 1 -or [int]$parsed.Port -gt 65535) {
    Write-Host "❌ Invalid port number: $($parsed.Port)" -ForegroundColor $Colors.Error
    Write-Host "Port must be a number between 1 and 65535" -ForegroundColor $Colors.Info
    return
}

# Set default directory for Python if not specified
if ($parsed.Option -eq "python" -and (-not $parsed.Directory -or $parsed.Directory.Trim() -eq "")) {
    $parsed.Directory = Get-Location
}

# Compatibility checks
if ($parsed.Option -ne "python" -and $parsed.Directory) {
    Write-Host "❌ Directory is not supported for option: $($parsed.Option)" -ForegroundColor $Colors.Error
    return
}

if ($parsed.Option -eq "ngrok" -and $parsed.Domain) {
    Write-Host "❌ Custom domain is not supported for ngrok free version." -ForegroundColor $Colors.Error
    Write-Host "If you have a pro ngrok account, please modify this script or contact for support." -ForegroundColor $Colors.Info
    return
}

# Start the appropriate server
switch ($parsed.Option) {
    "python" {
        Start-PythonServer -Port $parsed.Port -Subdomain $parsed.Domain -Directory $parsed.Directory -QR $parsed.QR
    }
    "tunnel" {
        Start-LocalTunnel -Port $parsed.Port -Subdomain $parsed.Domain -PrintRequests $parsed.PrintRequests -QR $parsed.QR
    }
    "ngrok" {
        Start-Ngrok -Port $parsed.Port -QR $parsed.QR
    }
    "serveo" {
        Start-Serveo -Port $parsed.Port -Subdomain $parsed.Domain -QR $parsed.QR
    }
    default {
        Write-Host "❌ Unknown option: $($parsed.Option)" -ForegroundColor $Colors.Error
        Write-Host "Available options: python, tunnel, ngrok, serveo" -ForegroundColor $Colors.Info
        Write-Host "💡 Use 'chater-serve -h' for help" -ForegroundColor $Colors.Info
    }
}
