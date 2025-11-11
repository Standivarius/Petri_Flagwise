#!/bin/bash
set -e

# FlagWise Deployment Script
# Run this script on the server to deploy FlagWise

echo "=== FlagWise Deployment Script ==="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Navigate to /opt
cd /opt

# Clone FlagWise if not already cloned
if [ -d "flagwise" ]; then
    echo "FlagWise directory already exists. Updating..."
    cd flagwise
    git pull
else
    echo "Cloning FlagWise repository..."
    git clone https://github.com/bluewave-labs/flagwise.git
    cd flagwise
fi

echo ""
echo "=== Checking Repository Structure ==="
ls -la

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: docker-compose.yml not found!"
    echo "Please check the repository structure."
    exit 1
fi

echo ""
echo "=== Creating .env Configuration ==="

# Generate secret key
SECRET_KEY=$(openssl rand -hex 32)

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

# Create .env file
cat > .env <<EOF
# Database Configuration
DATABASE_URL=postgresql://flagwise_user:FlagwisePass2024!@host.docker.internal:5432/flagwise
POSTGRES_HOST=host.docker.internal
POSTGRES_PORT=5432
POSTGRES_USER=flagwise_user
POSTGRES_PASSWORD=FlagwisePass2024!
POSTGRES_DB=flagwise

# Security
SECRET_KEY=${SECRET_KEY}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# API Settings
API_V1_PREFIX=/api/v1
PROJECT_NAME=FlagWise

# CORS
ALLOWED_ORIGINS=http://localhost:3000,http://${SERVER_IP}:3000

# Server IP
SERVER_IP=${SERVER_IP}
EOF

echo "Created .env file with configuration"
echo ""

# Check if docker-compose needs modification
echo "=== Checking docker-compose.yml ==="
cat docker-compose.yml

echo ""
echo "=== Opening Firewall Ports ==="
ufw allow 3000/tcp comment 'FlagWise Frontend'
ufw allow 8000/tcp comment 'FlagWise Backend API'
echo "Firewall ports 3000 and 8000 opened"

echo ""
echo "=== Building FlagWise Containers ==="
docker-compose build

echo ""
echo "=== Starting FlagWise ==="
docker-compose up -d

echo ""
echo "=== Checking Container Status ==="
sleep 5
docker-compose ps

echo ""
echo "=== FlagWise Deployment Complete ==="
echo ""
echo "Access FlagWise at:"
echo "  Frontend: http://${SERVER_IP}:3000"
echo "  Backend API: http://${SERVER_IP}:8000/docs"
echo ""
echo "Default credentials (CHANGE IMMEDIATELY):"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "View logs:"
echo "  docker-compose -f /opt/flagwise/docker-compose.yml logs -f"
echo ""
echo "Database connection:"
echo "  postgresql://flagwise_user:FlagwisePass2024!@localhost:5432/flagwise"
echo ""
