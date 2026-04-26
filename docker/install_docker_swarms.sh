#!/bin/bash
# setup_3_swarms_final.sh
# Login: theo / wachtwoord: theo

MANAGERS=(
    "10.24.50.210"
    "10.24.50.220"
    "10.24.50.230"
)

USER="theo"
PASSWORD="theo"

echo "========================================"
echo "Setup 3 Aparte Swarms"
echo "3 VMs, 3 Managers, 3 Swarms"
echo "========================================"

# Stap 1: Docker Installatie op alle VMs
echo ""
echo "[Stap 1] Installing Docker on all VMs..."
for MANAGER_IP in "${MANAGERS[@]}"; do
    echo "  → Installing Docker on $MANAGER_IP..."
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_IP << 'EOF'
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker theo
EOF
    echo "    ✅ Docker installed on $MANAGER_IP"
done

# Stap 2: Initialiseer Swarms
echo ""
echo "[Stap 2] Initializing Swarms..."
for MANAGER_IP in "${MANAGERS[@]}"; do
    echo "  → Initializing Swarm on $MANAGER_IP..."
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_IP \
        "docker swarm init --advertise-addr $MANAGER_IP"
    echo "    ✅ Swarm initialized on $MANAGER_IP"
done

# Stap 3: Verificatie
echo ""
echo "[Stap 3] Verification..."
for MANAGER_IP in "${MANAGERS[@]}"; do
    echo ""
    echo "Swarm on $MANAGER_IP:"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_IP "docker node ls"
done

echo ""
echo "========================================"
echo "✅ All 3 Swarms Successfully Created!"
echo "========================================"