# Node.js + Express + TypeScript Backend Setup Script
# Author: Assistant
# Description: Automatically sets up a modern Node.js backend with Express and TypeScript

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName
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

# Step 1: Create project directory and initialize
Write-Step "Creating project: $ProjectName"
try {
    if (Test-Path $ProjectName) {
        Write-Error "Directory $ProjectName already exists"
        exit 1
    }
    
    New-Item -ItemType Directory -Name $ProjectName
    Set-Location $ProjectName
    
    npm init -y
    if ($LASTEXITCODE -ne 0) { throw "Failed to initialize npm project" }
    Write-Success "Project initialized successfully"
} catch {
    Write-Error "Failed to create project: $_"
    exit 1
}

# Step 2: Install production dependencies
Write-Step "Installing production dependencies..."
try {
    npm install express dotenv
    npm install -D tsx
    if ($LASTEXITCODE -ne 0) { throw "Failed to install production dependencies" }
    Write-Success "Production dependencies installed"
} catch {
    Write-Error "Failed to install production dependencies: $_"
    exit 1
}

# Step 3: Install development dependencies
Write-Step "Installing development dependencies..."
try {
    npm install -D typescript ts-node @types/node @types/express nodemon eslint prettier @typescript-eslint/parser @typescript-eslint/eslint-plugin eslint-config-prettier
    if ($LASTEXITCODE -ne 0) { throw "Failed to install development dependencies" }
    Write-Success "Development dependencies installed"
} catch {
    Write-Error "Failed to install development dependencies: $_"
    exit 1
}

# Step 4: Create project structure
Write-Step "Creating project structure..."
try {
    $folders = @("src", "src/config", "src/controllers", "src/middlewares", "src/models", "src/routes")
    foreach ($folder in $folders) {
        New-Item -ItemType Directory -Path $folder -Force
    }
    Write-Success "Project structure created"
} catch {
    Write-Error "Failed to create project structure: $_"
    exit 1
}

# Step 5: Generate TypeScript configuration
Write-Step "Generating TypeScript configuration..."
try {
    npx tsc --init
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate tsconfig.json" }
    
    # Update tsconfig.json with custom configuration
    $tsConfig = @'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
'@
    $tsConfig | Out-File -FilePath "tsconfig.json" -Encoding UTF8
    Write-Success "TypeScript configuration updated"
} catch {
    Write-Error "Failed to generate TypeScript configuration: $_"
    exit 1
}

# Step 6: Create environment configuration
Write-Step "Creating environment configuration..."
try {
    $configContent = @'
import dotenv from 'dotenv';

dotenv.config();

interface Config {
  port: number;
  nodeEnv: string;
}

const config: Config = {
  port: Number(process.env.PORT) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
};

export default config;
'@
    $configContent | Out-File -FilePath "src/config/config.ts" -Encoding UTF8
    
    # Create .env file
    $envContent = @"
PORT=3000
NODE_ENV=development
"@
    $envContent | Out-File -FilePath ".env" -Encoding UTF8
    Write-Success "Environment configuration created"
} catch {
    Write-Error "Failed to create environment configuration: $_"
    exit 1
}

# Step 7: Create Item model
Write-Step "Creating Item model..."
try {
    $modelContent = @'
export interface Item {
  id: number;
  name: string;
}

export let items: Item[] = [];
'@
    $modelContent | Out-File -FilePath "src/models/item.ts" -Encoding UTF8
    Write-Success "Item model created"
} catch {
    Write-Error "Failed to create Item model: $_"
    exit 1
}

# Step 8: Create Item controller
Write-Step "Creating Item controller..."
try {
    $controllerContent = @'
import { Request, Response, NextFunction } from 'express';
import { items, Item } from '../models/item';

// Create an item
export const createItem = (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name } = req.body;
    const newItem: Item = { id: Date.now(), name };
    items.push(newItem);
    res.status(201).json(newItem);
  } catch (error) {
    next(error);
  }
};

// Read all items
export const getItems = (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(items);
  } catch (error) {
    next(error);
  }
};

// Read single item
export const getItemById = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = parseInt(req.params.id, 10);
    const item = items.find((i) => i.id === id);
    if (!item) {
      res.status(404).json({ message: 'Item not found' });
      return;
    }
    res.json(item);
  } catch (error) {
    next(error);
  }
};

// Update an item
export const updateItem = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { name } = req.body;
    const itemIndex = items.findIndex((i) => i.id === id);
    if (itemIndex === -1) {
      res.status(404).json({ message: 'Item not found' });
      return;
    }
    items[itemIndex].name = name;
    res.json(items[itemIndex]);
  } catch (error) {
    next(error);
  }
};

// Delete an item
export const deleteItem = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = parseInt(req.params.id, 10);
    const itemIndex = items.findIndex((i) => i.id === id);
    if (itemIndex === -1) {
      res.status(404).json({ message: 'Item not found' });
      return;
    }
    const deletedItem = items.splice(itemIndex, 1)[0];
    res.json(deletedItem);
  } catch (error) {
    next(error);
  }
};
'@
    $controllerContent | Out-File -FilePath "src/controllers/itemController.ts" -Encoding UTF8
    Write-Success "Item controller created"
} catch {
    Write-Error "Failed to create Item controller: $_"
    exit 1
}

# Step 9: Create Item routes
Write-Step "Creating Item routes..."
try {
    $routesContent = @'
import { Router } from 'express';
import {
  createItem,
  getItems,
  getItemById,
  updateItem,
  deleteItem,
} from '../controllers/itemController';

const router = Router();

router.get('/', getItems);
router.get('/:id', getItemById);
router.post('/', createItem);
router.put('/:id', updateItem);
router.delete('/:id', deleteItem);

export default router;
'@
    $routesContent | Out-File -FilePath "src/routes/itemRoutes.ts" -Encoding UTF8
    Write-Success "Item routes created"
} catch {
    Write-Error "Failed to create Item routes: $_"
    exit 1
}

# Step 10: Create error handler middleware
Write-Step "Creating error handler middleware..."
try {
    $errorHandlerContent = @'
import { Request, Response, NextFunction } from 'express';

export interface AppError extends Error {
  status?: number;
}

export const errorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.error(err);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
  });
};
'@
    $errorHandlerContent | Out-File -FilePath "src/middlewares/errorHandler.ts" -Encoding UTF8
    Write-Success "Error handler middleware created"
} catch {
    Write-Error "Failed to create error handler middleware: $_"
    exit 1
}

# Step 11: Create Express app configuration
Write-Step "Creating Express app configuration..."
try {
    $appContent = @'
import express from 'express';
import itemRoutes from './routes/itemRoutes';
import { errorHandler } from './middlewares/errorHandler';

const app = express();

app.use(express.json());

// Routes
app.use('/api/items', itemRoutes);

app.get('/', (req, res) => {
    res.send('{"message": "Healthy"}');
});

// Global error handler (should be after routes)
app.use(errorHandler);

export default app;
'@
    $appContent | Out-File -FilePath "src/app.ts" -Encoding UTF8
    Write-Success "Express app configuration created"
} catch {
    Write-Error "Failed to create Express app configuration: $_"
    exit 1
}

# Step 12: Create server entry point
Write-Step "Creating server entry point..."
try {
    $serverContent = @'
import app from './app';
import config from './config/config';

app.listen(config.port, () => {
  console.log(`Server running on port ${config.port}`);
});
'@
    $serverContent | Out-File -FilePath "src/server.ts" -Encoding UTF8
    Write-Success "Server entry point created"
} catch {
    Write-Error "Failed to create server entry point: $_"
    exit 1
}

# Step 13: Create ESLint configuration
Write-Step "Creating ESLint configuration..."
try {
    $eslintConfig = @'
module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'prettier',
  ],
  env: {
    node: true,
    es6: true,
  },
};
'@
    $eslintConfig | Out-File -FilePath ".eslintrc.js" -Encoding UTF8
    Write-Success "ESLint configuration created"
} catch {
    Write-Error "Failed to create ESLint configuration: $_"
    exit 1
}

# Step 14: Create Prettier configuration
Write-Step "Creating Prettier configuration..."
try {
    $prettierConfig = @'
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all"
}
'@
    $prettierConfig | Out-File -FilePath ".prettierrc" -Encoding UTF8
    Write-Success "Prettier configuration created"
} catch {
    Write-Error "Failed to create Prettier configuration: $_"
    exit 1
}

# Step 15: Update package.json scripts
Write-Step "Updating package.json scripts..."
try {
    $packageJsonContent = Get-Content "package.json" -Raw | ConvertFrom-Json
    
    $packageJsonContent.scripts = @{
        "build" = "tsc"
        "start" = "node dist/server.js"
        "dev" = 'nodemon --watch src --ext ts --exec \"npx tsx src/server.ts\"'
        "lint" = "eslint 'src/**/*.ts'"
        "format" = "prettier --write 'src/**/*.ts'"
        "test" = "echo `"Error: no test specified`" && exit 1"
    }
    
    $packageJsonContent | ConvertTo-Json -Depth 10 | Out-File -FilePath "package.json" -Encoding UTF8
    Write-Success "Package.json scripts updated"
} catch {
    Write-Error "Failed to update package.json scripts: $_"
    exit 1
}

# Step 16: Create .gitignore
Write-Step "Creating .gitignore..."
try {
    $gitignoreContent = @'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Production builds
dist/
build/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
*.lcov

# ESLint cache
.eslintcache
'@
    $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding UTF8
    Write-Success ".gitignore created"
} catch {
    Write-Error "Failed to create .gitignore: $_"
    exit 1
}

# Step 17: Create README.md
Write-Step "Creating README.md..."
try {
    $readmeContent = @"
# $ProjectName

A Node.js backend API built with Express, TypeScript, and modern development tools.

## Features

- 🚀 **Express.js** - Fast, minimalist web framework
- 📝 **TypeScript** - Type-safe JavaScript development
- 🔧 **Hot Reload** - Automatic server restart with nodemon
- 🛡️ **Error Handling** - Global error handling middleware
- 📦 **Environment Config** - Typed environment variables
- 🎯 **ESLint & Prettier** - Code linting and formatting
- 📁 **Organized Structure** - Clean project architecture

## Getting Started

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn

### Installation

1. Navigate to the project directory:
   \`\`\`bash
   cd $ProjectName
   \`\`\`

2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

3. Start the development server:
   \`\`\`bash
   npm run dev
   \`\`\`

The server will start on http://localhost:3000

## Available Scripts

- \`npm run dev\` - Start development server with hot reload
- \`npm run build\` - Build the project for production
- \`npm start\` - Start the production server
- \`npm run lint\` - Run ESLint
- \`npm run format\` - Format code with Prettier

## API Endpoints

### Items

- \`GET /api/items\` - Get all items
- \`GET /api/items/:id\` - Get item by ID
- \`POST /api/items\` - Create new item
- \`PUT /api/items/:id\` - Update item
- \`DELETE /api/items/:id\` - Delete item

### Example Usage

\`\`\`bash
# Get all items
curl http://localhost:3000/api/items

# Create a new item
curl -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Sample Item"}'

# Get item by ID
curl http://localhost:3000/api/items/1

# Update item
curl -X PUT http://localhost:3000/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Item"}'

# Delete item
curl -X DELETE http://localhost:3000/api/items/1
\`\`\`

## Project Structure

\`\`\`
$ProjectName/
├── src/
│   ├── config/
│   │   └── config.ts        # Environment configuration
│   ├── controllers/
│   │   └── itemController.ts # Business logic
│   ├── middlewares/
│   │   └── errorHandler.ts   # Error handling
│   ├── models/
│   │   └── item.ts          # Data models
│   ├── routes/
│   │   └── itemRoutes.ts    # API routes
│   ├── app.ts               # Express app setup
│   └── server.ts            # Server entry point
├── .env                     # Environment variables
├── .eslintrc.js            # ESLint configuration
├── .prettierrc             # Prettier configuration
├── tsconfig.json           # TypeScript configuration
└── package.json            # Dependencies and scripts
\`\`\`

## Environment Variables

Create a \`.env\` file in the root directory:

\`\`\`env
PORT=3000
NODE_ENV=development
\`\`\`

## Contributing

1. Fork the repository
2. Create your feature branch (\`git checkout -b feature/amazing-feature\`)
3. Commit your changes (\`git commit -m 'Add some amazing feature'\`)
4. Push to the branch (\`git push origin feature/amazing-feature\`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.
"@
    $readmeContent | Out-File -FilePath "README.md" -Encoding UTF8
    Write-Success "README.md created"
} catch {
    Write-Error "Failed to create README.md: $_"
    exit 1
}

# Final success message
Write-Host ""
Write-Host "🎉 Backend project setup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To start your backend server:" -ForegroundColor Yellow
Write-Host "  cd $ProjectName" -ForegroundColor Cyan
Write-Host "  npm run dev" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your API will be available at:" -ForegroundColor Yellow
Write-Host "  http://localhost:3000/api/items" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available commands:" -ForegroundColor Yellow
Write-Host "  npm run dev      # Start development server" -ForegroundColor Cyan
Write-Host "  npm run build    # Build for production" -ForegroundColor Cyan
Write-Host "  npm start        # Start production server" -ForegroundColor Cyan
Write-Host "  npm run lint     # Run ESLint" -ForegroundColor Cyan
Write-Host "  npm run format   # Format code with Prettier" -ForegroundColor Cyan
Write-Host ""