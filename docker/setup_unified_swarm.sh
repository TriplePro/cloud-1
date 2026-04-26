#!/bin/bash
# setup_unified_swarm.sh
# Upgrade 3 aparte swarms naar 1 unified swarm met 3 managers

MANAGER_PRIMARY="10.24.50.210"
MANAGER_SECONDARY_1="10.24.50.220"
MANAGER_SECONDARY_2="10.24.50.230"

USER="theo"
PASSWORD="theo"

echo "========================================"
echo "Upgrade to Unified Swarm"
echo "1 Swarm with 3 Distributed Managers"
echo "========================================"

# Stap 1: Leave huidige swarms (behalve primary)
echo ""
echo "[Stap 1] Cleaning up existing swarms..."
echo "  → Leaving Swarm on $MANAGER_SECONDARY_1..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_SECONDARY_1 \
    "docker swarm leave --force" 2>/dev/null || true
echo "    ✅ Left swarm"

echo "  → Leaving Swarm on $MANAGER_SECONDARY_2..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_SECONDARY_2 \
    "docker swarm leave --force" 2>/dev/null || true
echo "    ✅ Left swarm"

# Stap 2: Primary manager initialiseert nieuwe swarm
echo ""
echo "[Stap 2] Initializing new unified swarm..."
echo "  → Initializing on $MANAGER_PRIMARY..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_PRIMARY \
    "docker swarm leave --force" 2>/dev/null || true

sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_PRIMARY \
    "docker swarm init --advertise-addr $MANAGER_PRIMARY"
echo "    ✅ Unified Swarm initialized"

# Stap 3: Haal manager join token
echo ""
echo "[Stap 3] Getting manager join token..."
MANAGER_TOKEN=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_PRIMARY \
    "docker swarm join-token -q manager")
echo "    ✅ Token obtained"

# Stap 4: Secondary managers joinen als managers
echo ""
echo "[Stap 4] Joining secondary managers..."

echo "  → Joining $MANAGER_SECONDARY_1 as Manager..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_SECONDARY_1 \
    "docker swarm join --token $MANAGER_TOKEN $MANAGER_PRIMARY:2377"
echo "    ✅ Manager 2 joined"

echo "  → Joining $MANAGER_SECONDARY_2 as Manager..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_SECONDARY_2 \
    "docker swarm join --token $MANAGER_TOKEN $MANAGER_PRIMARY:2377"
echo "    ✅ Manager 3 joined"

# Stap 5: Verificatie
echo ""
echo "[Stap 5] Verification..."
echo ""
echo "All Nodes in Unified Swarm:"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_PRIMARY \
    "docker node ls"

echo ""
echo "========================================"
echo "✅ Unified Swarm Successfully Created!"
echo "========================================"
echo ""
echo "Swarm Details:"
echo "  Primary Manager: $MANAGER_PRIMARY"
echo "  Secondary Manager 1: $MANAGER_SECONDARY_1"
echo "  Secondary Manager 2: $MANAGER_SECONDARY_2"
echo ""
echo "Status:"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER_PRIMARY \
    "docker swarm info | grep -E 'Nodes|Managers'"