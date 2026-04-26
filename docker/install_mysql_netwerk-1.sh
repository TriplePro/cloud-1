#!/bin/bash

# Script voor MySQL setup op VM1 met Custom Subnet

# Creëer custom bridge network met eigen subnet
docker network create \
  --driver bridge \
  --subnet=172.20.0.0/16 \
  mysql-network-1

# Maak directory voor MySQL data
mkdir -p ~/mysql-data-vm1

# Start MySQL container op VM1
docker run -d \
  --name mysql-server-1 \
  --network mysql-network-1 \
  --ip 172.20.0.2 \
  -e MYSQL_ROOT_PASSWORD=root_password_123 \
  -e MYSQL_DATABASE=app_db \
  -v ~/mysql-data-vm1:/var/lib/mysql \
  -p 3306:3306 \
  mysql:5.7

echo "MySQL Server 1 gestart op 172.20.0.2"
docker network inspect mysql-network-1