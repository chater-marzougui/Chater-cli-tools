# Network Utilities for Chater-CLI Tools

# Import Core Utils if not already present
if (-not (Get-Command "Show-Header" -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\Utils.ps1"
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
        Write-Error "Could not retrieve local IPv4."
        return $null
    }
}

function Get-PublicIP {
    try {
        Write-Info "Checking public IP..."
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -UseBasicParsing -TimeoutSec 10
        return $publicIP.ip
    } catch {
        try {
            $publicIP6 = Invoke-RestMethod -Uri "https://api64.ipify.org?format=json" -UseBasicParsing -TimeoutSec 10
            return $publicIP6.ip
        } catch {
            Write-Error "Could not fetch public IP."
            return $null
        }
    }
}
