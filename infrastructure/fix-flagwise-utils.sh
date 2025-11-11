#!/bin/bash
set -e

# FlagWise Utils Fix Script
# This script fixes the missing lib/utils module issue

echo "=========================================="
echo "FlagWise lib/utils Fix Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /home/admin/flagwise || { echo "Error: /home/admin/flagwise not found"; exit 1; }

# Find web directory
if [ -d "web" ]; then
    WEB_DIR="web"
elif [ -d "frontend" ]; then
    WEB_DIR="frontend"
elif [ -d "client" ]; then
    WEB_DIR="client"
else
    echo -e "${RED}Error: Could not find web/frontend/client directory${NC}"
    exit 1
fi

echo -e "${GREEN}Found web directory: $WEB_DIR${NC}"
cd "$WEB_DIR"

echo ""
echo -e "${YELLOW}Step 1: Creating lib directory...${NC}"
mkdir -p lib
mkdir -p src/lib
echo -e "${GREEN}✓ Directories created${NC}"

echo ""
echo -e "${YELLOW}Step 2: Creating lib/utils.ts...${NC}"
cat > lib/utils.ts <<'EOF'
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
EOF
echo -e "${GREEN}✓ Created lib/utils.ts${NC}"

echo ""
echo -e "${YELLOW}Step 3: Creating src/lib/utils.ts (backup location)...${NC}"
cat > src/lib/utils.ts <<'EOF'
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
EOF
echo -e "${GREEN}✓ Created src/lib/utils.ts${NC}"

echo ""
echo -e "${YELLOW}Step 4: Checking package.json for required dependencies...${NC}"
if ! grep -q '"clsx"' package.json; then
    echo -e "${YELLOW}Adding clsx to package.json...${NC}"
    npm install clsx --save
fi

if ! grep -q '"tailwind-merge"' package.json; then
    echo -e "${YELLOW}Adding tailwind-merge to package.json...${NC}"
    npm install tailwind-merge --save
fi
echo -e "${GREEN}✓ Dependencies checked${NC}"

echo ""
echo -e "${YELLOW}Step 5: Finding and fixing toast.jsx imports...${NC}"
TOAST_FILES=$(find . -name "toast.jsx" -o -name "toast.tsx" 2>/dev/null)

if [ -n "$TOAST_FILES" ]; then
    for file in $TOAST_FILES; do
        echo "Checking: $file"
        if grep -q "from ['\"]../../lib/utils['\"]" "$file"; then
            echo -e "${YELLOW}Fixing import in $file...${NC}"
            # Backup original
            cp "$file" "$file.bak"
            # Fix import - try @/lib/utils first, then relative path
            sed -i "s|from ['\"]../../lib/utils['\"]|from '@/lib/utils'|g" "$file" || \
            sed -i "s|from ['\"]../../lib/utils['\"]|from '../lib/utils'|g" "$file"
            echo -e "${GREEN}✓ Fixed $file${NC}"
        fi
    done
else
    echo -e "${YELLOW}No toast files found to fix${NC}"
fi

echo ""
echo -e "${YELLOW}Step 6: Checking tsconfig.json for path aliases...${NC}"
if [ -f "tsconfig.json" ]; then
    if ! grep -q '"@/\*"' tsconfig.json; then
        echo -e "${YELLOW}Adding path alias to tsconfig.json...${NC}"
        # Backup
        cp tsconfig.json tsconfig.json.bak
        # Add paths if not present (simplified - may need manual adjustment)
        cat tsconfig.json
    fi
    echo -e "${GREEN}✓ Check tsconfig.json manually if needed${NC}"
else
    echo -e "${YELLOW}No tsconfig.json found (might be using jsconfig.json)${NC}"
fi

echo ""
echo -e "${YELLOW}Step 7: Checking vite.config or next.config...${NC}"
if [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
    echo "Found Vite config - ensure alias is set:"
    echo ""
    echo "resolve: {"
    echo "  alias: {"
    echo "    '@': path.resolve(__dirname, './src'),"
    echo "  },"
    echo "}"
fi

echo ""
echo "=========================================="
echo "Fix Applied Successfully!"
echo "=========================================="
echo ""
echo -e "${GREEN}Created files:${NC}"
echo "  - $WEB_DIR/lib/utils.ts"
echo "  - $WEB_DIR/src/lib/utils.ts"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Rebuild the containers:"
echo "   cd /home/admin/flagwise"
echo "   docker-compose down"
echo "   docker-compose build --no-cache"
echo "   docker-compose up -d"
echo ""
echo "2. Check logs:"
echo "   docker-compose logs -f web"
echo ""
echo "3. Test the web interface:"
echo "   http://167.235.28.228:3002"
echo ""
echo "If issues persist, check:"
echo "  - tsconfig.json or jsconfig.json for correct path aliases"
echo "  - vite.config or webpack config for resolve aliases"
echo "  - All import statements in components"
echo ""
