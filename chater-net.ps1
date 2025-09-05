$Arguments = $args

function Show-Help {
    param (
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "Chater-Net - Network Diagnostics Suite" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Comprehensive network diagnostics and information tool."
    Write-Host "  Test connectivity, speed, DNS resolution, and more."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-net                          # Show all network info" -ForegroundColor Green
    Write-Host "  chater-net -ip                      # Show local + public IP only" -ForegroundColor Green
    Write-Host "  chater-net -speed                   # Internet speed test" -ForegroundColor Green
    Write-Host "  chater-net -dns <domain>            # DNS lookup" -ForegroundColor Green
    Write-Host "  chater-net -trace <target>          # Traceroute to target" -ForegroundColor Green
    Write-Host "  chater-net -whoami                  # Detailed public IP info" -ForegroundColor Green
    Write-Host "  chater-net -h                       # Show this help" -ForegroundColor Green
    Write-Host ""
    if ($isSmall) { return }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-net -dns google.com" -ForegroundColor Green
    Write-Host "  chater-net -trace 8.8.8.8" -ForegroundColor Green
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -count <n>          Number of ping packets (default: 4)"
    Write-Host "  -timeout <ms>       Connection timeout in milliseconds (default: 5000)"
    Write-Host ""
}

function Get-NetworkIcon {
    param([string]$Type)
    switch ($Type) {
        "ip" { return "🌐" }
        "speed" { return "⚡" }
        "dns" { return "🔍" }
        "trace" { return "🛤️" }
        "whoami" { return "👤" }
        "port" { return "🔌" }
        "ping" { return "📡" }
        "error" { return "❌" }
        "success" { return "✅" }
        "warning" { return "⚠️" }
        default { return "📊" }
    }
}

function Write-SectionHeader {
    param([string]$Title, [string]$Icon = "📊")
    Write-Host ""
    Write-Host "$Icon $Title" -ForegroundColor Cyan
    Write-Host ("=" * ($Title.Length + 3)) -ForegroundColor DarkCyan
}

function Get-LocalIP {
    Write-SectionHeader "Local Network Information" "🏠"
    
    # Get primary network adapter
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
        Write-Host "Local IPv4    : " -NoNewline -ForegroundColor Green
        Write-Host $adapter.IPAddress
        Write-Host "Interface     : " -NoNewline -ForegroundColor Cyan
        Write-Host $adapter.InterfaceAlias
        
        # Get default gateway
        try {
            $gateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | 
                      Select-Object -First 1 -ExpandProperty NextHop
            if ($gateway) {
                Write-Host "Default Gateway: " -NoNewline -ForegroundColor Yellow
                Write-Host $gateway
            }
        } catch {}
        
        # Get DNS servers
        try {
            $dns = Get-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($dns.ServerAddresses) {
                Write-Host "DNS Servers   : " -NoNewline -ForegroundColor Magenta
                Write-Host ($dns.ServerAddresses -join ", ")
            }
        } catch {}
    } else {
        Write-Host "$(Get-NetworkIcon 'error') Could not retrieve local IPv4." -ForegroundColor Red
    }
}

function Get-PublicIP {
    Write-SectionHeader "Public IP Information" "🌍"
    
    try {
        Write-Host "Checking public IP..." -ForegroundColor Gray
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -UseBasicParsing -TimeoutSec 10
        Write-Host "Public IPv4: " -NoNewline -ForegroundColor Green
        Write-Host $publicIP.ip
        return $publicIP.ip
    } catch {
        try {
            $publicIP6 = Invoke-RestMethod -Uri "https://api64.ipify.org?format=json" -UseBasicParsing -TimeoutSec 10
            Write-Host "Public IPv6: " -NoNewline -ForegroundColor Green
            Write-Host $publicIP6.ip
            return $publicIP6.ip
        } catch {
            Write-Host "$(Get-NetworkIcon 'error') Could not fetch public IP." -ForegroundColor Red
            return $null
        }
    }
}

function Test-DownloadSpeed {
    param(
        [int]$ThreadCount = 4,
        [int]$ChunkSize = 8MB,
        [int]$TimeoutSec = 60
    )
    
    try {
        $testUrl = "https://speed.cloudflare.com/__down?bytes=$ChunkSize"
        
        # Create script block for parallel downloads
        $downloadScript = {
            param($Url, $TimeoutSec)
            
            try {
                $ProgressPreference = 'SilentlyContinue'
                $startTime = Get-Date
                $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                $endTime = Get-Date
                
                return @{
                    Success = $true
                    Bytes = $response.RawContentStream.Length
                    Duration = ($endTime - $startTime).TotalSeconds
                    Url = $Url
                }
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    Url = $Url
                }
            }
        }
        
        # Start parallel jobs
        $jobs = @()
        for ($i = 0; $i -lt $ThreadCount; $i++) {
            $url = $testUrl + "&thread=$i"
            $job = Start-Job -ScriptBlock $downloadScript -ArgumentList $url, 30
            $jobs += $job
        }
        
        # Wait for jobs with timeout
        $loadingStates = @('-', '\', '|', '/')
        $loadingIndex = 0
        $startTime = Get-Date

        while ($jobs | Where-Object { $_.State -eq 'Running' }) {
            $loadingChar = $loadingStates[$loadingIndex % $loadingStates.Count]
            Write-Host -NoNewline "`r$loadingChar "
            Start-Sleep -Milliseconds 120
            $loadingIndex++

            if ((Get-Date) - $startTime -gt [TimeSpan]::FromSeconds($TimeoutSec)) {
                Write-Host "`r⚠ Timeout reached, continuing with completed threads...   " -ForegroundColor Yellow
                break
            }
        }
        Write-Host "`r" -NoNewline
        
        # Collect results
        $results = @()
        $totalBytes = 0
        $totalDuration = 0
        $successCount = 0
        $completed = $jobs | Where-Object { $_.State -eq 'Completed' }
        $jobs | Where-Object { $_.State -eq 'Running' } | Remove-Job -Force -ErrorAction SilentlyContinue

        foreach ($job in $completed) {
            try {
                # Check if job still exists before trying to receive results
                if ($job.State -eq 'Running' -or $job.State -eq 'Completed') {
                    $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                    
                    if ($result -and $result.Success) {
                        $results += $result
                        $totalBytes += $result.Bytes
                        $totalDuration += $result.Duration
                        $successCount++
                        $threadMessage = "  Thread $($successCount): {0:N2} MB in {1:N2}s" -f ($result.Bytes/1MB), $result.Duration
                        Write-Host $threadMessage -ForegroundColor DarkGreen
                    } else {
                        $errorMsg = if ($result) { $result.Error } else { "Unknown error" }
                        Write-Host "  Thread failed: $errorMsg" -ForegroundColor DarkRed
                    }
                } else {
                    Write-Host "  Thread terminated unexpectedly (State: $($job.State))" -ForegroundColor DarkRed
                }
            } catch {
                Write-Host "  Thread error: $($_.Exception.Message)" -ForegroundColor DarkRed
            } finally {
                # Safely remove job if it exists
                if ($job -and (Get-Job -Id $job.Id -ErrorAction SilentlyContinue)) {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        if ($successCount -gt 0) {
            # Average per-thread throughput
            $threadSpeeds = $results | ForEach-Object { (($_.Bytes * 8) / ($_.Duration * 1MB)) }

            # Average per-thread throughput
            $avgSpeed = ($threadSpeeds | Measure-Object -Average).Average

            # Peak per-thread throughput
            $peakSpeed = ($threadSpeeds | Measure-Object -Maximum).Maximum

            # Overall throughput (parallel threads, real-world)
            $maxDuration = ($results | ForEach-Object { $_.Duration } | Measure-Object -Maximum).Maximum
            $totalThroughput = ($totalBytes * 8) / ($maxDuration * 1MB)

            Write-Host ""
            Write-Host ("{0} Download Speed: {1:N2} Mbps | {2:N2} Mbps avg/thread | {3:N2} Mbps peak/thread" -f (Get-NetworkIcon 'success'), $totalThroughput, $avgSpeed, $peakSpeed) -ForegroundColor Green

            $dataMessage = "  Total data: {0:N2} MB across $successCount threads" -f ($totalBytes/1MB)
            Write-Host $dataMessage -ForegroundColor Gray
            
            return @{
                Success = $true
                TotalThroughput = $totalThroughput
                AvgSpeed = $avgSpeed
                PeakSpeed = $peakSpeed
                TotalBytes = $totalBytes
                SuccessCount = $successCount
            }
        } else {
            Write-Host "$(Get-NetworkIcon 'error') All download threads failed" -ForegroundColor Red
            return @{ Success = $false }
        }
        
    } catch {
        Write-Host "$(Get-NetworkIcon 'error') Download speed test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false }
    } finally {
        # Clean up any remaining jobs safely
        $remainingJobs = Get-Job -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "Job*" }
        foreach ($job in $remainingJobs) {
            try {
                if (Get-Job -Id $job.Id -ErrorAction SilentlyContinue) {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            } catch {
                # Silent cleanup - we don't care about errors during cleanup
            }
        }
    }
}

function Test-UploadSpeed {
    param(
        [int]$ThreadCount = 4,
        [int]$ChunkSize = 4MB,
        [int]$TimeoutSec = 60
    )
    
    try {
        # Create script block for parallel uploads
        $uploadScript = {
            param($ChunkSize, $TimeoutSec, $ThreadId)
            
            try {
                $ProgressPreference = 'SilentlyContinue'
                
                # Try multiple upload endpoints for better compatibility
                $uploadUrl = "https://speed.cloudflare.com/__up"
                
                # Create proper byte array for upload
                $uploadData = New-Object byte[] $ChunkSize
                (New-Object System.Random).NextBytes($uploadData)
                
                $startTime = Get-Date
                $success = $false
                $response = $null
                
                try {
                    $response = Invoke-WebRequest -Uri $uploadUrl -Method Post -Body $uploadData -ContentType "application/octet-stream" -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                    
                    if ($response.StatusCode -eq 200) {
                        $success = $true
                    }
                } catch {
                    Write-Host "Thread $ThreadId : Failed with $uploadUrl - $($_.Exception.Message)"
                }
                
                $endTime = Get-Date
                
                if ($success) {
                    return @{
                        Success = $true
                        Bytes = $ChunkSize
                        Duration = ($endTime - $startTime).TotalSeconds
                        ThreadId = $ThreadId
                        Endpoint = $uploadUrl
                    }
                } else {
                    return @{
                        Success = $false
                        Error = "All upload endpoints failed"
                        ThreadId = $ThreadId
                    }
                }
                
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    ThreadId = $ThreadId
                }
            }
        }
        
        # Start parallel jobs
        $jobs = @()
        for ($i = 0; $i -lt $ThreadCount; $i++) {
            $job = Start-Job -ScriptBlock $uploadScript -ArgumentList $ChunkSize, 45, $i
            $jobs += $job
        }
        
        # Wait for jobs with timeout (same as original)
        $loadingStates = @('-', '\', '|', '/')
        $loadingIndex = 0
        $startTime = Get-Date

        while ($jobs | Where-Object { $_.State -eq 'Running' }) {
            $loadingChar = $loadingStates[$loadingIndex % $loadingStates.Count]
            Write-Host -NoNewline "`r$loadingChar "
            Start-Sleep -Milliseconds 120
            $loadingIndex++

            if ((Get-Date) - $startTime -gt [TimeSpan]::FromSeconds($TimeoutSec)) {
                Write-Host "`r⚠ Upload timeout reached, continuing with completed threads...   " -ForegroundColor Yellow
                break
            }
        }
        Write-Host "`r" -NoNewline
        
        # Collect results (same as original)
        $results = @()
        $totalBytes = 0
        $successCount = 0
        $completed = $jobs | Where-Object { $_.State -eq 'Completed' }
        $jobs | Where-Object { $_.State -eq 'Running' } | Remove-Job -Force -ErrorAction SilentlyContinue

        foreach ($job in $completed) {
            try {
                if ($job.State -eq 'Running' -or $job.State -eq 'Completed') {
                    $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                    
                    if ($result -and $result.Success) {
                        $results += $result
                        $totalBytes += $result.Bytes
                        $successCount++
                        $threadMessage = "  Thread $($successCount): {0:N2} MB in {1:N2}s via {2}" -f ($result.Bytes/1MB), $result.Duration, ($result.Endpoint -replace "https://", "" -replace "/.*", "")
                        Write-Host $threadMessage -ForegroundColor DarkBlue
                    } else {
                        $errorMsg = if ($result) { $result.Error } else { "Unknown error" }
                        Write-Host "  Upload thread $($result.ThreadId) failed: $errorMsg" -ForegroundColor DarkRed
                    }
                }
            } catch {
                Write-Host "  Upload thread error: $($_.Exception.Message)" -ForegroundColor DarkRed
            } finally {
                if ($job -and (Get-Job -Id $job.Id -ErrorAction SilentlyContinue)) {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        if ($successCount -gt 0) {
            # Calculate speeds (same as original)
            $threadSpeeds = $results | ForEach-Object { (($_.Bytes * 8) / ($_.Duration * 1MB)) }
            $avgSpeed = ($threadSpeeds | Measure-Object -Average).Average
            $peakSpeed = ($threadSpeeds | Measure-Object -Maximum).Maximum
            $maxDuration = ($results | ForEach-Object { $_.Duration } | Measure-Object -Maximum).Maximum
            $totalThroughput = ($totalBytes * 8) / ($maxDuration * 1MB)

            Write-Host ""
            $uploadMessage = "$(Get-NetworkIcon 'success') Upload Speed: {0:N2} Mbps | {1:N2} Mbps avg/thread | {2:N2} Mbps peak/thread" -f $totalThroughput, $avgSpeed, $peakSpeed
            Write-Host $uploadMessage -ForegroundColor Blue
            
            $dataMessage = "  Total data: {0:N2} MB across $successCount threads" -f ($totalBytes/1MB)
            Write-Host $dataMessage -ForegroundColor Gray
            
            return @{
                Success = $true
                TotalThroughput = $totalThroughput
                AvgSpeed = $avgSpeed
                PeakSpeed = $peakSpeed
                TotalBytes = $totalBytes
                SuccessCount = $successCount
            }
        } else {
            Write-Host "$(Get-NetworkIcon 'error') All upload threads failed" -ForegroundColor Red
            return @{ Success = $false }
        }
        
    } catch {
        Write-Host "$(Get-NetworkIcon 'error') Upload speed test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false }
    } finally {
        # Clean up remaining jobs (same as original)
        $remainingJobs = Get-Job -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "Job*" }
        foreach ($job in $remainingJobs) {
            try {
                if (Get-Job -Id $job.Id -ErrorAction SilentlyContinue) {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            } catch {
                # Silent cleanup
            }
        }
    }
}

function Test-Latency {
    param(
        [string]$TargetHost = "1.1.1.1",
        [int]$Count = 4
    )
    
    try {
        $ping = Test-Connection -ComputerName $TargetHost -Count $Count -ErrorAction SilentlyContinue
        if ($ping) {
            $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
            $minLatency = ($ping | Measure-Object -Property ResponseTime -Minimum).Minimum
            $maxLatency = ($ping | Measure-Object -Property ResponseTime -Maximum).Maximum
            
            $latencyMessage = "$(Get-NetworkIcon 'ping') Latency: {0:N0}ms avg | {1:N0}ms min | {2:N0}ms max (to $TargetHost)" -f $avgLatency, $minLatency, $maxLatency
            Write-Host $latencyMessage -ForegroundColor Yellow
            
            return @{
                Success = $true
                Average = $avgLatency
                Minimum = $minLatency
                Maximum = $maxLatency
                TargetHost = $TargetHost
            }
        } else {
            Write-Host "$(Get-NetworkIcon 'error') Latency test failed: No response from $TargetHost" -ForegroundColor Red
            return @{ Success = $false }
        }
    } catch {
        Write-Host "$(Get-NetworkIcon 'error') Latency test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false }
    }
}

function Test-InternetSpeed {
    Write-SectionHeader "Internet Speed Test" "⚡"
    Write-Host "Running speed test (this may take a moment)..." -ForegroundColor Gray
    
    # Run download speed test
    $downloadResult = Test-DownloadSpeed
    
    Write-Host ""
    
    # Run upload speed test
    Start-Sleep -Seconds 1
    $uploadResult = Test-UploadSpeed
    
    Write-Host ""
    
    # Run latency test
    $latencyResult = Test-Latency
}

function Resolve-DnsLookup {
    param([string]$Domain)
    
    if (-not $Domain) {
        Write-Host "$(Get-NetworkIcon 'error') Please specify a domain name." -ForegroundColor Red
        return
    }
    
    Write-SectionHeader "DNS Lookup for '$Domain'" "🔍"
    
    try {
        # A Records (IPv4)
        $aRecords = Resolve-DnsName -Name $Domain -Type A -ErrorAction SilentlyContinue
        if ($aRecords) {
            Write-Host "A Records (IPv4):" -ForegroundColor Green
            foreach ($record in $aRecords) {
                if ($record.IPAddress) {
                    Write-Host "  $($record.IPAddress)" -ForegroundColor White
                }
            }
        }
        
        # AAAA Records (IPv6)
        $aaaaRecords = Resolve-DnsName -Name $Domain -Type AAAA -ErrorAction SilentlyContinue
        if ($aaaaRecords) {
            Write-Host "AAAA Records (IPv6):" -ForegroundColor Green
            foreach ($record in $aaaaRecords) {
                if ($record.IPAddress) {
                    Write-Host "  $($record.IPAddress)" -ForegroundColor White
                }
            }
        }
        
        # CNAME Records
        $cnameRecords = Resolve-DnsName -Name $Domain -Type CNAME -ErrorAction SilentlyContinue
        if ($cnameRecords) {
            Write-Host "CNAME Records:" -ForegroundColor Magenta
            foreach ($record in $cnameRecords) {
                if ($record.NameHost) {
                    Write-Host "  $($record.NameHost)" -ForegroundColor White
                }
            }
        }
        
        # MX Records
        $mxRecords = Resolve-DnsName -Name $Domain -Type MX -ErrorAction SilentlyContinue
        if ($mxRecords) {
            Write-Host "MX Records (Mail):" -ForegroundColor Yellow
            foreach ($record in $mxRecords | Sort-Object Preference) {
                Write-Host "  Priority $($record.Preference): $($record.NameExchange)" -ForegroundColor White
            }
        }
        
    } catch {
        Write-Host "$(Get-NetworkIcon 'error') DNS lookup failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Start-Traceroute {
    param([string]$Target)
    
    if (-not $Target) {
        Write-Host "$(Get-NetworkIcon 'error') Please specify a target." -ForegroundColor Red
        return
    }
    
    Write-SectionHeader "Traceroute to '$Target'" "🛤️"
    Write-Host "Tracing route (max 30 hops)..." -ForegroundColor Gray
    
    try {
        $result = tracert $Target
        foreach ($line in $result) {
            if ($line -match '^\s*(\d+)') {
                Write-Host $line -ForegroundColor White
            } elseif ($line -match 'Tracing route' -or $line -match 'over a maximum') {
                Write-Host $line -ForegroundColor Cyan
            } else {
                Write-Host $line -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "$(Get-NetworkIcon 'error') Traceroute failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-WhoAmI {
    Write-SectionHeader "Detailed Public IP Information" "👤"
    
    try {
        Write-Host "Fetching detailed information..." -ForegroundColor Gray
        $ipInfo = Invoke-RestMethod -Uri "http://ipinfo.io/json" -UseBasicParsing -TimeoutSec 10
        
        Write-Host "IP Address : " -NoNewline -ForegroundColor Green
        Write-Host $ipInfo.ip
        Write-Host "Location   : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($ipInfo.city), $($ipInfo.region), $($ipInfo.country)"
        Write-Host "Coordinates: " -NoNewline -ForegroundColor Cyan
        Write-Host $ipInfo.loc
        Write-Host "ISP        : " -NoNewline -ForegroundColor Magenta
        Write-Host $ipInfo.org
        Write-Host "Timezone   : " -NoNewline -ForegroundColor Blue
        Write-Host $ipInfo.timezone
        
        if ($ipInfo.postal) {
            Write-Host "Postal Code: " -NoNewline -ForegroundColor DarkYellow
            Write-Host $ipInfo.postal
        }
        
    } catch {
        Write-Host "$(Get-NetworkIcon 'error') Could not fetch detailed IP information: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-BasicConnectivity {
    Write-SectionHeader "Connectivity Test" "📡"
    
    $targets = @(
        @{Name="Google DNS"; Host="8.8.8.8"},
        @{Name="Cloudflare DNS"; Host="1.1.1.1"},
        @{Name="Google"; Host="google.com"}
    )
    
    foreach ($target in $targets) {
        Write-Host "Testing $($target.Name) ($($target.Host))... " -NoNewline -ForegroundColor Gray
        
        $ping = Test-Connection -ComputerName $target.Host -Count 2 -ErrorAction SilentlyContinue
        if ($ping) {
            $avgTime = ($ping | Measure-Object -Property ResponseTime -Average).Average
            $message = "$(Get-NetworkIcon 'success') {0:N0} ms" -f $avgTime
            Write-Host $message -ForegroundColor Green
        } else {
            Write-Host "$(Get-NetworkIcon 'error') Failed" -ForegroundColor Red
        }
    }
}

# Main execution logic
$helpArgs = @("-h", "--h", "help", "-help", "--help")
if ($Arguments.Count -eq 0 -or $helpArgs -contains $Arguments[0]) {
    $isSmall = $Arguments -contains "--small"
    Show-Help -isSmall $isSmall
    return
}

$ipArgs = @('ip', '--ip', '-ip')
$speedArgs = @('speed', '--speed', '-speed')
$dnsArgs = @('dns', '--dns', '-dns')
$traceArgs = @('trace', '--trace', '-trace')
$whoamiArgs = @('whoami', '--whoami', '-whoami')
$allArgs = @('all', '--all', '-all', '-a', '--a')

# Handle positional arguments
if ($Arguments.Count -gt 0) {
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i].ToLower()
        switch ($arg) {
            { $ipArgs -contains $_ } { $Ip = $true; continue }
            { $speedArgs -contains $_ } { $Speed = $true; continue }
            { $dnsArgs -contains $_ } { $Dns = $true; $Target = if ($Arguments.Count -gt ($i + 1)) { $Arguments[$i + 1] } else { "" }; continue }
            { $traceArgs -contains $_ } { $Trace = $true; $Target = if ($Arguments.Count -gt ($i + 1)) { $Arguments[$i + 1] } else { "" }; continue }
            { $whoamiArgs -contains $_ } { $WhoAmI = $true; continue }
            { $allArgs -contains $_ } { $All = $true; continue }
            default { continue }
        }
    }
}

if ($Ip) {
    Get-LocalIP
    $publicIp = Get-PublicIP
}

if ($Speed) {
    Test-InternetSpeed
}

if ($Dns) {
    Resolve-DnsLookup -Domain $Target
}

if ($Trace) {
    Start-Traceroute -Target $Target
}

if ($WhoAmI) {
    Get-WhoAmI
}

if ($All) {
    Get-LocalIP
    $publicIp = Get-PublicIP
    Test-BasicConnectivity
    Test-InternetSpeed
    Get-WhoAmI
}

Write-Host ""