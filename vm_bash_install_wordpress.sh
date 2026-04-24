#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

read -p "Enter the VM ID (VMID): " VMID
VM_IP="10.24.50.$VMID"
DB_USER="wordpress_user"
DB_PASSWORD="password"
DB_NAME="wordpress"
WP_URL="https://wordpress.org/latest.tar.gz"
WP_DIR="/var/www/wordpress"

printf "\n==============================\n"
printf "Install WordPress on VM %s\n" "$VMID"
printf "\n==============================\n"

printf "Checking if the VM is running...\n"
if ! qm status "$VMID" | grep -q "running"; then

    printf "\n==============================\n"
    printf "VM %s is not running. Starting VM...\n" "$VMID"
    qm start "$VMID"

    printf "\n==============================\n"
    printf "Waiting for VM to start...\n"
    sleep 15
fi

printf "\n==============================\n"
printf "Updating packages...\n"
printf "\n==============================\n"
qm guest exec "$VMID" -- apt-get update
qm guest exec "$VMID" -- apt-get upgrade -y

printf "\n==============================\n"
printf "Installing nginx...\n"
printf "\n==============================\n"
qm guest exec "$VMID" -- apt-get install -y nginx

printf "\n==============================\n"
printf "Installing MariaDB server...\n"
printf "\n==============================\n"
qm guest exec "$VMID" -- apt-get install -y mariadb-server

printf "\n==============================\n"
printf "Installing PHP and modules...\n"
printf "\n==============================\n"
qm guest exec "$VMID" -- apt-get install -y php-fpm php-mysql

printf "\n==============================\n"
printf "Detecting PHP version...\n"
PHP_VERSION=$(qm guest exec "$VMID" -- php -v | grep -oP 'PHP \K[0-9]+\.[0-9]+' | head -1)
PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
PHP_FPM_SOCK="/var/run/php/php${PHP_VERSION}-fpm.sock"

printf "Detected PHP version: %s\n" "$PHP_VERSION"
printf "PHP-FPM service: %s\n" "$PHP_FPM_SERVICE"
printf "PHP-FPM socket: %s\n" "$PHP_FPM_SOCK"

printf "\n==============================\n"
printf "Starting and enabling MariaDB...\n"
printf "\n==============================\n"
qm guest exec "$VMID" -- systemctl start mariadb
qm guest exec "$VMID" -- systemctl enable mariadb

printf "\n==============================\n"
printf "Creating WordPress database...\n"
qm guest exec "$VMID" -- mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
qm guest exec "$VMID" -- mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
qm guest exec "$VMID" -- mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
qm guest exec "$VMID" -- mysql -e "FLUSH PRIVILEGES;"

printf "\n==============================\n"
printf "Creating WordPress directory...\n"
qm guest exec "$VMID" -- sudo mkdir -p "$WP_DIR"

printf "\n==============================\n"
printf "Downloading and installing WordPress...\n"
qm guest exec "$VMID" -- bash -c "cd /tmp && wget -q ${WP_URL} && tar -xzf latest.tar.gz && sudo mv wordpress/* ${WP_DIR}/ && rm -rf wordpress latest.tar.gz"

printf "\n==============================\n"
printf "Setting access to WordPress directory...\n"
qm guest exec "$VMID" -- sudo chown -R www-data:www-data "$WP_DIR"
qm guest exec "$VMID" -- sudo chmod -R 755 "$WP_DIR"

printf "\n==============================\n"
printf "Configuring nginx for WordPress...\n"
qm guest exec "$VMID" -- bash -c "sudo cat > /etc/nginx/sites-available/wordpress << 'EOF'
server {
    listen 80;
    server_name ${VM_IP};

    root ${WP_DIR};
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_FPM_SOCK};
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
"

printf "\n==============================\n"
printf "Enabling nginx site...\n"
printf "Creating symbolic link for WordPress site...\n"
qm guest exec "$VMID" -- bash -c "rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress"

printf "\n==============================\n"
printf "Starting PHP-FPM...\n"
printf "\n==============================\n"
qm guest exec "$VMID" -- systemctl start "$PHP_FPM_SERVICE"
qm guest exec "$VMID" -- systemctl enable "$PHP_FPM_SERVICE"

printf "\n==============================\n"
printf "Testing and restarting nginx...\n"
printf "\n==============================\n"
qm guest exec "$VMID" -- nginx -t
qm guest exec "$VMID" -- systemctl restart nginx
qm guest exec "$VMID" -- systemctl enable nginx

printf "\n==============================\n"
printf "WordPress installation complete!\n"
printf "\n==============================\n"

printf "VM ID: %s\n" "$VMID"
printf "IP Address: %s\n" "$VM_IP"
printf "Database user: %s\n" "$DB_USER"
printf "Database name: %s\n" "$DB_NAME"
printf "WordPress directory: %s\n" "$WP_DIR"
printf "\nAccess WordPress at: http://%s\n" "$VM_IP"

printf "\n==============================\n"