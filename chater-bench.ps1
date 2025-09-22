param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$functionStartTime = Get-Date

# Help function
function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "Command Benchmark Tool" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Benchmark any command by running it multiple times and measuring execution time."
    Write-Host "  Provides detailed timing statistics including min, max, average, and percentiles."
    Write-Host "  Perfect for performance testing, comparing commands, or measuring optimizations."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-benchmark -n <count> <command>     # Run command N times" -ForegroundColor Green
    Write-Host "  chater-benchmark -n <count> -s <command>  # Run silently (no command output)" -ForegroundColor Green
    Write-Host "  chater-benchmark -n <count> -w <command>  # Warm up with 1 run first" -ForegroundColor Green
    Write-Host "  chater-benchmark -h                       # Show this help message" -ForegroundColor Green
    Write-Host "  chater-benchmark help                     # Show this help message" -ForegroundColor Green
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -n <number>    Number of runs (required)" -ForegroundColor White
    Write-Host "  -s             Silent mode - suppress command output" -ForegroundColor White
    Write-Host "  -w             Warm up - run once before timing starts" -ForegroundColor White
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-benchmark -n 5 `"chater-ask 'what is docker'`"" -ForegroundColor Green
    Write-Host "  chater-benchmark -n 10 `"ping google.com -n 1`"" -ForegroundColor Green
    Write-Host "  chater-benchmark -n 3 -s `"npm run build`"" -ForegroundColor Green
    Write-Host "  chater-benchmark -n 5 -w `"python script.py`"" -ForegroundColor Green
    Write-Host "  chater-benchmark -n 10 `"Get-Process | Where-Object CPU -gt 10`"" -ForegroundColor Green
    Write-Host ""
    Write-Host "OUTPUT:" -ForegroundColor Yellow
    Write-Host "  • Individual run times" -ForegroundColor Gray
    Write-Host "  • Statistical summary (min, max, average, median)" -ForegroundColor Gray
    Write-Host "  • Percentiles (95th, 99th)" -ForegroundColor Gray
    Write-Host "  • Success/failure rate" -ForegroundColor Gray
    Write-Host ""
}

function Format-Duration {
    param([TimeSpan]$Duration)
    
    if ($Duration.TotalMilliseconds -lt 1000) {
        return "$([math]::Round($Duration.TotalMilliseconds, 2)) ms"
    } elseif ($Duration.TotalSeconds -lt 60) {
        return "$([math]::Round($Duration.TotalSeconds, 3)) s"
    } else {
        return "$($Duration.Minutes)m $([math]::Round($Duration.Seconds + $Duration.Milliseconds/1000, 2))s"
    }
}

function Get-Percentile {
    param(
        [double[]]$Values,
        [double]$Percentile
    )
    
    $sorted = $Values | Sort-Object
    $index = ($Percentile / 100) * ($sorted.Count - 1)
    $lower = [math]::Floor($index)
    $upper = [math]::Ceiling($index)
    
    if ($lower -eq $upper) {
        return $sorted[$lower]
    } else {
        $weight = $index - $lower
        return $sorted[$lower] * (1 - $weight) + $sorted[$upper] * $weight
    }
}

function Run_Benchmark {
    param(
        [string]$Command,
        [int]$Iterations,
        [bool]$Silent = $false,
        [bool]$WarmUp = $false
    )
    
    $times = @()
    $successCount = 0
    $failureCount = 0
    
    Write-Host ""
    Write-Host "🚀 Benchmark Configuration" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host "Command: $Command" -ForegroundColor White
    Write-Host "Iterations: $Iterations" -ForegroundColor White
    Write-Host "Silent Mode: $Silent" -ForegroundColor White
    Write-Host "Warm Up: $WarmUp" -ForegroundColor White
    Write-Host ""
    
    # Warm up run
    if ($WarmUp) {
        Write-Host "🔥 Warming up..." -ForegroundColor Yellow
        try {
            if ($Silent) {
                Invoke-Expression $Command | Out-Null 2>&1
            } else {
                Invoke-Expression $Command | Out-Host
            }
            Write-Host "✅ Warm up completed" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Warm up failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Run benchmarks
    Write-Host "⏱️  Starting benchmark runs..." -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 1; $i -le $Iterations; $i++) {
        Write-Host "Run $i/$Iterations" -NoNewline -ForegroundColor Yellow
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $success = $true
        
        try {
            if ($Silent) {
                $null = Invoke-Expression $Command 2>&1
            } else {
                Write-Host " - Output:" -ForegroundColor Gray
                Invoke-Expression $Command | Out-Host
            }
        } catch {
            Write-Host " - ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $success = $false
        }
        
        $stopwatch.Stop()
        $executionTime = $stopwatch.Elapsed
        
        if ($success) {
            $times += $executionTime.TotalMilliseconds
            $successCount++
            $timeStr = Format-Duration -Duration $executionTime
            Write-Host " - ✅ $timeStr" -ForegroundColor Green
        } else {
            $failureCount++
        }
        
        # Small delay between runs to avoid resource contention
        if ($i -lt $Iterations) {
            Start-Sleep -Milliseconds 100
        }
    }
    
    # Calculate statistics
    if ($times.Count -eq 0) {
        Write-Host ""
        Write-Host "❌ All runs failed - no timing data available" -ForegroundColor Red
        return
    }
    
    $minTime = $times | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
    $maxTime = $times | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    $avgTime = $times | Measure-Object -Average | Select-Object -ExpandProperty Average
    $median = Get-Percentile -Values $times -Percentile 50
    $p95 = Get-Percentile -Values $times -Percentile 95
    $p99 = Get-Percentile -Values $times -Percentile 99
    
    # Calculate standard deviation
    $variance = ($times | ForEach-Object { [math]::Pow($_ - $avgTime, 2) } | Measure-Object -Average).Average
    $stdDev = [math]::Sqrt($variance)
    
    # Display results
    Write-Host ""
    Write-Host "📊 Benchmark Results" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    
    # Success/Failure summary
    Write-Host "📈 Execution Summary:" -ForegroundColor Yellow
    Write-Host "  Successful runs: $successCount/$Iterations ($([math]::Round($successCount/$Iterations*100, 1))%)" -ForegroundColor Green
    if ($failureCount -gt 0) {
        Write-Host "  Failed runs: $failureCount/$Iterations ($([math]::Round($failureCount/$Iterations*100, 1))%)" -ForegroundColor Red
    }
    Write-Host ""
    
    # Timing statistics
    Write-Host "⏱️  Timing Statistics:" -ForegroundColor Yellow
    Write-Host "  Fastest:    $(Format-Duration -Duration ([TimeSpan]::FromMilliseconds($minTime)))" -ForegroundColor Green
    Write-Host "  Slowest:    $(Format-Duration -Duration ([TimeSpan]::FromMilliseconds($maxTime)))" -ForegroundColor Red
    Write-Host "  Average:    $(Format-Duration -Duration ([TimeSpan]::FromMilliseconds($avgTime)))" -ForegroundColor White
    Write-Host "  Median:     $(Format-Duration -Duration ([TimeSpan]::FromMilliseconds($median)))" -ForegroundColor White
    Write-Host "  Std Dev:    $(Format-Duration -Duration ([TimeSpan]::FromMilliseconds($stdDev)))" -ForegroundColor Gray
    Write-Host ""
    
    # Percentiles
    Write-Host "📊 Percentiles:" -ForegroundColor Yellow
    Write-Host "  95th percentile: $(Format-Duration -Duration ([TimeSpan]::FromMilliseconds($p95)))" -ForegroundColor White
    Write-Host "  99th percentile: $(Format-Duration -Duration ([TimeSpan]::FromMilliseconds($p99)))" -ForegroundColor White
    Write-Host ""
    
    # Performance assessment
    $coefficient_of_variation = $stdDev / $avgTime
    Write-Host "🎯 Performance Assessment:" -ForegroundColor Yellow
    
    if ($coefficient_of_variation -lt 0.1) {
        Write-Host "  Consistency: Excellent (CV: $([math]::Round($coefficient_of_variation*100, 1))%)" -ForegroundColor Green
    } elseif ($coefficient_of_variation -lt 0.2) {
        Write-Host "  Consistency: Good (CV: $([math]::Round($coefficient_of_variation*100, 1))%)" -ForegroundColor Yellow
    } else {
        Write-Host "  Consistency: Variable (CV: $([math]::Round($coefficient_of_variation*100, 1))%)" -ForegroundColor Red
    }
    
    $slowdown = $maxTime / $minTime
    if ($slowdown -lt 1.5) {
        Write-Host "  Stability: Very stable (max/min ratio: $([math]::Round($slowdown, 2))x)" -ForegroundColor Green
    } elseif ($slowdown -lt 2.5) {
        Write-Host "  Stability: Stable (max/min ratio: $([math]::Round($slowdown, 2))x)" -ForegroundColor Yellow
    } else {
        Write-Host "  Stability: Unstable (max/min ratio: $([math]::Round($slowdown, 2))x)" -ForegroundColor Red
    }
    Write-Host ""
    
    # Individual run times (if <= 20 runs)
    if ($times.Count -le 20) {
        Write-Host "🕐 Individual Run Times:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $times.Count; $i++) {
            $time = Format-Duration -Duration ([TimeSpan]::FromMilliseconds($times[$i]))
            $runNum = ($i + 1).ToString().PadLeft(2)
            Write-Host "  Run $runNum : $time" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

$helpArgs = @("-h", "--h", "help", "-Help")
# Check for help
if ($Arguments.Count -eq 0 -or ($Arguments.Count -le 2 -and ($helpArgs -contains $Arguments[0]))) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Parse arguments
$iterations = 0
$command = ""
$silent = $false
$warmup = $false
$commandParts = @()
$expectingNumber = $false

for ($i = 0; $i -lt $Arguments.Count; $i++) {
    $arg = $Arguments[$i]
    
    if ($expectingNumber) {
        if ($arg -match '^\d+$') {
            $iterations = [int]$arg
            $expectingNumber = $false
        } else {
            Write-Host "❌ Error: Expected number after -n, got '$arg'" -ForegroundColor Red
            return
        }
    } elseif ($arg -eq "-n") {
        $expectingNumber = $true
    } elseif ($arg -eq "-s") {
        $silent = $true
    } elseif ($arg -eq "-w") {
        $warmup = $true
    } else {
        $commandParts += $arg
    }
}

# Validate inputs
if ($iterations -le 0) {
    Write-Host "❌ Error: Number of iterations (-n) is required and must be greater than 0" -ForegroundColor Red
    Write-Host "Usage: chater-benchmark -n <count> <command>" -ForegroundColor Yellow
    return
}

if ($commandParts.Count -eq 0) {
    Write-Host "❌ Error: Command to benchmark is required" -ForegroundColor Red
    Write-Host "Usage: chater-benchmark -n <count> <command>" -ForegroundColor Yellow
    return
}

$command = $commandParts -join " "

if ($iterations -gt 100) {
    Write-Host "⚠️ Warning: Large number of iterations ($iterations). This might take a while..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to cancel if needed." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

try {
    Run_Benchmark -Command $command -Iterations $iterations -Silent $silent -WarmUp $warmup
    
    # Show total timing
    $totalDuration = (Get-Date) - $functionStartTime
    Write-Host "⚡ Total benchmark time: $(Format-Duration -Duration $totalDuration)" -ForegroundColor DarkGray
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
