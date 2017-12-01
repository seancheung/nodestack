#!/bin/bash
set -e

MYSQL_INITSQL=/var/run/mysql/.init

function ensure_dir()
{
    for dir in "/var/run/mysql" "/var/log/mysql" "/var/opt/mysql"; do
        mkdir -p $dir
        chown mysql:mysql $dir
    done
    for dir in "/var/run/redis" "/var/log/redis" "/var/opt/redis"; do
        mkdir -p $dir
        chown redis:redis $dir
    done
    for dir in "/var/run/mongodb" "/var/log/mongodb" "/var/opt/mongodb"; do
        mkdir -p $dir
        chown mongodb:mongodb $dir
    done
    for dir in "/var/run/elasticsearch" "/var/log/elasticsearch" "/var/opt/elasticsearch" \
        "/var/log/kibana" "/var/run/logstash" "/var/log/logstash" "/var/opt/logstash"; do
        mkdir -p $dir
        chown elk:elk $dir
    done
    for dir in "/var/run/nginx" "/var/log/nginx"; do
        mkdir -p $dir
        chown nginx:nginx $dir
    done
}

function boot_mysql()
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

    # MYSQL_USER: "username:password" or "username". password will be the same as username if omitted.
    # For multiple user creation, seperate them with ";".
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

    # MYSQL_DATABASE: "username@database" or "database". username will be the same as database if omitted.
    # User will be created(with password the same as username) if not exist.
    # For multiple database creation, seperate them with ";".
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

function init_nginx()
{
    if [ -f "/etc/nginx/conf.d/default.conf" ]; then
        mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default
    fi

    if [ -f "/etc/nginx/conf.d/kibana.conf" ] && [ ! -f "/etc/nginx/kibana.auth" ]; then
        IFS=':'; credentials=($1); unset IFS;
        if [ ${#credentials[@]} -eq 1 ]; then
            username=${credentials[0]}
            password=$username
        elif [ ${#credentials[@]} -eq 2 ]; then
            username=${credentials[0]}
            password=${credentials[1]}
        else
            echo "[Nginx] invalid credentials in $1"
            exit 1
        fi
        htpasswd -b -c /etc/nginx/kibana.auth "$username" "$password"
        sed -i '/auth_basic/s/^\(\s*\)#/\1/g' /etc/nginx/conf.d/kibana.conf 
    fi
}

ensure_dir

if [ ! -f "$MYSQL_INITSQL" ]; then
    boot_mysql "$MYSQL_INITSQL"
fi

# KIBANA_AUTH: "username:password" or "username". password will be the same as username if omitted
if [ -n "$KIBANA_AUTH" ]; then
    init_nginx "$KIBANA_AUTH"
fi

exec "$@"