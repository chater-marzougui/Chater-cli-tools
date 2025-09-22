
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
