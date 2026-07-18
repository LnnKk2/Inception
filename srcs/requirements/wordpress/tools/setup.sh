#!/bin/bash

MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
DOMAIN_NAME=$DOMAIN_NAME
WEBSITE_NAME=$WEBSITE_NAME
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_NAME=$ADMIN_NAME
SCND_USER_NAME=$SCND_USER_NAME
SCND_USER_EMAIL=$SCND_USER_EMAIL
WP_DB_PASS=$(cat /run/secrets/wordpress_db_password)
WORDPRESS_ADMIN_PASSWORD=$(cat /run/secrets/wordpress_admin_password)
WORDPRESS_SCNDUSER_PASSWORD=$(cat /run/secrets/wordpress_scnduser_password)


# permet d attendre que mariadb soit bien up
while ! mysqladmin ping -h mariadb -u $MYSQL_USER -p$WP_DB_PASS --silent; do
    echo "En attente de MariaDB..."
    sleep 2
done

# installe wordpress d un coup si fichier config n existe pas deja
if [ ! -f "wp-config.php" ]; then
    wp core download --allow-root
    wp config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$WP_DB_PASS" \
        --dbhost="mariadb" \
        --allow-root
    wp core install \
        --url="$DOMAIN_NAME" \
        --title="$WEBSITE_NAME" \
        --admin_user="$ADMIN_NAME" \
        --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
        --admin_email="$ADMIN_EMAIL" \
        --skip-email \
        --allow-root
    wp user create "$SCND_USER_NAME" "$SCND_USER_EMAIL" \
        --role=author \
        --user_pass="$WORDPRESS_SCNDUSER_PASSWORD" \
        --allow-root
fi

# donne les bonne permissions
chown -R www-data:www-data /var/www/html

# exec php
exec php-fpm8.2 -F