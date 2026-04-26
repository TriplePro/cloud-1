#!/bin/bash
# verify_unified_swarm.sh

MANAGER="10.24.50.210"
USER="theo"
PASSWORD="theo"

echo "========================================"
echo "Verifying Unified Swarm Setup"
echo "========================================"

echo ""
echo "[1] All Nodes in Swarm:"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER \
    "docker node ls"

echo ""
echo "[2] Detailed Node Info:"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER \
    "docker node ls --format 'table {{.ID}}\t{{.Hostname}}\t{{.Status}}\t{{.ManagerStatus}}'"

echo ""
echo "[3] Swarm Info:"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$MANAGER \
    "docker info | grep -A 20 'Swarm'"

echo ""
echo "[4] Test: Services can reach all managers:"
for ip in 10.24.50.210 10.24.50.220 10.24.50.230; do
    echo "  → Testing $ip:"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$ip \
        "docker node ls | wc -l" | xargs echo "    Nodes visible:"
done

echo ""
echo "========================================"
echo "✅ Verification Complete!"
echo "========================================"