#!/bin/bash

# Script voor MySQL setup op VM2 met Custom Subnet

# Creëer custom bridge network met ander subnet
docker network create \
  --driver bridge \
  --subnet=172.21.0.0/16 \
  mysql-network-2

# Maak directory voor MySQL data
mkdir -p ~/mysql-data-vm2

# Start MySQL container op VM2
docker run -d \
  --name mysql-server-2 \
  --network mysql-network-2 \
  --ip 172.21.0.2 \
  -e MYSQL_ROOT_PASSWORD=root_password_456 \
  -e MYSQL_DATABASE=app_db \
  -v ~/mysql-data-vm2:/var/lib/mysql \
  -p 3307:3306 \
  mysql:5.7

echo "MySQL Server 2 gestart op 172.21.0.2"
docker network inspect mysql-network-2