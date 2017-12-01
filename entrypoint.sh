#!/bin/bash
set -e

function boot()
{
    bootfile=$1
    cat > $bootfile << EOF
    USE mysql;
    UPDATE user SET password=PASSWORD('') WHERE user='root' AND host='localhost';
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
EOF

    if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
        echo "[Mysql] updating root password"
        echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;" >> $bootfile
    fi

    # MYSQL_USER=username:password;username:password
    if [ -n "$MYSQL_USER" ]; then
        IFS=';'; users=($MYSQL_USER); unset IFS;
        for entry in "${users[@]}"; do
            IFS=':'; sub=($entry); unset IFS;
            if [ ${#sub[@]} -eq 1 ]; then
                username=${sub[0]}
                password=$username
            elif [ ${#sub[@]} -eq 2 ]; then
                username=${sub[0]}
                password=${sub[1]}
            else
                echo "[Mysql] invalid username in ${MYSQL_USER}"
                exit 1
            fi
            echo "[Mysql] create user ${username}"
            echo "CREATE USER IF NOT EXISTS '${username}'@'%' IDENTIFIED BY '${password}';" >> $bootfile
        done
    fi

    # MYSQL_DATABASE: username@database;username@database;
    if [ -n "$MYSQL_DATABASE" ]; then
        IFS=';'; ary=($MYSQL_DATABASE); unset IFS;
        for entry in "${ary[@]}"; do
            IFS='@'; sub=($entry); unset IFS;
            if [ ${#sub[@]} -eq 1 ]; then
                username=${sub[0]}
                database=$username
            elif [ ${#sub[@]} -eq 2 ]; then
                username=${sub[0]}
                database=${sub[1]}
            else
                echo "[Mysql] invalid database in ${MYSQL_DATABASE}"
                exit 1
            fi
            echo "[Mysql] create database ${database}"
            echo "CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $bootfile
            # ensure user exists
            echo "CREATE USER IF NOT EXISTS '${username}'@'%' IDENTIFIED BY '${username}';" >> $bootfile
            echo "[Mysql] grant privileges to ${username} on ${database}"
            echo "GRANT ALL PRIVILEGES ON \`${database}\`.* to '${username}'@'%';" >> $bootfile
        done
    fi

    echo "FLUSH PRIVILEGES;" >> $bootfile

    echo "[Mysql] initializing database"
    mysql_install_db --user=mysql --datadir=/var/opt/mysql
}

if [ ! -f "$MYSQL_BOOTSQL" ]; then
    boot "$MYSQL_BOOTSQL"
fi

exec "$@"