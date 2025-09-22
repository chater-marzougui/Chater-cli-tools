function Test-DownloadSpeed {
    param(
        [int]$ThreadCount = 4,
        [int]$ChunkSize = 8MB,
        [int]$TimeoutSec = 60
    )
    
    try {
        # Use a large file URL that we can stream from
        $testUrl = "https://speed.cloudflare.com/__down?bytes=1000000000"  # 1GB max
        $testDuration = 15  # Fixed 15 second test duration
        
        # Create script block for parallel downloads with time-based measurement
        $downloadScript = {
            param($Url, $TestDuration, $ThreadId)
            
            try {
                $ProgressPreference = 'SilentlyContinue'
                
                # Create WebClient for streaming download
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell-SpeedTest/1.0")
                
                $totalBytes = 0
                $startTime = Get-Date
                $buffer = New-Object byte[] 32768  # 32KB buffer
                
                try {
                    $stream = $webClient.OpenRead($Url)
                    
                    while (((Get-Date) - $startTime).TotalSeconds -lt $TestDuration) {
                        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
                        
                        if ($bytesRead -eq 0) {
                            # Stream ended, break out
                            break
                        }
                        
                        $totalBytes += $bytesRead
                    }
                    
                    $stream.Close()
                } catch {
                    # If streaming fails, fall back to chunked downloads
                    $stream = $null
                    
                    while (((Get-Date) - $startTime).TotalSeconds -lt $TestDuration) {
                        try {
                            $chunkUrl = $Url + "&t=" + (Get-Date).Ticks
                            $response = Invoke-WebRequest -Uri $chunkUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                            $totalBytes += $response.RawContentLength
                        } catch {
                            Start-Sleep -Milliseconds 100
                        }
                    }
                }
                
                $actualDuration = ((Get-Date) - $startTime).TotalSeconds
                $webClient.Dispose()
                
                return @{
                    Success = $true
                    Bytes = $totalBytes
                    Duration = $actualDuration
                    ThreadId = $ThreadId
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
            $job = Start-Job -ScriptBlock $downloadScript -ArgumentList $testUrl, $testDuration, $i
            $jobs += $job
        }
        
        # Wait for jobs with progress indicator
        $loadingStates = @('-', '\', '|', '/')
        $loadingIndex = 0
        $startTime = Get-Date
        $testEndTime = $startTime.AddSeconds($testDuration + 5)  # Extra 5s for cleanup

        Write-Host "Testing download speed..." -ForegroundColor Cyan
        
        while (($jobs | Where-Object { $_.State -eq 'Running' }) -and (Get-Date) -lt $testEndTime) {
            $loadingChar = $loadingStates[$loadingIndex % $loadingStates.Count]
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
            Write-Host -NoNewline "`r$loadingChar Testing... ${elapsed}s"
            Start-Sleep -Milliseconds 200
            $loadingIndex++
        }
        
        # Force stop any running jobs
        $jobs | Where-Object { $_.State -eq 'Running' } | Remove-Job -Force -ErrorAction SilentlyContinue
        Write-Host "`r                    `r" -NoNewline
        
        # Collect results
        $results = @()
        $totalBytes = 0
        $successCount = 0
        $completed = $jobs | Where-Object { $_.State -eq 'Completed' }

        foreach ($job in $completed) {
            try {
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                
                if ($result -and $result.Success -and $result.Bytes -gt 0) {
                    $results += $result
                    $totalBytes += $result.Bytes
                    $successCount++
                    $threadSpeed = (($result.Bytes * 8) / ($result.Duration * 1MB))
                    $threadMessage = "  Thread $($result.ThreadId + 1): {0:N2} MB in {1:N2}s ({2:N1} Mbps)" -f ($result.Bytes/1MB), $result.Duration, $threadSpeed
                    Write-Host $threadMessage -ForegroundColor DarkGreen
                } else {
                    $errorMsg = if ($result) { $result.Error } else { "No data received" }
                    Write-Host "  Thread $($result.ThreadId + 1) failed: $errorMsg" -ForegroundColor DarkRed
                }
            } catch {
                Write-Host "  Thread error: $($_.Exception.Message)" -ForegroundColor DarkRed
            } finally {
                if ($job -and (Get-Job -Id $job.Id -ErrorAction SilentlyContinue)) {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        if ($successCount -gt 0) {
            # Calculate speeds based on actual data transferred
            $threadSpeeds = $results | ForEach-Object { (($_.Bytes * 8) / ($_.Duration * 1MB)) }
            $avgSpeed = ($threadSpeeds | Measure-Object -Average).Average
            $peakSpeed = ($threadSpeeds | Measure-Object -Maximum).Maximum
            
            # Total throughput is sum of all thread speeds (parallel download)
            $totalThroughput = ($threadSpeeds | Measure-Object -Sum).Sum

            Write-Host ""
            Write-Host ("{0} Download Speed: {1:N2} Mbps | {2:N2} Mbps avg/thread | {3:N2} Mbps peak/thread" -f (Get-NetworkIcon 'success'), $totalThroughput, $avgSpeed, $peakSpeed) -ForegroundColor Green

            $dataMessage = "  Total data: {0:N2} MB across $successCount threads in ~15s" -f ($totalBytes/1MB)
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
                # Silent cleanup
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
        $uploadUrl = "https://speed.cloudflare.com/__up"
        $testDuration = 15  # Fixed 15 second test duration
        
        # Create script block for parallel uploads with time-based measurement
        $uploadScript = {
            param($UploadUrl, $ChunkSize, $TestDuration, $ThreadId)
            
            try {
                $ProgressPreference = 'SilentlyContinue'
                
                $totalBytes = 0
                $startTime = Get-Date
                
                # Create reusable upload data
                $uploadData = New-Object byte[] $ChunkSize
                (New-Object System.Random).NextBytes($uploadData)
                
                while (((Get-Date) - $startTime).TotalSeconds -lt $TestDuration) {
                    try {
                        $chunkStartTime = Get-Date
                        $response = Invoke-WebRequest -Uri $UploadUrl -Method Post -Body $uploadData -ContentType "application/octet-stream" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                        
                        if ($response.StatusCode -eq 200) {
                            $totalBytes += $ChunkSize
                        }
                        
                        # Small delay to prevent overwhelming the server
                        Start-Sleep -Milliseconds 50
                        
                    } catch {
                        # If upload fails, wait a bit and try again
                        Start-Sleep -Milliseconds 200
                        
                        # Check if we still have time
                        if (((Get-Date) - $startTime).TotalSeconds -ge $TestDuration) {
                            break
                        }
                    }
                }
                
                $actualDuration = ((Get-Date) - $startTime).TotalSeconds
                
                return @{
                    Success = $true
                    Bytes = $totalBytes
                    Duration = $actualDuration
                    ThreadId = $ThreadId
                    Endpoint = $UploadUrl
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
            $job = Start-Job -ScriptBlock $uploadScript -ArgumentList $uploadUrl, $ChunkSize, $testDuration, $i
            $jobs += $job
        }
        
        # Wait for jobs with progress indicator
        $loadingStates = @('-', '\', '|', '/')
        $loadingIndex = 0
        $startTime = Get-Date
        $testEndTime = $startTime.AddSeconds($testDuration + 5)  # Extra 5s for cleanup

        Write-Host "Testing upload speed..." -ForegroundColor Cyan
        
        while (($jobs | Where-Object { $_.State -eq 'Running' }) -and (Get-Date) -lt $testEndTime) {
            $loadingChar = $loadingStates[$loadingIndex % $loadingStates.Count]
            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
            Write-Host -NoNewline "`r$loadingChar Testing... ${elapsed}s"
            Start-Sleep -Milliseconds 200
            $loadingIndex++
        }
        
        # Force stop any running jobs
        $jobs | Where-Object { $_.State -eq 'Running' } | Remove-Job -Force -ErrorAction SilentlyContinue
        Write-Host "`r                    `r" -NoNewline
        
        # Collect results
        $results = @()
        $totalBytes = 0
        $successCount = 0
        $completed = $jobs | Where-Object { $_.State -eq 'Completed' }

        foreach ($job in $completed) {
            try {
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                
                if ($result -and $result.Success -and $result.Bytes -gt 0) {
                    $results += $result
                    $totalBytes += $result.Bytes
                    $successCount++
                    $threadSpeed = (($result.Bytes * 8) / ($result.Duration * 1MB))
                    $threadMessage = "  Thread $($result.ThreadId + 1): {0:N2} MB in {1:N2}s ({2:N1} Mbps)" -f ($result.Bytes/1MB), $result.Duration, $threadSpeed
                    Write-Host $threadMessage -ForegroundColor DarkBlue
                } else {
                    $errorMsg = if ($result) { $result.Error } else { "No data uploaded" }
                    Write-Host "  Upload thread $($result.ThreadId + 1) failed: $errorMsg" -ForegroundColor DarkRed
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
            # Calculate speeds based on actual data transferred
            $threadSpeeds = $results | ForEach-Object { (($_.Bytes * 8) / ($_.Duration * 1MB)) }
            $avgSpeed = ($threadSpeeds | Measure-Object -Average).Average
            $peakSpeed = ($threadSpeeds | Measure-Object -Maximum).Maximum
            
            # Total throughput is sum of all thread speeds (parallel upload)
            $totalThroughput = ($threadSpeeds | Measure-Object -Sum).Sum

            Write-Host ""
            $uploadMessage = "$(Get-NetworkIcon 'success') Upload Speed: {0:N2} Mbps | {1:N2} Mbps avg/thread | {2:N2} Mbps peak/thread" -f $totalThroughput, $avgSpeed, $peakSpeed
            Write-Host $uploadMessage -ForegroundColor Blue
            
            $dataMessage = "  Total data: {0:N2} MB across $successCount threads in ~15s" -f ($totalBytes/1MB)
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
        # Clean up remaining jobs
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
