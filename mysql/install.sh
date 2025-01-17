#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "${0} is not running as root. please run as root."
    exit 1
fi

echo "[INFO] Configuring Databases.."
systemctl enable mariadb
systemctl start mariadb

DB_USER="passbolt"
DB_PASS="password"
DATABASE="passbolt"

mysql -e "
	DROP DATABASE IF EXISTS ${DATABASE};
	DROP USER IF EXISTS '${DB_USER}'@'localhost';
	CREATE DATABASE ${DATABASE} CHARACTER 

