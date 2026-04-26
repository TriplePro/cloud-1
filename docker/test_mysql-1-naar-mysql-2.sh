#!/bin/bash

# Is container actief?
docker ps | grep mysql-server-1

# Luistert poort 3306?
netstat -tlnp | grep 3306

# Kan VM2 bereiken?
ping -c 2 10.24.50.182

# Kan MySQL poort VM2 bereiken?
nc -zv 10.24.50.182 3307

# rechtstreeks
docker exec mysql-server-1 mysql -h 172.20.0.2 -u root -proot_password_123 -e "SELECT 1 AS 'Connection Successful';" 2>/dev/null || echo "MySQL Server 1 niet bereikbaar"
docker exec mysql-server-2 mysql -h 172.21.0.2 -u root -proot_password_456 -e "SELECT 1 AS 'Connection Successful';" 2>/dev/null || echo "MySQL Server 2 niet bereikbaar"