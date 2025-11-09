# Vite + React + TypeScript + Tailwind + shadcn/ui Setup Script
# Author: Assistant
# Description: Automatically sets up a modern React project with all dependencies

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    [bool]$NoShadcn = $false
)

function Write-Step {
    param([string]$Message)
    Write-Host "📦 $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Check if Node.js is installed
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Success "Node.js found: $nodeVersion"
    } else {
        throw "Node.js not found"
    }
} catch {
    Write-Error "Node.js is not installed. Please install Node.js from https://nodejs.org/"
    exit 1
}

# Check if npm is available
try {
    $npmVersion = npm --version 2>$null
    Write-Success "npm found: $npmVersion"
} catch {
    Write-Error "npm is not available"
    exit 1
}

# Step 1: Create Vite + React + TypeScript project
Write-Step "Creating project: $ProjectName"
try {
    npm create vite@latest $ProjectName -- --template react-ts
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Vite project" }
} catch {
    Write-Error "Failed to create Vite project: $_"
    exit 1
}

# Navigate to project directory
Set-Location $ProjectName

# Step 2: Install dependencies
Write-Step "Installing project dependencies..."
try {
    npm install
    if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies" }
} catch {
    Write-Error "Failed to install dependencies: $_"
    exit 1
}

# Step 3: Install Tailwind CSS
Write-Step "Installing Tailwind CSS..."
try {
    npm install tailwindcss @tailwindcss/vite --save-dev
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Tailwind CSS" }
} catch {
    Write-Error "Failed to install Tailwind CSS: $_"
    exit 1
}

# Step 4: Update Vite config
Write-Step "Updating Vite configuration..."
$viteConfig = @'
import path from "path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
})
'@

try {
    $viteConfig | Out-File -FilePath "vite.config.ts" -Encoding UTF8
} catch {
    Write-Error "Failed to update Vite configuration: $_"
}

# Step 5: Update CSS file
Write-Step "Updating CSS file with Tailwind directives..."
$cssContent = @'
@import 'tailwindcss';
'@

try {
    $cssContent | Out-File -FilePath "src/index.css" -Encoding UTF8
} catch {
    Write-Error "Failed to update CSS file: $_"
}

# Step 5: Install @types/node for path resolution
Write-Step "Installing @types/node..."
try {
    npm install -D @types/node
    if ($LASTEXITCODE -ne 0) { throw "Failed to install @types/node" }
} catch {
    Write-Error "Failed to install @types/node: $_"
    exit 1
}
function Update-TsConfig-Raw {
    param(
        [string]$FilePath
    )
    
    try {
        if (Test-Path $FilePath) {
            $content = Get-Content $FilePath -Raw
            
            # Check if compilerOptions exists
            if ($content -match '"compilerOptions"') {
                # Update baseUrl and paths within compilerOptions
                $content = $content -replace '"baseUrl"\s*:\s*"[^"]*"', '"baseUrl": "./"'
                $content = $content -replace '"paths"\s*:\s*\{[^}]*\}', '"paths": { "@/*": ["./src/*"] }'
                
                # If baseUrl or paths don't exist, add them
                if ($content -notmatch '"baseUrl"') {
                    $content = $content -replace '("compilerOptions"\s*:\s*\{)', '$1"baseUrl": "./",'
                }
                if ($content -notmatch '"paths"') {
                    $content = $content -replace '("compilerOptions"\s*:\s*\{)', '$1"paths": { "@/*": ["./src/*"] },'
                }
            } else {
                # Add compilerOptions section if it doesn't exist
                $content = $content -replace '(\{)', '$1"compilerOptions": {"baseUrl": "./", "paths": { "@/*": ["./src/*"] }},'
            }
            
            # Write back to file
            $content | Out-File -FilePath $FilePath -Encoding UTF8
            Write-Success "$($FilePath) updated using raw method"
        }
    } catch {
        Write-Warning "Raw method failed for $($FilePath): $($_.Exception.Message)"
    }
}

# Try the object-based method first, fall back to raw method if it fails
Update-TsConfig-Raw "tsconfig.json"

Update-TsConfig-Raw "tsconfig.app.json"

if (-not $NoShadcn) {
    # Step 8: Initialize shadcn/ui
    Write-Step "Initializing shadcn/ui..."
    Write-Host ""

    try {
        npx shadcn@latest init
        if ($LASTEXITCODE -ne 0) { 
            Write-Warning "shadcn init may have encountered issues, but continuing..."
        } else {
            Write-Success "shadcn/ui initialized successfully"
        }
    } catch {
        Write-Error "Failed to initialize shadcn/ui: $_"
        exit 1
    }

    # Step 9: Install common shadcn/ui components
    $components = @("button", "card", "input", "label")

    try {
        Write-Host "  Installing components: $($components -join ', ')" -ForegroundColor Cyan
        npx shadcn@latest add $components --yes
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Failed to install some components"
            
            # Fallback: try installing one by one
            Write-Host "  Trying to install components individually..." -ForegroundColor Yellow
            foreach ($component in $components) {
                Write-Host "    Installing $component..." -ForegroundColor Cyan
                npx shadcn@latest add $component --yes
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✅ $component installed" -ForegroundColor Green
                } else {
                    Write-Warning "    Failed to install $component"
                }
            }
        }
    } catch {
        Write-Warning "Failed to install components: $_"
    }

    # Step 10: Create sample App.tsx
    Write-Step "Creating sample App.tsx..."
    $appContent = @"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

function App() {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Welcome to $projectName</CardTitle>
          <CardDescription>
            Vite + React + TypeScript + Tailwind + shadcn/ui
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input id="email" type="email" placeholder="Enter your email" />
          </div>
          <Button className="w-full">Get Started</Button>
        </CardContent>
      </Card>
    </div>
  )
}

export default App
"@

    try {
        $appContent | Out-File -FilePath "src/App.tsx" -Encoding UTF8
        Write-Success "Sample App.tsx created"
    } catch {
        Write-Error "Failed to create App.tsx: $_"
    }
}
# Step 11: Create sample index.html
Write-Step "Creating sample index.html..."
$appContent = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$ProjectName</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
"@

try {
    $appContent | Out-File -FilePath "src/index.html" -Encoding UTF8
    Write-Success "Sample index.html created"
} catch {
    Write-Error "Failed to create index.html: $_"
}

# Final success message
Write-Host ""
Write-Host "🎉 Project setup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To start your project:" -ForegroundColor Yellow
Write-Host "  cd $ProjectName" -ForegroundColor Cyan
Write-Host "  npm run dev" -ForegroundColor Cyan
Write-Host ""
Write-Host "Add more shadcn/ui components with:" -ForegroundColor Yellow
Write-Host "  npx shadcn@latest add [component-name]" -ForegroundColor Cyan
Write-Host ""