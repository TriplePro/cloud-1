#!/bin/bash
# setup_docker.sh - Docker installatie op Ubuntu 22.04.5

set -e

echo "========================================"
echo "Docker Installatie Ubuntu 22.04.5"
echo "========================================"

# Stap 1: Update repositories
echo "[1/5] Updating package repositories..."
sudo apt-get update
sudo apt-get upgrade -y

# Stap 2: Installeer vereisten
echo "[2/5] Installing prerequisites..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget

# Stap 3: Voeg Docker GPG sleutel toe
echo "[3/5] Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Stap 4: Voeg Docker repository toe
echo "[4/5] Adding Docker repository..."
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Stap 5: Installeer Docker
echo "[5/5] Installing Docker Engine..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Docker starten en enablen
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# User toevoegen aan docker groep
echo "Adding current user to docker group..."
sudo usermod -aG docker $USER
newgrp docker

# Verificatie
echo ""
echo "========================================"
echo "Docker installatie voltooid!"
echo "========================================"
docker --version
docker run hello-world

echo ""
echo "⚠️  Log uit en in (of run: 'newgrp docker') om docker zonder sudo te gebruiken"