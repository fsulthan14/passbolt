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
apt install nginx php php-{fpm,mysql,common,cli,opcache,readline,mbstring,xml,gd,curl,imagick,gnupg,ldap,imap,zip,bz2,intl,gmp} haveged composer -y
echo "[INFO] Done..."

## Installing Databases
${dirName}/mysql/install.sh
