# Tunnel Utilities for Chater-CLI
# Import dependent utils
if (-not (Get-Command "Show-Header" -ErrorAction SilentlyContinue)) { . "$PSScriptRoot\Utils.ps1" }

function Start-LocalTunnel {
    param($Port, $Subdomain)
    Show-Header "Starting LocalTunnel" "🚇"
    if (-not (Test-Command "lt")) { Write-Error "LocalTunnel (lt) not found."; return }
    
    $args = @("--port", $Port)
    if ($Subdomain) { $args += "--subdomain", $Subdomain }
    
    Write-Info "Press Ctrl+C to stop."
    & npx.cmd lt @args
}

function Start-Ngrok {
    param($Port)
    Show-Header "Starting ngrok" "🔒"
    # Basic ngrok start
    & ngrok http $Port
}

function Start-Serveo {
    param($Port, $Subdomain)
    Show-Header "Starting Serveo" "📡"
    $sshArgs = if ($Subdomain) { "-R", "$Subdomain:80:localhost:$Port", "serveo.net" } else { "-R", "80:localhost:$Port", "serveo.net" }
    ssh @sshArgs
}

function Start-Cloudflare {
    param($Port)
    Show-Header "Starting Cloudflare Tunnel" "☁️"
    if (Test-Command "cloudflared") {
        cloudflared tunnel --url "localhost:$Port"
    } else {
        Write-Error "cloudflared not found."
    }
}
