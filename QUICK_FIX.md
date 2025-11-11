# Quick Fix for FlagWise lib/utils Error

## TL;DR - Run These Commands

```bash
# SSH into your server
ssh admin@167.235.28.228

# Download and run the fix
curl -o fix-flagwise-utils.sh https://raw.githubusercontent.com/Standivarius/Petri_Flagwise/claude/setup-hetzner-llm-audit-infra-011CV26VJnMsjqHcoAfmS71x/infrastructure/fix-flagwise-utils.sh
chmod +x fix-flagwise-utils.sh
sudo ./fix-flagwise-utils.sh

# Rebuild containers
cd /home/admin/flagwise
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f web

# Test: http://167.235.28.228:3002
```

## What This Does

1. Creates missing `lib/utils.ts` file
2. Installs required dependencies (clsx, tailwind-merge)
3. Fixes import paths in toast.jsx
4. Rebuilds the frontend container

## If You Want to Diagnose First

```bash
ssh admin@167.235.28.228

curl -o diagnose-flagwise.sh https://raw.githubusercontent.com/Standivarius/Petri_Flagwise/claude/setup-hetzner-llm-audit-infra-011CV26VJnMsjqHcoAfmS71x/infrastructure/diagnose-flagwise.sh
chmod +x diagnose-flagwise.sh
sudo ./diagnose-flagwise.sh
```

This will show you exactly what's wrong before applying any fixes.

## Expected Result

After the fix:
- ✅ Web interface loads at http://167.235.28.228:3002
- ✅ No "Cannot find module" errors
- ✅ Toast notifications work properly
- ✅ All containers running

## Root Cause

FlagWise uses shadcn/ui components but is missing the `lib/utils.ts` file that contains the `cn()` classname utility function. This is a common issue when shadcn/ui components are added without running the full initialization.

See `FLAGWISE_ISSUE_DIAGNOSIS.md` for detailed explanation.
