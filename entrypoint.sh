#!/bin/bash
set -e

bootfile=/var/run/mysql/.init

function init()
{
    cat > $bootfile << EOF
    USE mysql;
    UPDATE user SET password=PASSWORD('') WHERE user='root' AND host='localhost';
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
EOF

    if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
        echo "[Mysql] updating root password"
        echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;" >> $bootfile
    fi

    # database in this format: username:password@database;username:password@database;
    if [ -n "$MYSQL_DATABASE" ]; then
        IFS=';'; ary=($MYSQL_DATABASE); unset IFS;
        for entry in "${ary[@]}"; do
            IFS='@'; sub=($entry); unset IFS;
            if [ ${#sub[@]} -eq 1 ]; then
                database=${sub[0]}
            elif [ ${#sub[@]} -eq 2 ]; then
                database=${sub[1]}
            else
                echo "[Mysql] invalid database name in ${MYSQL_DATABASE}"
                exit 1
            fi
            if [ -z "$database" ]; then
                echo "[Mysql] missing database name in ${MYSQL_DATABASE}"
                exit 1
            fi
            username=$database
            userpass=$database
            if [ ${#sub[@]} -eq 2 ] && [ -n "${sub[0]}" ]; then
                IFS=':'; cred=(${entry[0]}); unset IFS;
                username=${cred[0]}
                if [ -n "${cred[1]}" ]; then
                    userpass=${cred[1]}
                fi
            fi
            echo "[Mysql] create database ${database} for ${username}"
            echo "CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $bootfile
            echo "GRANT ALL ON \`${userpass}\`.* to '${username}'@'%' IDENTIFIED BY '${userpass}';" >> $bootfile
        done
    fi

    echo "FLUSH PRIVILEGES;" >> $bootfile

    echo "[Mysql] initializing database"
    mysql_install_db --user=mysql --datadir=/var/opt/mysql
}

if [ ! -f "$bootfile" ]; then
    init
fi

exec "$@"