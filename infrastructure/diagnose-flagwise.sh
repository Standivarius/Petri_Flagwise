#!/bin/bash
set -e

# FlagWise Diagnostic and Repair Script
# Run this on the VPS to diagnose and fix the "Cannot find module '../../lib/utils'" error

echo "=========================================="
echo "FlagWise Diagnostic and Repair Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to FlagWise directory
cd /home/admin/flagwise || { echo "Error: /home/admin/flagwise not found"; exit 1; }

echo -e "${YELLOW}[1/8] Checking repository structure...${NC}"
echo ""
echo "Current directory: $(pwd)"
echo ""
echo "Directory structure:"
ls -la
echo ""

echo -e "${YELLOW}[2/8] Checking for web/frontend directory...${NC}"
if [ -d "web" ]; then
    echo -e "${GREEN}✓ web/ directory found${NC}"
    cd web
elif [ -d "frontend" ]; then
    echo -e "${GREEN}✓ frontend/ directory found${NC}"
    cd frontend
elif [ -d "client" ]; then
    echo -e "${GREEN}✓ client/ directory found${NC}"
    cd client
else
    echo -e "${RED}✗ No web/frontend/client directory found!${NC}"
    echo "Available directories:"
    ls -d */
    exit 1
fi

WEB_DIR=$(pwd)
echo "Web directory: $WEB_DIR"
echo ""

echo -e "${YELLOW}[3/8] Searching for toast.jsx...${NC}"
TOAST_FILE=$(find . -name "toast.jsx" -o -name "toast.tsx" 2>/dev/null | head -1)
if [ -n "$TOAST_FILE" ]; then
    echo -e "${GREEN}✓ Found: $TOAST_FILE${NC}"
    echo ""
    echo "Content of toast file:"
    cat "$TOAST_FILE"
    echo ""
else
    echo -e "${RED}✗ toast.jsx not found${NC}"
fi

echo -e "${YELLOW}[4/8] Checking for lib/utils...${NC}"
if [ -f "lib/utils.js" ]; then
    echo -e "${GREEN}✓ lib/utils.js exists${NC}"
elif [ -f "lib/utils.ts" ]; then
    echo -e "${GREEN}✓ lib/utils.ts exists${NC}"
elif [ -f "src/lib/utils.js" ]; then
    echo -e "${GREEN}✓ src/lib/utils.js exists${NC}"
elif [ -f "src/lib/utils.ts" ]; then
    echo -e "${GREEN}✓ src/lib/utils.ts exists${NC}"
else
    echo -e "${RED}✗ lib/utils not found in expected locations${NC}"
    echo ""
    echo "Searching for utils files..."
    find . -name "utils.js" -o -name "utils.ts" 2>/dev/null
    echo ""
fi

echo -e "${YELLOW}[5/8] Checking package.json...${NC}"
if [ -f "package.json" ]; then
    echo -e "${GREEN}✓ package.json found${NC}"
    echo ""
    echo "Dependencies:"
    cat package.json | grep -A 50 '"dependencies"' | head -60
    echo ""
else
    echo -e "${RED}✗ package.json not found${NC}"
fi

echo -e "${YELLOW}[6/8] Checking Docker containers...${NC}"
cd /home/admin/flagwise
echo ""
docker-compose ps
echo ""

echo -e "${YELLOW}[7/8] Checking web container logs (last 50 lines)...${NC}"
echo ""
docker-compose logs --tail=50 web 2>/dev/null || docker-compose logs --tail=50 frontend 2>/dev/null || echo "Could not find web/frontend container"
echo ""

echo -e "${YELLOW}[8/8] Checking if this is a known issue...${NC}"
echo ""
echo "Checking git repository status:"
git log --oneline -5
echo ""
git status
echo ""

echo "=========================================="
echo "Diagnostic Information Collected"
echo "=========================================="
echo ""
echo -e "${YELLOW}Common solutions:${NC}"
echo ""
echo "1. Missing shadcn/ui utils - Install with:"
echo "   cd $WEB_DIR"
echo "   npx shadcn-ui@latest init"
echo ""
echo "2. Missing lib/utils.ts - Create it manually:"
echo "   mkdir -p $WEB_DIR/lib"
echo "   cat > $WEB_DIR/lib/utils.ts <<'EOF'
import { type ClassValue, clsx } from \"clsx\"
import { twMerge } from \"tailwind-merge\"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
EOF"
echo ""
echo "3. Wrong import path - Fix toast.jsx import:"
echo "   Change: import { cn } from '../../lib/utils'"
echo "   To: import { cn } from '@/lib/utils'"
echo ""
echo "4. Missing dependencies - Install:"
echo "   cd $WEB_DIR"
echo "   npm install clsx tailwind-merge"
echo ""
echo "After applying fix, rebuild:"
echo "   cd /home/admin/flagwise"
echo "   docker-compose down"
echo "   docker-compose build --no-cache web"
echo "   docker-compose up -d"
echo ""
