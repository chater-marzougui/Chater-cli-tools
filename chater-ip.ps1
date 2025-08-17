param(
    [switch]$Help,
    [switch]$All
)

function Show-Help {
    Write-Host "Chater-IP" -ForegroundColor Cyan
    Write-Host "=========" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Show network and IP information (local + public)."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-ip             # Show both local + public IP"
    Write-Host "  chater-ip -all        # Show extended info (DNS, Gateway, MAC, etc.)"
    Write-Host "  chater-ip -h          # Show help"
    Write-Host ""
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
        Write-Host "Local IPv4: " -NoNewline -ForegroundColor Green
        Write-Host $adapter.IPAddress
        Write-Host "Interface : " -NoNewline -ForegroundColor Cyan
        Write-Host $adapter.InterfaceAlias
    } else {
        Write-Host "❌ Could not retrieve local IPv4." -ForegroundColor Red
    }
}

function Get-PublicIP {
    try {
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -UseBasicParsing -TimeoutSec 5
        Write-Host "Public IPv4: " -NoNewline -ForegroundColor Green
        Write-Host $publicIP.ip
    } catch {
        try {
            $publicIP6 = Invoke-RestMethod -Uri "https://api64.ipify.org?format=json" -UseBasicParsing -TimeoutSec 5
            Write-Host "Public IPv6: " -NoNewline -ForegroundColor Green
            Write-Host $publicIP6.ip
        } catch {
            Write-Host "❌ Could not fetch public IP." -ForegroundColor Red
        }
    }
}

function Get-ExtendedInfo {
    Write-Host "`n--- Extended Network Info ---" -ForegroundColor Yellow
    ipconfig /all | Out-String | Write-Host
}

if ($Help) { Show-Help; return }
if ($All) { Get-LocalIP; Get-PublicIP; Get-ExtendedInfo; return }

# Default
Get-LocalIP
Get-PublicIP
