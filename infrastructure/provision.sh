#!/bin/bash
set -e

# Hetzner VPS Provisioning Script for LLM Security Audit Infrastructure
# This script creates a cx23 server with cloud-init configuration

# Configuration
HETZNER_API_TOKEN="t4bkO8LqJiFmSrdbKg9L6IAiTUqM3saQwCkaghv3U4Xr5JL63J7o8udwRCHcftxK"
SERVER_NAME="llm-audit-vps-$(date +%Y%m%d-%H%M%S)"
SERVER_TYPE="cx23"  # 2 vCPU, 4 GB RAM, 40 GB SSD
LOCATION="nbg1"     # Nuremberg (alternative: fsn1 for Falkenstein)
IMAGE="ubuntu-24.04"
SSH_KEY_NAME="marius-audit-key"
SSH_KEY_PUBLIC="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8o6ndVXDWrWfJZbJY8nQRRv162UWua2opUmYzNhSjC marius.moldovan@standivarius.com"

API_URL="https://api.hetzner.cloud/v1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to make API calls with retry
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local max_retries=4
    local retry_count=0
    local wait_time=2

    while [ $retry_count -lt $max_retries ]; do
        if [ -z "$data" ]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" \
                -H "Authorization: Bearer $HETZNER_API_TOKEN" \
                -H "Content-Type: application/json" \
                "$API_URL/$endpoint")
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" \
                -H "Authorization: Bearer $HETZNER_API_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$API_URL/$endpoint")
        fi

        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')

        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            echo "$body"
            return 0
        elif [ "$http_code" -eq 403 ]; then
            print_error "API call failed with 403 Forbidden. Check your API token and permissions."
            echo "$body"
            return 1
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "API call failed with code $http_code. Retrying in ${wait_time}s... (Attempt $retry_count/$max_retries)"
                sleep $wait_time
                wait_time=$((wait_time * 2))
            else
                print_error "API call failed after $max_retries attempts. HTTP Code: $http_code"
                echo "$body"
                return 1
            fi
        fi
    done
}

# Check if cloud-init.yaml exists
if [ ! -f "cloud-init.yaml" ]; then
    print_error "cloud-init.yaml not found in current directory!"
    exit 1
fi

print_info "Starting Hetzner VPS provisioning..."
echo "============================================"

# Step 1: Create or get SSH key
print_info "Step 1: Setting up SSH key..."
ssh_key_response=$(api_call "GET" "ssh_keys")

# Check if key already exists by public key (more reliable than name)
ssh_key_id=$(echo "$ssh_key_response" | jq -r ".ssh_keys[] | select(.public_key | contains(\"$(echo $SSH_KEY_PUBLIC | awk '{print $2}')\")) | .id")

if [ -z "$ssh_key_id" ] || [ "$ssh_key_id" == "null" ]; then
    print_info "SSH key not found. Creating new SSH key..."
    ssh_key_data=$(jq -n \
        --arg name "$SSH_KEY_NAME" \
        --arg public_key "$SSH_KEY_PUBLIC" \
        '{name: $name, public_key: $public_key}')

    ssh_key_response=$(api_call "POST" "ssh_keys" "$ssh_key_data")
    if [ $? -ne 0 ]; then
        print_error "Failed to create SSH key"
        exit 1
    fi

    ssh_key_id=$(echo "$ssh_key_response" | jq -r '.ssh_key.id')
    print_success "SSH key created with ID: $ssh_key_id"
else
    print_success "SSH key already exists with ID: $ssh_key_id"
fi

# Step 2: Read and encode cloud-init configuration
print_info "Step 2: Reading cloud-init configuration..."
cloud_init_data=$(cat cloud-init.yaml)

# Step 3: Create server
print_info "Step 3: Creating server..."
print_info "Server details:"
echo "  Name: $SERVER_NAME"
echo "  Type: $SERVER_TYPE"
echo "  Location: $LOCATION"
echo "  Image: $IMAGE"

server_data=$(jq -n \
    --arg name "$SERVER_NAME" \
    --arg server_type "$SERVER_TYPE" \
    --arg image "$IMAGE" \
    --arg location "$LOCATION" \
    --arg ssh_key_id "$ssh_key_id" \
    --arg user_data "$cloud_init_data" \
    '{
        name: $name,
        server_type: $server_type,
        image: $image,
        location: $location,
        ssh_keys: [$ssh_key_id],
        user_data: $user_data,
        start_after_create: true,
        labels: {
            purpose: "llm-audit",
            project: "petri-flagwise",
            environment: "production"
        }
    }')

server_response=$(api_call "POST" "servers" "$server_data")

if [ $? -ne 0 ]; then
    print_error "Failed to create server"
    exit 1
fi

# Extract server information
server_id=$(echo "$server_response" | jq -r '.server.id')
server_ipv4=$(echo "$server_response" | jq -r '.server.public_net.ipv4.ip')
server_ipv6=$(echo "$server_response" | jq -r '.server.public_net.ipv6.ip')
root_password=$(echo "$server_response" | jq -r '.root_password // "N/A (SSH key only)"')

print_success "Server created successfully!"
echo "============================================"
echo ""
echo "Server Information:"
echo "  Server ID: $server_id"
echo "  Name: $SERVER_NAME"
echo "  IPv4: $server_ipv4"
echo "  IPv6: $server_ipv6"
echo "  Root Password: $root_password"
echo ""

# Step 4: Wait for server to be ready
print_info "Step 4: Waiting for server to be ready..."
max_wait=300  # 5 minutes
waited=0
while [ $waited -lt $max_wait ]; do
    server_status=$(api_call "GET" "servers/$server_id")
    status=$(echo "$server_status" | jq -r '.server.status')

    if [ "$status" == "running" ]; then
        print_success "Server is running!"
        break
    fi

    print_info "Server status: $status (waited ${waited}s)"
    sleep 10
    waited=$((waited + 10))
done

if [ "$status" != "running" ]; then
    print_warning "Server is not running yet after ${max_wait}s. Status: $status"
    print_info "You can check the status later with: curl -H 'Authorization: Bearer \$TOKEN' https://api.hetzner.cloud/v1/servers/$server_id"
fi

# Step 5: Wait for cloud-init to complete
print_info "Step 5: Waiting for cloud-init to complete..."
print_info "This may take 5-10 minutes as Docker, PostgreSQL, and Inspect AI are being set up..."
print_info "You can SSH into the server and monitor progress:"
echo "  ssh admin@$server_ipv4"
echo "  tail -f /var/log/cloud-init-output.log"
echo "  tail -f /var/log/infrastructure-setup.log"
echo ""

# Wait a bit more for cloud-init to start
sleep 30

# Save deployment information
DEPLOYMENT_FILE="deployment-info-$(date +%Y%m%d-%H%M%S).txt"
cat > "$DEPLOYMENT_FILE" <<EOF
================================================================================
HETZNER VPS - LLM SECURITY AUDIT INFRASTRUCTURE
================================================================================

Deployment Date: $(date)
Server Created: $(date)

--------------------------------------------------------------------------------
SERVER DETAILS
--------------------------------------------------------------------------------
Server ID: $server_id
Server Name: $SERVER_NAME
Server Type: $SERVER_TYPE ($LOCATION)
Image: $IMAGE

IPv4: $server_ipv4
IPv6: $server_ipv6

--------------------------------------------------------------------------------
SSH ACCESS
--------------------------------------------------------------------------------
Command: ssh admin@$server_ipv4

User: admin
SSH Key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8o6ndVXDWrWfJZbJY8nQRRv162UWua2opUmYzNhSjC

Root Password (if needed): $root_password

--------------------------------------------------------------------------------
IMPORTANT: CLOUD-INIT IN PROGRESS
--------------------------------------------------------------------------------
The server is currently running cloud-init setup. This process takes 5-10 minutes.

Monitor progress:
  ssh admin@$server_ipv4
  sudo tail -f /var/log/cloud-init-output.log
  sudo tail -f /var/log/infrastructure-setup.log

After cloud-init completes, check:
  sudo cat /root/DEPLOYMENT_INFO.txt

This file contains:
  - Portainer URL and initial password
  - PostgreSQL connection details
  - Inspect AI configuration
  - FlagWise deployment instructions
  - All service credentials

--------------------------------------------------------------------------------
SERVICES (Available after cloud-init completes)
--------------------------------------------------------------------------------
Portainer:       http://$server_ipv4:9000
Portainer HTTPS: https://$server_ipv4:9443

PostgreSQL:      $server_ipv4:5432
  - Main DB:     audit_db (user: pgadmin)
  - Inspect AI:  inspect_ai (user: inspect_user)
  - FlagWise:    flagwise (user: flagwise_user)

Inspect AI:      http://$server_ipv4:7000

--------------------------------------------------------------------------------
NEXT STEPS
--------------------------------------------------------------------------------
1. Wait for cloud-init to complete (5-10 minutes)
2. SSH into the server: ssh admin@$server_ipv4
3. Check deployment info: sudo cat /root/DEPLOYMENT_INFO.txt
4. Access Portainer and set up admin account
5. Configure Inspect AI API keys
6. Deploy FlagWise (instructions in DEPLOYMENT_INFO.txt)

--------------------------------------------------------------------------------
HETZNER CLOUD MANAGEMENT
--------------------------------------------------------------------------------
View server in Hetzner Cloud Console:
  https://console.hetzner.cloud/projects

Delete server (when no longer needed):
  curl -X DELETE -H "Authorization: Bearer \$TOKEN" \\
    https://api.hetzner.cloud/v1/servers/$server_id

Get server details:
  curl -H "Authorization: Bearer \$TOKEN" \\
    https://api.hetzner.cloud/v1/servers/$server_id

--------------------------------------------------------------------------------
COST ESTIMATION
--------------------------------------------------------------------------------
Server Type: $SERVER_TYPE
Estimated Cost: ~€6-8/month (check Hetzner pricing for exact amount)

Remember to delete the server when no longer needed to avoid charges!

================================================================================
EOF

print_success "Deployment information saved to: $DEPLOYMENT_FILE"
echo ""

# Display summary
print_info "============================================"
print_info "DEPLOYMENT SUMMARY"
print_info "============================================"
echo ""
echo "Server IP: $server_ipv4"
echo "SSH Command: ssh admin@$server_ipv4"
echo ""
echo "Services (available after cloud-init completes):"
echo "  Portainer:  http://$server_ipv4:9000"
echo "  PostgreSQL: $server_ipv4:5432"
echo "  Inspect AI: http://$server_ipv4:7000"
echo ""
print_warning "IMPORTANT: Cloud-init is still running! Wait 5-10 minutes before accessing services."
echo ""
print_info "Detailed deployment information saved to: $DEPLOYMENT_FILE"
print_info "After cloud-init completes, SSH in and check: sudo cat /root/DEPLOYMENT_INFO.txt"
echo ""
print_success "Provisioning complete!"
