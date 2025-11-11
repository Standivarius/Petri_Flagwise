# Inspect AI (Petri) - LLM Evaluation Framework

This directory contains the Docker configuration for running [Inspect AI](https://github.com/UKGovernmentBEIS/inspect_ai), a framework for large language model evaluations developed by the UK AI Security Institute.

## Overview

Inspect AI is NOT an Anthropic project, but rather a community-driven evaluation framework that supports multiple LLM providers including Anthropic's Claude, OpenAI, and others. The [inspect_evals](https://github.com/UKGovernmentBEIS/inspect_evals) repository contains a collection of community-contributed evaluations.

## What's Included

The cloud-init configuration automatically sets up:

- **Inspect AI Framework**: Latest version from PyPI
- **Inspect Evals**: Community evaluation collection
- **PostgreSQL Database**: For potential custom result storage
- **Docker Container**: Isolated environment with all dependencies
- **Log Storage**: Persistent volume for evaluation results

## Quick Start

### 1. Configure API Keys

After the server is provisioned, SSH in and configure your API keys:

```bash
ssh admin@<SERVER_IP>
sudo nano /opt/inspect-ai/.env.local
```

Add your API keys:

```env
ANTHROPIC_API_KEY=sk-ant-xxxxx
OPENAI_API_KEY=sk-xxxxx
```

Restart the container:

```bash
cd /opt/inspect-ai
sudo docker-compose restart
```

### 2. Run Your First Evaluation

Access the Inspect AI container:

```bash
sudo docker exec -it inspect_ai bash
```

Run a simple evaluation:

```bash
# Test with a basic eval
uv run inspect eval inspect_evals/arc_easy --model anthropic/claude-3-5-sonnet-20241022

# Or with OpenAI
uv run inspect eval inspect_evals/arc_easy --model openai/gpt-4

# Run multiple evals
uv run inspect eval-set inspect_evals/arc_easy inspect_evals/arc_challenge
```

### 3. View Results

View evaluation logs:

```bash
# From within the container
uv run inspect view

# Or access the web viewer
# Open http://<SERVER_IP>:7000 in your browser
```

## Available Evaluations

The `inspect_evals` repository includes numerous evaluations:

- **ARC**: AI2 Reasoning Challenge
- **MMLU**: Massive Multitask Language Understanding
- **HellaSwag**: Commonsense reasoning
- **TruthfulQA**: Truthfulness evaluation
- **And many more...**

List all available evaluations:

```bash
sudo docker exec -it inspect_ai ls -la /app/inspect_evals/
```

## Storage and Logs

### Default Storage (File-Based)

Inspect AI uses file-based storage by default:

- **Logs Directory**: `/opt/inspect-ai/logs` (on host) → `/app/logs` (in container)
- **Format**: JSON/`.eval` files
- **Viewer**: Built-in web viewer accessible at `http://<SERVER_IP>:7000`

### PostgreSQL Database

A PostgreSQL database is provisioned for potential custom storage:

```
Host: localhost (from container: postgres)
Port: 5432
Database: inspect_ai
Username: inspect_user
Password: InspectPass2024!
```

**Note**: Inspect AI does not natively support PostgreSQL for log storage. If you need database storage, you would need to:

1. Create a custom extension using the fsspec API
2. Use the log file API to read results and store them separately
3. Implement a custom storage backend

## Advanced Usage

### Custom Evaluations

Create custom evaluations by adding Python files to `/opt/inspect-ai/evals/`:

```python
# /opt/inspect-ai/evals/my_custom_eval.py
from inspect_ai import Task, task
from inspect_ai.dataset import example_dataset
from inspect_ai.scorer import model_graded_fact
from inspect_ai.solver import generate, system_message

@task
def my_eval():
    return Task(
        dataset=example_dataset("my_dataset"),
        plan=[
            system_message("You are a helpful assistant."),
            generate()
        ],
        scorer=model_graded_fact()
    )
```

Run it:

```bash
sudo docker exec -it inspect_ai uv run inspect eval /app/evals/my_custom_eval.py
```

### Model Configuration

Configure models in `.env.local` or specify via command line:

```bash
# Using environment variable
export INSPECT_EVAL_MODEL=anthropic/claude-3-5-sonnet-20241022
uv run inspect eval inspect_evals/arc_easy

# Or via command line
uv run inspect eval inspect_evals/arc_easy --model anthropic/claude-3-opus-20240229
```

### Batch Evaluations

Run multiple evaluations in parallel:

```bash
# Create a script
cat > /opt/inspect-ai/batch_eval.sh <<'EOF'
#!/bin/bash
uv run inspect eval-set \
  inspect_evals/arc_easy \
  inspect_evals/arc_challenge \
  inspect_evals/hellaswag \
  --model anthropic/claude-3-5-sonnet-20241022 \
  --parallel 3
EOF

chmod +x /opt/inspect-ai/batch_eval.sh
sudo docker exec -it inspect_ai bash /app/batch_eval.sh
```

## Supported Models

Inspect AI supports various model providers:

### Anthropic Claude
```bash
--model anthropic/claude-3-5-sonnet-20241022
--model anthropic/claude-3-opus-20240229
--model anthropic/claude-3-haiku-20240307
```

### OpenAI
```bash
--model openai/gpt-4
--model openai/gpt-4-turbo
--model openai/gpt-3.5-turbo
```

### Others
- HuggingFace models
- Local models
- Custom API endpoints

## Monitoring and Maintenance

### View Logs

```bash
# Container logs
sudo docker logs inspect_ai

# Follow logs in real-time
sudo docker logs -f inspect_ai

# Evaluation logs
sudo docker exec -it inspect_ai ls -la /app/logs/
```

### Container Management

```bash
# Restart
cd /opt/inspect-ai && sudo docker-compose restart

# Rebuild (after code changes)
cd /opt/inspect-ai && sudo docker-compose build --no-cache

# View resource usage
sudo docker stats inspect_ai
```

### Backup Evaluation Results

```bash
# Backup logs directory
sudo tar -czf inspect-logs-backup-$(date +%Y%m%d).tar.gz /opt/inspect-ai/logs/

# Copy to local machine
scp admin@<SERVER_IP>:/home/admin/inspect-logs-backup-*.tar.gz .
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
sudo docker logs inspect_ai

# Check if PostgreSQL is running
sudo docker ps | grep postgres

# Restart everything
cd /opt/inspect-ai
sudo docker-compose down
sudo docker-compose up -d
```

### API Key Issues

```bash
# Verify API key is set
sudo docker exec -it inspect_ai env | grep API_KEY

# Re-add to .env.local
sudo nano /opt/inspect-ai/.env.local

# Restart container
cd /opt/inspect-ai && sudo docker-compose restart
```

### Out of Memory

The cx23 server has 4 GB RAM. For large evaluations, you may need to:

1. Run evaluations sequentially instead of in parallel
2. Upgrade to a larger server type
3. Reduce batch sizes in evaluation configs

## Resources

- **Inspect AI Documentation**: https://inspect.aisi.org.uk/
- **Inspect Evals Repository**: https://github.com/UKGovernmentBEIS/inspect_evals
- **Inspect AI GitHub**: https://github.com/UKGovernmentBEIS/inspect_ai
- **Model Providers Guide**: https://inspect.aisi.org.uk/providers.html
- **Tutorial**: https://inspect.aisi.org.uk/tutorial.html

## Cost Optimization

Remember that LLM API calls can be expensive:

1. Start with small test evaluations
2. Monitor your API usage dashboards
3. Use cheaper models for initial testing (e.g., claude-3-haiku, gpt-3.5-turbo)
4. Estimate costs before running large evaluation sets
5. Set up billing alerts in your API provider accounts

## Next Steps

1. Configure your API keys
2. Run a simple test evaluation
3. Explore the available evaluation sets
4. Create custom evaluations for your specific use case
5. Set up automated evaluation pipelines
6. Integrate with CI/CD for continuous model evaluation
