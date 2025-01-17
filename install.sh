#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "${0} is not running as root. please run as root."
    exit 1
fi

### GLOBAL VARIABLES
dirName=$(dirName)

## Installing Dependencies
echo "[INFO] Installing Dependencies..."
apt-get update -y && sudo apt-get upgrade -y
echo "[INFO] Done..."

## Installing Databases
${dirName}/mysql/install.sh
