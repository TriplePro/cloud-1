#!/bin/bash

echo "=== Docker Network Status ==="
docker network ls

echo -e "\n=== Running Containers ==="
docker ps

echo -e "\n=== Container IP Adressen ==="
docker inspect --format='{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -q)

echo -e "\n=== Network Details ==="
docker network inspect mysql-network-1 2>/dev/null || echo "Network 1 niet gevonden"
docker network inspect mysql-network-2 2>/dev/null || echo "Network 2 niet gevonden"

echo -e "\n=== MySQL Connectiviteit Test ==="
docker exec mysql-server-1 mysql -h 172.20.0.2 -u root -proot_password_123 -e "SELECT 1 AS 'Connection Successful';" 2>/dev/null || echo "MySQL Server 1 niet bereikbaar"
docker exec mysql-server-2 mysql -h 172.21.0.2 -u root -proot_password_456 -e "SELECT 1 AS 'Connection Successful';" 2>/dev/null || echo "MySQL Server 2 niet bereikbaar"