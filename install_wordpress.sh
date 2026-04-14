#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

CTID=150
LXC_IP="10.24.50.$CTID"
DB_USER="wordpress_user"
DB_PASSWORD="password"
DB_NAME="wordpress"
WP_URL="https://wordpress.org/latest.tar.gz"
WP_DIR="/var/www/wordpress"

printf "\n==============================\n"
printf "install WordPress on LXC %s\n" "$CTID"
printf "\n==============================\n"

printf "check if the container is running...\n"
if ! pct status "$CTID" | grep -q "running"; then

    printf "\n==============================\n"
    printf "container %s is not running. starting container...\n" "$CTID"
    pct start "$CTID"

    printf "\n==============================\n"
    printf "wait until the container is started...\n"
    sleep 10
fi

printf "\n==============================\n"
printf "update packages...\n"
printf "\n==============================\n"
pct exec "$CTID" -- apt update
pct exec "$CTID" -- apt upgrade -y

printf "\n==============================\n"
printf "install nginx...\n"
printf "\n==============================\n"
pct exec "$CTID" -- apt install -y nginx

printf "\n==============================\n"
printf "install MariaDB server...\n"
printf "\n==============================\n"
pct exec "$CTID" -- apt install -y mariadb-server

printf "\n==============================\n"
printf "install PHP en modules...\n"
printf "\n==============================\n"
pct exec "$CTID" -- apt install -y php-fpm php-mysql

printf "\n==============================\n"
printf "detect PHP version...\n"
PHP_VERSION=$(pct exec "$CTID" -- php -v | grep -oP 'PHP \K[0-9]+\.[0-9]+' | head -1)
PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
PHP_FPM_SOCK="/var/run/php/php${PHP_VERSION}-fpm.sock"

printf "Detected PHP version: %s\n" "$PHP_VERSION"
printf "PHP-FPM service: %s\n" "$PHP_FPM_SERVICE"
printf "PHP-FPM socket: %s\n" "$PHP_FPM_SOCK"

printf "\n==============================\n"
printf "start and enable MariaDB...\n"
printf "\n==============================\n"
pct exec "$CTID" -- systemctl start mariadb
pct exec "$CTID" -- systemctl enable mariadb

printf "\n==============================\n"
printf "making WordPress database...\n"
pct exec "$CTID" -- mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
pct exec "$CTID" -- mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
pct exec "$CTID" -- mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
pct exec "$CTID" -- mysql -e "FLUSH PRIVILEGES;"

printf "\n==============================\n"
printf "making WordPress directory...\n"
pct exec "$CTID" -- mkdir -p "$WP_DIR"

printf "\n==============================\n"
printf "check if WordPress is already installed...\n"
if pct exec "$CTID" -- [ -f "$WP_DIR/wp-config.php" ]; then
    printf "WordPress is already installed at %s\n" "$WP_DIR"
    printf "Skipping download and installation.\n"
else
    printf "WordPress not found. Downloading and installing...\n"
    pct exec "$CTID" -- bash -c "cd /tmp && wget -q ${WP_URL} && tar -xzf latest.tar.gz && mv wordpress/* ${WP_DIR}/ && rm -rf wordpress latest.tar.gz"
fi

printf "\n==============================\n"
printf "set WordPress owner and group...\n"
pct exec "$CTID" -- chown -R www-data:www-data "$WP_DIR"
pct exec "$CTID" -- chmod -R 755 "$WP_DIR"

printf "\n==============================\n"
printf "configure nginx for WordPress...\n"
pct exec "$CTID" -- bash -c "cat > /etc/nginx/sites-available/wordpress << 'EOF'
server {
    listen 80;
    server_name $LXC_IP;

    root ${WP_DIR};
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_FPM_SOCK};
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
"

printf "\n==============================\n"
printf "enable nginx site...\n"
if pct exec "$CTID" -- [ -L /etc/nginx/sites-enabled/wordpress ]; then
    printf "Symbolic link for WordPress site already exists.\n"
else
    printf "Creating symbolic link for WordPress site...\n"
    pct exec "$CTID" -- bash -c "rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress"
fi

printf "\n==============================\n"
printf "start PHP-FPM...\n"
printf "\n==============================\n"
pct exec "$CTID" -- systemctl start "$PHP_FPM_SERVICE"
pct exec "$CTID" -- systemctl enable "$PHP_FPM_SERVICE"

printf "\n==============================\n"
printf "testen and restart nginx...\n"
printf "\n==============================\n"
pct exec "$CTID" -- nginx -t
pct exec "$CTID" -- systemctl restart nginx
pct exec "$CTID" -- systemctl enable nginx

printf "\n==============================\n"
printf "WordPress is installed.\n"
printf "\n==============================\n"

printf "IP: %s\n" "$LXC_IP"
printf "Database user: %s\n" "$DB_USER"
printf "Database name: %s\n" "$DB_NAME"
printf "WordPress directory: %s\n" "$WP_DIR"

printf "\n==============================\n"