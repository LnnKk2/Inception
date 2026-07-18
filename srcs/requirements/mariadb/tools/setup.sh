#!/bin/bash

# recuperation des variables du .env -> juste avec $VAR et celles du dossier secrets avec $(cat ...)
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER
DB_ROOT_PASSWD=$(cat /run/secrets/db_root_password)
DB_USER_PASSWD=$(cat /run/secrets/db_user_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo ">>> Premier demarrage: initialisation"
    chown -R mysql:mysql /var/lib/mysql # permet de s assurer que le dosser /var/lib/mysql appartient bien a l user mysql
    mariadb-install-db --datadir=/var/lib/mysql --user mysql --basedir=/usr --skip-test-db
    cat << EOF > /tmp/init.sql
    CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` ;

    /* '%' autorise la connexion reseau -> pour que ca marche entre containers */
    CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_USER_PASSWD' ;

    /* donne tout les droits sur cette db uniquement */
    GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%' ;

    /* root en localhost pour que aucun autre container puisse acceder au root via le reseau -> securite */
    ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWD' ;

    /*recharge les privileges */
    FLUSH PRIVILEGES ;
    
EOF

    mysqld --user=mysql &

    while ! mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

    mysql < /tmp/init.sql

    mysqladmin -u root -p"$DB_ROOT_PASSWD" shutdown
    wait
    rm -f /tmp/init.sql
else
    echo "Database deja initialisee"
fi

# remplace PID = 1 par mariadb
exec mysqld --user=mysql

