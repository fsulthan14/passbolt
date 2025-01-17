#!/bin/bash

# only root should execute this script
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run as root or use sudo."
  echo
  exit 1
fi

echo
echo "[INFO] Exec ${0}"
echo

echo "[INFO] MySQL configuration"

dirName=$(dirname "$0")

#copy mysql & mysqldump to /usr/local/bin
cp ${dirName}/mysql ${dirName}/mysqldump /usr/local/bin

#copy mariadb configuration
cp ${dirName}/mariadb.cnf /etc/mysql/.

#add dummy .client.cnf for root
touch /root/.client.cnf

# Resart MariaDB
systemctl restart mariadb

echo "[INFO] MySQL configuration completed."

