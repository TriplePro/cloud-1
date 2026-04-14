#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

CTID=150
LXC_IP="10.24.50.150"
DB_USER="wordpress_user"
DB_PASSWORD="password"
DB_NAME="wordpress"
WP_URL="https://wordpress.org/latest.tar.gz"
WP_DIR="/var/www/wordpress"

printf "\n==============================\n"
printf "install WordPress on LXC %s\n" "$CTID"

printf "\n==============================\n"
#printf "check if the container is running...\n"
#if ! pct status "$CTID" | grep -q "running"; then
#    printf "Container %s is not running. Start the container first.\n" "$CTID"
#    exit 1
#fi

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
pct exec "$CTID" -- apt update
pct exec "$CTID" -- apt upgrade -y

printf "\n==============================\n"
printf "install nginx...\n"
pct exec "$CTID" -- apt install -y nginx

printf "\n==============================\n"
printf "install MariaDB server...\n"
pct exec "$CTID" -- apt install -y mariadb-server

printf "\n==============================\n"
printf "install PHP en modules...\n"
pct exec "$CTID" -- apt install -y php-fpm php-mysql

printf "\n==============================\n"
printf "start and enable MariaDB...\n"
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
printf "download and unzip WordPress...\n"
pct exec "$CTID" -- bash -c "cd /tmp && wget -q ${WP_URL} && tar -xzf latest.tar.gz && mv wordpress/* ${WP_DIR}/ && rm -rf wordpress latest.tar.gz"


printf "\n==============================\n"
printf "set WordPress owner and group...\n"
pct exec "$CTID" -- chown -R www-data:www-data "$WP_DIR"
pct exec "$CTID" -- chmod -R 755 "$WP_DIR"


printf "\n==============================\n"
printf "making wp-config.php...\n"
pct exec "$CTID" -- bash -c "cp ${WP_DIR}/wp-config-sample.php ${WP_DIR}/wp-config.php"


printf "\n==============================\n"
printf "set database credentials in wp-config.php...\n"
pct exec "$CTID" -- sed -i "s/database_name_here/${DB_NAME}/g" "${WP_DIR}/wp-config.php"
pct exec "$CTID" -- sed -i "s/username_here/${DB_USER}/g" "${WP_DIR}/wp-config.php"
pct exec "$CTID" -- sed -i "s/password_here/${DB_PASSWORD}/g" "${WP_DIR}/wp-config.php"


printf "\n==============================\n"
printf "configure nginx for WordPress...\n"
pct exec "$CTID" -- bash -c "cat > /etc/nginx/sites-available/wordpress << 'EOF'
server {
    listen 80;
    server_name _;

    root ${WP_DIR};
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
"

printf "\n==============================\n"
printf "enable nginx site...\n"
pct exec "$CTID" -- bash -c "rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress"


printf "\n==============================\n"
printf "start PHP-FPM...\n"
pct exec "$CTID" -- systemctl start php-fpm
pct exec "$CTID" -- systemctl enable php-fpm


printf "\n==============================\n"
printf "testen and restart nginx...\n"
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