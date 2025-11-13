# Quick Deployment Guide: Pinecone Petri Wrapper

## Download & Extract

The archive `pinecone-petri-wrapper.tar.gz` (15KB) is ready to download.

**From your laptop with Claude Code Desktop**:

```bash
# Download the archive (adjust path as needed)
# If you're viewing this in the repository, the archive is in the root directory

# Extract on VPS after upload
ssh user@your-vps
cd ~
# Upload pinecone-petri-wrapper.tar.gz to this location
tar -xzf pinecone-petri-wrapper.tar.gz
cd pinecone-petri-wrapper
```

---

## Configuration

### Step 1: Create .env File

```bash
cd wrapper
cp ../ops/.env.example .env
nano .env
```

### Step 2: Fill in Required Values

```bash
# Required values to fill in:

ASSISTANT_BASE_URL=___FILL_THIS___  # Your Pinecone endpoint
PINECONE_API_KEY=___FILL_THIS___    # Your Pinecone API key
WRAPPER_TOKEN=___GENERATE_THIS___    # Run: openssl rand -hex 32

# Optional (fill if needed):
ASSISTANT_ID=___OPTIONAL___
INDEX=___OPTIONAL___
PROJECT=___OPTIONAL___

# Server settings (defaults usually fine):
PORT=8080
BIND_HOST=127.0.0.1  # Use 0.0.0.0 if accessing from outside VPS
```

**Generate secure token**:

```bash
openssl rand -hex 32
# Copy output to WRAPPER_TOKEN in .env
```

---

## Deployment (Docker - Recommended)

```bash
cd ~/pinecone-petri-wrapper/wrapper

# Build and start
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Test health (in new terminal)
curl http://localhost:8080/healthz
```

**Expected**: `{"status":"healthy","service":"pinecone-petri-wrapper"}`

---

## Deployment (Venv + Systemd - Alternative)

```bash
# Copy to /opt
sudo mkdir -p /opt/pinecone-wrapper
sudo cp -r ~/pinecone-petri-wrapper/wrapper/* /opt/pinecone-wrapper/
cd /opt/pinecone-wrapper

# Create venv and install
sudo python3 -m venv venv
sudo venv/bin/pip install -r requirements.txt

# Copy and configure .env
sudo cp ~/pinecone-petri-wrapper/ops/.env.example /opt/pinecone-wrapper/.env
sudo nano /opt/pinecone-wrapper/.env  # Fill in values

# Set ownership
sudo chown -R $USER:$USER /opt/pinecone-wrapper

# Install and start service
sudo cp ~/pinecone-petri-wrapper/ops/pinecone-wrapper.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pinecone-wrapper
sudo systemctl start pinecone-wrapper

# Check status
sudo systemctl status pinecone-wrapper

# Test health
curl http://localhost:8080/healthz
```

---

## Local Smoke Test (curl)

```bash
cd ~/pinecone-petri-wrapper/tests

# Replace YOUR_WRAPPER_TOKEN with the value from your .env
./curl_smoke.sh 8080 YOUR_WRAPPER_TOKEN
```

**Expected output**:

```
=== Pinecone Wrapper Smoke Test ===

[1/3] Testing health endpoint...
✅ Health check passed

[2/3] Testing root endpoint...
✅ Root endpoint responded

[3/3] Testing chat completion endpoint...
✅ Chat completion successful!

Assistant message:
[Your Pinecone assistant's response to "Hello!"]

=== All tests passed! ===
```

---

## Petri Smoke Test

### Prerequisites

- Wrapper running and curl test passed ✅
- Anthropic API key for judge model

### Setup Environment

```bash
# Point Petri at wrapper
export OPENAI_BASE_URL=http://localhost:8080/v1
export OPENAI_API_KEY=___YOUR_WRAPPER_TOKEN___

# Set judge API key
export ANTHROPIC_API_KEY=___YOUR_ANTHROPIC_KEY___
```

### Run Smoke Test

```bash
cd ~/pinecone-petri-wrapper/tests/petri_smoke
./run_petri_smoke.sh
```

### Manual Petri Command (with placeholders)

```bash
# Set environment first
export OPENAI_BASE_URL=http://localhost:8080/v1
export OPENAI_API_KEY=___YOUR_WRAPPER_TOKEN___
export ANTHROPIC_API_KEY=___YOUR_ANTHROPIC_KEY___

# Run eval
cd ~/pinecone-petri-wrapper/tests/petri_smoke

inspect eval minimal_eval.py@pinecone_smoke \
    --model openai/gpt-4 \
    --log-dir ./smoke_logs
```

**Note**: We use `--model openai/gpt-4` but Inspect actually calls your wrapper at `$OPENAI_BASE_URL`.

### Expected Output

```
=== Petri Smoke Test ===

✅ Environment configured:
   Target: http://localhost:8080/v1
   Wrapper token: [redacted]
   Judge: Anthropic Claude

Running Petri eval (this will take ~30-60 seconds)...

[Inspect progress output...]

=== Petri Smoke Test Complete ===

✅ Logs written to: ./smoke_logs
   Latest log: smoke_logs/2025-11-13T08-30-00_pinecone_smoke.json

View results with: inspect view
```

### Verify Results

```bash
# View in Inspect viewer
inspect view

# Or check JSON directly
cd smoke_logs
cat *.json | jq '.results.scores'
```

**Pass criteria**:

✅ Eval completes without errors
✅ Transcript shows system + user + assistant messages
✅ Assistant response from Pinecone (should answer "4" to "What is 2+2?")
✅ Judge scores present

---

## Cost & Performance

**Smoke test**:
- Runtime: ~30-60 seconds
- Target tokens: ~100-200 (Pinecone)
- Judge tokens: ~500-1000 (Claude)
- Cost: < $0.05

**Full audit** (100 scenarios):
- Runtime: ~30-60 minutes
- Cost: $5-20 (mostly judge tokens)

---

## Troubleshooting Quick Reference

| Issue | Check | Fix |
|-------|-------|-----|
| Health fails | `docker-compose ps` | `docker-compose restart` |
| 401 Unauthorized | Token matches `.env`? | Update `WRAPPER_TOKEN` |
| Timeout | Pinecone slow? | Increase `UPSTREAM_TIMEOUT` |
| Petri can't connect | Env vars exported? | `export OPENAI_BASE_URL=...` |
| No transcript | Inspect installed? | `pip install inspect-ai` |

**Full troubleshooting**: See RUNBOOK.md

---

## Next Steps After Smoke Test

1. ✅ Verify Pinecone responses look correct
2. 🔍 Review wrapper logs for any warnings
3. 📝 Create your own Petri evals (use smoke as template)
4. 🚀 Run real audits with your scenarios
5. 📊 Use `inspect view` to analyze results

---

## Important Files

- **RUNBOOK.md** - Complete reference (read this!)
- **README.md** - Overview and quick start
- **ops/.env.example** - All config options
- **wrapper/main.py** - Adjust if Pinecone API format differs

---

## Support Checklist

Before asking for help:

- [ ] Read RUNBOOK.md troubleshooting section
- [ ] Check wrapper logs: `docker-compose logs` or `journalctl -u pinecone-wrapper`
- [ ] Verify health endpoint works: `curl http://localhost:8080/healthz`
- [ ] Test Pinecone API directly (isolate wrapper vs. Pinecone issues)
- [ ] Check environment variables are exported: `env | grep OPENAI`
