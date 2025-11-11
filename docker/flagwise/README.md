# FlagWise - Feature Flag & Network Audit System

This directory contains documentation for deploying [FlagWise](https://github.com/bluewave-labs/flagwise), a feature flag management and network audit system.

## Overview

FlagWise is an open-source feature flag management system with network audit capabilities. It combines:

- **Feature Flag Management**: Toggle features on/off dynamically
- **Network Monitoring**: Audit network traffic and events
- **Detection Rules**: Keyword and regex pattern matching
- **Alert System**: Configurable notifications
- **Role-Based Access Control**: User management and permissions

## Architecture

FlagWise consists of:

- **Frontend**: React 18+ web application (Port 3000)
- **Backend**: FastAPI Python application (Port 8000)
- **Database**: PostgreSQL 15+ (Already running on your server!)
- **Deployment**: Docker Compose for easy management

## Prerequisites

✅ **Already Set Up on Your Server:**

- Docker and Docker Compose
- PostgreSQL 15+ with FlagWise database
- Firewall configured (will need to open additional ports)

❌ **Still Needed:**

- FlagWise repository clone
- Docker Compose configuration update
- Firewall rules for ports 3000 and 8000

## Deployment Instructions

### Step 1: Clone FlagWise Repository

```bash
# SSH into your server
ssh admin@<SERVER_IP>

# Clone the repository
cd /opt
sudo git clone https://github.com/bluewave-labs/flagwise.git
cd flagwise
```

### Step 2: Configure Database Connection

FlagWise needs to connect to the PostgreSQL database that's already running on your server.

Edit the `docker-compose.yml` file:

```bash
sudo nano docker-compose.yml
```

Update the database connection settings:

```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    container_name: flagwise_backend
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      # Database Configuration
      DATABASE_URL: postgresql://flagwise_user:FlagwisePass2024!@host.docker.internal:5432/flagwise
      POSTGRES_HOST: host.docker.internal
      POSTGRES_PORT: 5432
      POSTGRES_USER: flagwise_user
      POSTGRES_PASSWORD: FlagwisePass2024!
      POSTGRES_DB: flagwise

      # Security
      SECRET_KEY: <GENERATE_A_STRONG_SECRET_KEY>

      # Optional: Kafka for network monitoring (if needed)
      # KAFKA_BOOTSTRAP_SERVERS: localhost:9092
      # KAFKA_TOPIC: network-events
    volumes:
      - ./backend:/app
    depends_on:
      - frontend
    networks:
      - flagwise_net
    extra_hosts:
      - "host.docker.internal:host-gateway"

  frontend:
    build: ./frontend
    container_name: flagwise_frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      REACT_APP_API_URL: http://<SERVER_IP>:8000
    volumes:
      - ./frontend:/app
      - /app/node_modules
    networks:
      - flagwise_net

networks:
  flagwise_net:
    driver: bridge
```

**Important**:
- Replace `<SERVER_IP>` with your actual server IP
- Generate a strong secret key: `openssl rand -hex 32`

### Step 3: Initialize Database

The PostgreSQL database is already created with the following credentials:

```
Database: flagwise
Username: flagwise_user
Password: FlagwisePass2024!
Host: <SERVER_IP> (or localhost if on server)
Port: 5432
```

FlagWise should automatically create the necessary tables on first run. If manual initialization is needed:

```bash
# Connect to the database
sudo docker exec -it postgres_main psql -U flagwise_user -d flagwise

# Verify connection
\dt

# Exit
\q
```

### Step 4: Open Firewall Ports

```bash
# Allow FlagWise frontend
sudo ufw allow 3000/tcp comment 'FlagWise Frontend'

# Allow FlagWise backend API
sudo ufw allow 8000/tcp comment 'FlagWise Backend API'

# Verify firewall status
sudo ufw status
```

### Step 5: Build and Start FlagWise

```bash
cd /opt/flagwise

# Build and start containers
sudo docker-compose build
sudo docker-compose up -d

# Check status
sudo docker-compose ps

# View logs
sudo docker-compose logs -f
```

### Step 6: Access FlagWise

Once running, access FlagWise at:

- **Frontend**: http://`<SERVER_IP>`:3000
- **Backend API Docs**: http://`<SERVER_IP>`:8000/docs

**Default Credentials** (change immediately!):
- Username: admin
- Password: admin

## Configuration

### Environment Variables

Key environment variables for the backend:

```env
# Database
DATABASE_URL=postgresql://flagwise_user:FlagwisePass2024!@host.docker.internal:5432/flagwise

# Security
SECRET_KEY=<your-secret-key>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# API Settings
API_V1_PREFIX=/api/v1
PROJECT_NAME=FlagWise

# CORS
ALLOWED_ORIGINS=http://localhost:3000,http://<SERVER_IP>:3000

# Optional: Network Monitoring
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
KAFKA_TOPIC=network-events
```

### Feature Flags

FlagWise allows you to manage feature flags through its web interface:

1. Log in to http://`<SERVER_IP>`:3000
2. Navigate to "Feature Flags" section
3. Create new flags with:
   - Flag name
   - Description
   - Default value (on/off)
   - Targeting rules
   - Environment-specific settings

### Detection Rules

Configure network audit rules:

1. Navigate to "Detection Rules"
2. Add rules with:
   - **Keywords**: Simple text matching
   - **Regex Patterns**: Advanced pattern matching
   - **Alert Thresholds**: Trigger conditions
   - **Notification Channels**: Where to send alerts

Example detection rule:

```json
{
  "name": "Suspicious Login Attempt",
  "pattern": "failed.*login.*attempt",
  "type": "regex",
  "severity": "high",
  "action": "alert"
}
```

## Data Source Integration (Optional)

FlagWise can monitor network traffic through Kafka topics. If you need this functionality:

### Install Kafka (Optional)

```bash
cd /opt
sudo mkdir kafka
cd kafka

# Create docker-compose.yml for Kafka
cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
    ports:
      - "2181:2181"

  kafka:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
EOF

sudo docker-compose up -d

# Open firewall (if accessing externally)
sudo ufw allow 9092/tcp comment 'Kafka'
```

### Configure Router to Send Logs to Kafka

This depends on your network router/firewall. You'll need to:

1. Configure syslog forwarding to your server
2. Use a log collector (e.g., Logstash, Fluentd) to parse logs
3. Send parsed events to Kafka topic
4. FlagWise will consume from the topic

## User Management

### Create Additional Users

Via the web interface:

1. Log in as admin
2. Navigate to "User Management"
3. Click "Add User"
4. Set username, password, email, and role

Via API:

```bash
curl -X POST http://<SERVER_IP>:8000/api/v1/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-token>" \
  -d '{
    "username": "analyst",
    "email": "analyst@example.com",
    "password": "SecurePassword123!",
    "role": "viewer"
  }'
```

### Roles

FlagWise supports role-based access control:

- **Admin**: Full access to all features
- **Editor**: Can create and modify flags and rules
- **Viewer**: Read-only access
- **Custom Roles**: Define your own with specific permissions

## Monitoring and Maintenance

### View Logs

```bash
# All containers
cd /opt/flagwise && sudo docker-compose logs -f

# Backend only
sudo docker logs -f flagwise_backend

# Frontend only
sudo docker logs -f flagwise_frontend
```

### Database Backup

```bash
# Backup FlagWise database
sudo docker exec postgres_main pg_dump -U flagwise_user flagwise > flagwise_backup_$(date +%Y%m%d).sql

# Restore from backup
sudo docker exec -i postgres_main psql -U flagwise_user flagwise < flagwise_backup_20251111.sql
```

### Update FlagWise

```bash
cd /opt/flagwise

# Pull latest changes
sudo git pull

# Rebuild and restart
sudo docker-compose build --no-cache
sudo docker-compose down
sudo docker-compose up -d
```

### Resource Monitoring

```bash
# Check container resource usage
sudo docker stats flagwise_backend flagwise_frontend

# Check disk usage
df -h /opt/flagwise
```

## Troubleshooting

### Cannot Connect to Database

**Issue**: Backend can't connect to PostgreSQL

**Solution**:

```bash
# Check if PostgreSQL is running
sudo docker ps | grep postgres

# Test connection from host
psql -h localhost -U flagwise_user -d flagwise

# Check PostgreSQL logs
sudo docker logs postgres_main

# Verify database exists
sudo docker exec -it postgres_main psql -U pgadmin -c "\l"
```

### Frontend Can't Reach Backend

**Issue**: API calls fail from frontend

**Solution**:

1. Verify backend is running: `sudo docker ps`
2. Check firewall: `sudo ufw status`
3. Test API directly: `curl http://localhost:8000/docs`
4. Verify CORS settings in backend environment variables
5. Check `REACT_APP_API_URL` in frontend container

### Port Already in Use

**Issue**: Ports 3000 or 8000 are already occupied

**Solution**:

```bash
# Find process using port
sudo lsof -i :3000
sudo lsof -i :8000

# Kill process or change FlagWise ports
# Edit docker-compose.yml to use different ports
# Example: "3001:3000" instead of "3000:3000"
```

### Container Keeps Restarting

```bash
# Check logs for errors
sudo docker logs flagwise_backend
sudo docker logs flagwise_frontend

# Common issues:
# - Missing environment variables
# - Database connection failed
# - Missing dependencies

# Rebuild from scratch
cd /opt/flagwise
sudo docker-compose down
sudo docker-compose build --no-cache
sudo docker-compose up -d
```

## Integration with Inspect AI

While FlagWise and Inspect AI are separate tools, you can use them together:

1. **Feature Flags for Evaluations**: Use FlagWise to toggle which evaluations to run
2. **Audit Evaluation Results**: Send Inspect AI results to FlagWise for auditing
3. **API Integration**: Create custom integration between the two systems

Example integration script:

```python
import requests
import json

# FlagWise API
FLAGWISE_API = "http://localhost:8000/api/v1"
TOKEN = "your-token"

# Check if evaluation is enabled
def is_eval_enabled(eval_name):
    response = requests.get(
        f"{FLAGWISE_API}/flags/{eval_name}",
        headers={"Authorization": f"Bearer {TOKEN}"}
    )
    return response.json().get("enabled", False)

# Send audit event
def log_eval_result(eval_name, result):
    requests.post(
        f"{FLAGWISE_API}/audit/events",
        headers={"Authorization": f"Bearer {TOKEN}"},
        json={
            "event_type": "eval_completed",
            "eval_name": eval_name,
            "result": result
        }
    )
```

## Security Considerations

1. **Change Default Credentials**: Immediately change the default admin password
2. **Use HTTPS**: Set up SSL/TLS certificates (e.g., with Let's Encrypt)
3. **Firewall Rules**: Only open necessary ports, restrict access by IP if possible
4. **Database Security**: Change default PostgreSQL passwords
5. **API Authentication**: Always use token-based authentication
6. **Regular Updates**: Keep FlagWise and dependencies up to date
7. **Backup**: Regular database backups to prevent data loss

## API Documentation

Once deployed, explore the interactive API documentation:

- **Swagger UI**: http://`<SERVER_IP>`:8000/docs
- **ReDoc**: http://`<SERVER_IP>`:8000/redoc

The API includes endpoints for:

- `/api/v1/auth` - Authentication
- `/api/v1/flags` - Feature flag management
- `/api/v1/rules` - Detection rule management
- `/api/v1/users` - User management
- `/api/v1/audit` - Audit events and logs

## Resources

- **FlagWise Repository**: https://github.com/bluewave-labs/flagwise
- **Documentation**: Check the repository's docs/ folder
- **Issues**: Report bugs at GitHub Issues
- **Community**: Join discussions in the repository

## Next Steps

1. Deploy FlagWise using the instructions above
2. Change default admin credentials
3. Create your first feature flag
4. Set up detection rules for your use case
5. Configure network data sources (if applicable)
6. Integrate with your existing infrastructure
7. Set up monitoring and alerts
8. Train team members on FlagWise usage

## Support

For issues with FlagWise deployment:

1. Check the official repository for documentation updates
2. Review GitHub Issues for similar problems
3. Check container logs for error messages
4. Verify database connectivity and credentials
5. Ensure all required ports are open and accessible
