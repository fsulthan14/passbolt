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

echo "[INFO] MariaDB installation"

# check if mariadb is already installed
mariadb -V &> /dev/null
if [[ ${?} == 0 ]]; then
    echo "[INFO] MariaDB is already installed!"
    exit 0
fi

DEBIAN_FRONTEND=noninteractive apt -y --fix-missing install mariadb-server
systemctl start mariadb
systemctl enable mariadb

# Display completion message
echo "[INFO] MariaDB installation completed."

