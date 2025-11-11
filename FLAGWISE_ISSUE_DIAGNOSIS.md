# FlagWise Deployment Issue: Diagnosis and Fix

## Problem Summary

**Error**: `Cannot find module '../../lib/utils'` in `toast.jsx` component
**Location**: http://167.235.28.228:3002
**VPS Path**: `/home/admin/flagwise`
**Ports**: Frontend on 3002, Backend on 8004

## Root Cause Analysis

### What's Happening

FlagWise uses **shadcn/ui** components (a popular React component library). The `toast` component from shadcn/ui requires a utility file (`lib/utils.ts`) that contains helper functions like `cn()` (classname utility).

**The issue**: The FlagWise repository appears to be missing the `lib/utils.ts` file, which is normally created during shadcn/ui initialization.

### Why This Happens

1. **Incomplete shadcn/ui setup**: The repository may not have run `npx shadcn-ui@latest init`
2. **Missing from git**: The `lib/` directory might be gitignored
3. **Build process issue**: The file should be generated during build but isn't
4. **Repository state**: The repo might be in an incomplete/development state

### Evidence from Research

Search of GitHub issues shows this is a common problem with shadcn/ui components:
- shadcn-ui/ui Issue #1101: "Cannot find module '@/lib/utils'"
- shadcn-ui/ui Issue #401: "Toast component missing imports & code"

The issue is NOT specific to FlagWise but rather a common shadcn/ui setup problem.

## Solution

### Option 1: Automated Fix (Recommended)

I've created scripts to diagnose and fix this issue automatically.

**Step 1: SSH into the VPS**
```bash
ssh admin@167.235.28.228
```

**Step 2: Download and run the diagnostic script**
```bash
curl -o diagnose-flagwise.sh https://raw.githubusercontent.com/Standivarius/Petri_Flagwise/claude/setup-hetzner-llm-audit-infra-011CV26VJnMsjqHcoAfmS71x/infrastructure/diagnose-flagwise.sh

chmod +x diagnose-flagwise.sh
sudo ./diagnose-flagwise.sh
```

This will show you:
- Repository structure
- Location of toast.jsx
- Whether lib/utils exists
- Container status and logs
- Suggested fixes

**Step 3: Apply the automated fix**
```bash
curl -o fix-flagwise-utils.sh https://raw.githubusercontent.com/Standivarius/Petri_Flagwise/claude/setup-hetzner-llm-audit-infra-011CV26VJnMsjqHcoAfmS71x/infrastructure/fix-flagwise-utils.sh

chmod +x fix-flagwise-utils.sh
sudo ./fix-flagwise-utils.sh
```

This will:
- Create `lib/utils.ts` with the required `cn()` function
- Install missing dependencies (clsx, tailwind-merge)
- Fix import paths in toast.jsx
- Prepare the project for rebuild

**Step 4: Rebuild containers**
```bash
cd /home/admin/flagwise
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

**Step 5: Verify the fix**
```bash
docker-compose logs -f web
# Then open: http://167.235.28.228:3002
```

### Option 2: Manual Fix

If you prefer to fix it manually:

**1. Create the missing utils file:**
```bash
cd /home/admin/flagwise
# Find the web directory (might be 'web', 'frontend', or 'client')
cd web  # or frontend/client

mkdir -p lib

cat > lib/utils.ts <<'EOF'
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
EOF
```

**2. Install required dependencies:**
```bash
npm install clsx tailwind-merge
```

**3. Fix the import in toast.jsx:**

Find the toast component:
```bash
find . -name "toast.jsx" -o -name "toast.tsx"
```

Edit it and change:
```javascript
// FROM:
import { cn } from '../../lib/utils'

// TO:
import { cn } from '@/lib/utils'
// OR if @ alias isn't configured:
import { cn } from '../lib/utils'
```

**4. Rebuild:**
```bash
cd /home/admin/flagwise
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Option 3: Proper shadcn/ui Initialization

The "proper" way to fix this (if you have time):

```bash
cd /home/admin/flagwise/web  # or frontend
npx shadcn-ui@latest init
```

This will:
- Create the proper directory structure
- Set up path aliases in tsconfig.json/jsconfig.json
- Create lib/utils.ts correctly
- Configure the project properly

Then rebuild as in Option 1.

## Verification Steps

After applying the fix:

1. **Check container status:**
   ```bash
   docker-compose ps
   ```
   All containers should be "Up"

2. **Check logs for errors:**
   ```bash
   docker-compose logs web | grep -i error
   ```
   Should be clean or show minimal errors

3. **Test web interface:**
   Open http://167.235.28.228:3002
   - Should load without module errors
   - Toast notifications should work

4. **Test API:**
   Open http://167.235.28.228:8004/docs
   - Should show FastAPI Swagger UI
   - Endpoints should be accessible

## Why I Can't SSH Directly

**Important**: I (Claude) cannot SSH into your VPS because:
1. SSH requires a private key for authentication
2. Only you have the private key on your local machine
3. I only have the public key (which is used on the server side)
4. This is a security feature - private keys should never be shared

That's why I've created scripts you can download and run instead.

## If the Fix Doesn't Work

If the automated fix fails, provide me with:

1. **Output of diagnostic script:**
   ```bash
   ./diagnose-flagwise.sh > diagnosis.txt 2>&1
   cat diagnosis.txt
   ```

2. **Container logs:**
   ```bash
   docker-compose logs web > web-logs.txt 2>&1
   cat web-logs.txt
   ```

3. **Repository structure:**
   ```bash
   cd /home/admin/flagwise
   tree -L 3 > structure.txt 2>&1
   # or
   find . -type f -name "*.json" -o -name "*.ts" -o -name "*.jsx" | head -50
   ```

With this information, I can provide more specific fixes.

## Alternative: Check Official Repository

The FlagWise repository might have been updated since deployment. Try:

```bash
cd /home/admin/flagwise
git pull origin main  # or master
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

This will pull any fixes the maintainers may have pushed.

## Related Issues

This issue is common with shadcn/ui components:
- **shadcn-ui/ui #1101**: Cannot find module '@/lib/utils'
- **shadcn-ui #401**: Toast component missing imports

The fix I've provided is based on the official shadcn/ui documentation and community solutions.

## Next Steps

1. Run the diagnostic script to confirm the issue
2. Apply the automated fix
3. Rebuild containers
4. Test the web interface
5. If issues persist, collect logs and share them for further diagnosis

## Repository Status

All diagnostic and fix scripts are available in this repository:
- `infrastructure/diagnose-flagwise.sh` - Diagnostic tool
- `infrastructure/fix-flagwise-utils.sh` - Automated fix
- This document - Complete diagnosis and instructions

Branch: `claude/setup-hetzner-llm-audit-infra-011CV26VJnMsjqHcoAfmS71x`
