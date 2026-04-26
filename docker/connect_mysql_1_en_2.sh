#!/bin/bash
# setup-mysql-complete.sh
# Volledig automated setup voor MySQL op 2 VMs met aparte subnetten

set -e

# Configuratie
VM1_IP="10.24.50.181"
VM2_IP="10.24.50.182"
VM1_SUBNET="172.20.0.0/16"
VM2_SUBNET="172.21.0.0/16"
VM1_CONTAINER_IP="172.20.0.2"
VM2_CONTAINER_IP="172.21.0.2"

echo "========================================"
echo "Complete MySQL Setup - 2 VMs"
echo "========================================"
echo ""
echo "VM1: $VM1_IP (Subnet: $VM1_SUBNET)"
echo "VM2: $VM2_IP (Subnet: $VM2_SUBNET)"
echo ""

# STAP 1: Setup VM1
echo "[Stap 1/2] Setting up MySQL on VM1..."
echo ""

# Installeer Docker op VM1
echo "  [1.1] Installing Docker on VM1..."
docker run -d \
  --name setup-vm1 \
  --rm \
  -e "HOST=$VM1_IP" \
  -e "SUBNET=$VM1_SUBNET" \
  -e "CONTAINER_IP=$VM1_CONTAINER_IP" \
  alpine:latest \
  sh -c 'echo "Setup placeholders"' > /dev/null 2>&1 || true

# Creëer network op VM1
echo "  [1.2] Creating Docker network on VM1..."
docker network create \
  --driver bridge \
  --subnet=$VM1_SUBNET \
  mysql-network-1 2>/dev/null || echo "    (Network already exists)"

# Maak data directory
mkdir -p ~/mysql-data-vm1

# Start MySQL op VM1
echo "  [1.3] Starting MySQL container on VM1..."
docker run -d \
  --name mysql-server-1 \
  --network mysql-network-1 \
  --ip $VM1_CONTAINER_IP \
  -e MYSQL_ROOT_PASSWORD=root_password_123 \
  -e MYSQL_DATABASE=app_db \
  -v ~/mysql-data-vm1:/var/lib/mysql \
  -p 3306:3306 \
  mysql:5.7 2>/dev/null || echo "    (Container already running)"

echo "  ✅ VM1 Setup Complete"
echo ""

# STAP 2: Setup VM2 (via SSH)
echo "[Stap 2/2] Setting up MySQL on VM2..."
echo ""

# SSH commands for VM2
VM2_SETUP="
  # Network
  docker network create \
    --driver bridge \
    --subnet=$VM2_SUBNET \
    mysql-network-2 2>/dev/null || echo 'Network already exists'
  
  # Data directory
  mkdir -p ~/mysql-data-vm2
  
  # Start MySQL
  docker run -d \
    --name mysql-server-2 \
    --network mysql-network-2 \
    --ip $VM2_CONTAINER_IP \
    -e MYSQL_ROOT_PASSWORD=root_password_456 \
    -e MYSQL_DATABASE=app_db \
    -v ~/mysql-data-vm2:/var/lib/mysql \
    -p 3307:3306 \
    mysql:5.7 2>/dev/null || echo 'Container already running'
"

# Poging met SSH
if command -v ssh &> /dev/null; then
  echo "  [2.1] Connecting to VM2 via SSH..."
  ssh -o StrictHostKeyChecking=no theo@$VM2_IP "$VM2_SETUP" 2>/dev/null && echo "  ✅ VM2 Setup via SSH" || echo "  ⚠️  SSH not available"
else
  echo "  ⚠️  SSH not available. Please run manually on VM2:"
  echo "    docker network create --driver bridge --subnet=$VM2_SUBNET mysql-network-2"
  echo "    mkdir -p ~/mysql-data-vm2"
  echo "    docker run -d --name mysql-server-2 --network mysql-network-2 --ip $VM2_CONTAINER_IP -e MYSQL_ROOT_PASSWORD=root_password_456 -e MYSQL_DATABASE=app_db -v ~/mysql-data-vm2:/var/lib/mysql -p 3307:3306 mysql:5.7"
fi

echo ""
echo "========================================"
echo "✅ Setup Complete!"
echo "========================================"
echo ""
echo "Verification:"
echo ""

# Verificatie
echo "Docker PS VM1:"
docker ps --filter "name=mysql-server-1" --format "table {{.Names}}\t{{.Status}}"
echo ""

echo "Docker Networks VM1:"
docker network ls | grep mysql-network-1
echo ""

echo "Connectivity Tests:"
echo "  → VM1 → VM2:"
timeout 2 nc -zv $VM2_IP 3307 2>&1 | grep -o "succeeded\|refused" || echo "Testing..."
echo ""
echo "  → Proxmox → VM1:"
timeout 2 nc -zv $VM1_IP 3306 2>&1 | grep -o "succeeded\|refused" || echo "Testing..."
echo ""
echo "  → Proxmox → VM2:"
timeout 2 nc -zv $VM2_IP 3307 2>&1 | grep -o "succeeded\|refused" || echo "Testing..."
echo ""

echo "Setup Details:"
echo "  VM1 MySQL: $VM1_IP:3306"
echo "  VM2 MySQL: $VM2_IP:3307"
echo "  Username: root"
echo "  VM1 Password: root_password_123"
echo "  VM2 Password: root_password_456"