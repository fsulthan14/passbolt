#!/bin/bash

set -euo pipefail

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root!" >&2
  exit 1
fi

## Default Values for Optional Arguments
dirName=$(dirname "$0")
WEB_USER="www-data"
ADMIN_EMAIL=""
FIRST_NAME=""
LAST_NAME=""
DB_USERNAME="passbolt"
DB_NAME="passbolt"
SMTP_ADDRESS="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASS=""
PARENTDIR="/opt"
WEBDIR="/var/www"
USERNAME="passbolt"
PASSBOLT_URL="$(hostname -I)"
SSL_CONFIG="false"

## Usage Function
usage() {
  cat << EOF

Usage: $0 [OPTIONS]

This script installs and configures Passbolt on your system.

Options:
  -e <ADMIN_EMAIL>      Set the administrator email address (required).
  -f <FIRST_NAME>       Set the administrator's first name (required).
  -l <LAST_NAME>        Set the administrator's last name (required).
  -u <SMTP_USER>        Set the SMTP username for email sending (required).
  -p <SMTP_PASS>        Set the SMTP password for email sending (required).

Optional Arguments:
  -d <DB_USERNAME>      Set the database username. Default: passbolt.
  -m <DB_NAME>          Set the database name. Default: passbolt.
  -s <SMTP_ADDRESS>     Set the SMTP server address. Default: smtp.gmail.com.
  -t <SMTP_PORT>        Set the SMTP server port. Default: 587.
  -w <WEB_USER>         Set the web server user. Default: www-data.
  -U <PASSBOLT_URL> 	Set the passbolt URL. Default is HTTP: IP Address Passbolt. (10.10.XX.XX).
  -S <SSL_CONFIG>       Set the passbolt with HTTPS. Default is False. Set True to activate.
  -h                    Show this help message and exit.

Examples:
  Install Passbolt with default values:
    ./$0 -e "admin@example.com" -f "John" -l "Doe" -u "smtp_user" -p "smtp_pass"

  Install Passbolt with custom database configuration:
    ./$0 -e "admin@example.com" -f "John" -l "Doe" -u "smtp_user" -p "smtp_pass" \\
            -d "custom_user" -m "custom_db"

  Install Passbolt with custom SMTP server:
    ./$0 -e "admin@example.com" -f "John" -l "Doe" -u "smtp_user" -p "smtp_pass" \\
            -s "smtp.example.com" -t "465"

  Install Passbolt with HTTPS/SSL:
    ./$0 -e "admin@example.com" -f "John" -l "Doe" -u "smtp_user" -p "smtp_pass" \\
            -U "passbolt.local" -S "true"

EOF
}

## Parse Arguments
while getopts "e:f:l:u:d:s:p:m:w:U:S:h" opt; do
  case $opt in
    e) ADMIN_EMAIL="${OPTARG}" ;;  # Email Admin
    f) FIRST_NAME="${OPTARG}" ;;  # Nama Depan Admin
    l) LAST_NAME="${OPTARG}" ;;   # Nama Belakang Admin
    u) SMTP_USER="${OPTARG}" ;;   # SMTP User
    p) SMTP_PASS="${OPTARG}" ;;   # SMTP Password
    d) DB_USERNAME="${OPTARG}" ;; # Database Username
    s) SMTP_ADDRESS="${OPTARG}" ;; # SMTP Server Address
    m) DB_NAME="${OPTARG}" ;;     # Database Name
    w) WEB_USER="${OPTARG}" ;;    # Web Server User
    U) PASSBOLT_URL="${OPTARG}" ;; # Passbolt URL/Domain/IP
    S) SSL_CONFIG="${OPTARG}" ;; # Set True to enable HTTPS
    h) 
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Invalid option."
      usage
      exit 1
      ;;
  esac
done

## Validate Required Arguments
if [[ -z "$ADMIN_EMAIL" || -z "$FIRST_NAME" || -z "$LAST_NAME" || -z "$SMTP_USER" || -z "$SMTP_PASS" ]]; then
  echo "[ERROR] Missing required arguments!"
  usage
  exit 1
fi

## Info Exec Script
echo "Executing ${0} with the following arguments:"
echo "ADMIN_EMAIL: $ADMIN_EMAIL"
echo "FIRST_NAME: $FIRST_NAME"
echo "LAST_NAME: $LAST_NAME"
echo "SMTP_USER: $SMTP_USER"
echo "SMTP_PASS: $SMTP_PASS"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_NAME: $DB_NAME"
echo "SMTP_ADDRESS: $SMTP_ADDRESS"
echo "SMTP_PORT: $SMTP_PORT"
echo "WEB_USER: $WEB_USER"
echo "PARENTDIR: $PARENTDIR"
echo "WEBDIR: $WEBDIR"
echo "PASSBOLT URL: $PASSBOLT_URL"
echo "SSL CONFIG: $SSL_CONFIG"

echo "[INFO] Starting Installation.."

# Create Databases & Users
echo "[INFO] Create Databases.."
DB_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
mysql -e "
  DROP DATABASE IF EXISTS \`${DB_NAME}\`;
  DROP USER IF EXISTS '${DB_USERNAME}'@'localhost';
  CREATE DATABASE \`${DB_NAME}\`;
  GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* to '${DB_USERNAME}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
  FLUSH PRIVILEGES;
"

echo "[INFO] Create Passbolt User.."
mkdir -p ${PARENTDIR}/${USERNAME}
id ${USERNAME} &> /dev/null && userdel -rf ${USERNAME} &>/dev/null
getent group ${USERNAME} &> /dev/null && groupdel ${USERNAME} &>/dev/null

groupadd ${USERNAME}
useradd -m -s /bin/bash -c "" -d ${PARENTDIR}/${USERNAME} -u 1100 -g ${USERNAME} -G ${WEB_USER} ${USERNAME}

# Installing Passbolt

echo "[INFO] Download Passbolt..."
cd /tmp
sudo -u ${WEB_USER} git clone https://github.com/passbolt/passbolt_api.git
cp -R /tmp/passbolt_api/* ${PARENTDIR}/${USERNAME}
cd ${PARENTDIR}/${USERNAME}
chown -R ${WEB_USER}.${WEB_USER} ${PARENTDIR}/${USERNAME} ${WEBDIR}
sudo -u ${WEB_USER} composer install --no-dev --no-interaction
chmod +x ${PARENTDIR}/${USERNAME}/bin/cake
chmod -w ${PARENTDIR}/${USERNAME}/config/jwt

echo "[INFO] Installing GPG Key..."
rm -rf ${WEBDIR}/.gnupg/openpgp-revocs.d/*
sudo -u ${WEB_USER} gpg --quick-gen-key --pinentry-mode=loopback --passphrase '' '${FIRST_NAME} ${LAST_NAME} <${ADMIN_EMAIL}>' default default never
sudo -u ${WEB_USER} gpg --armor --export ${ADMIN_EMAIL} | sudo tee ${PARENTDIR}/${USERNAME}/config/gpg/serverkey.asc > /dev/null
sudo -u ${WEB_USER} gpg --armor --export-secret-keys ${ADMIN_EMAIL} | sudo tee ${PARENTDIR}/${USERNAME}/config/gpg/serverkey_private.asc > /dev/nul

echo "[INFO] Set Up Passbolt Configuration..."
PASSBOLT_GPG_KEY=$(ls ${WEBDIR}/.gnupg/openpgp-revocs.d/ | sed 's/\.rev$//')
if [[ "${SSL_CONFIG}" != "true" ]]; then
	sed -i "s/SSL_CONFIG/http/g" ${dirName}/passbolt.php
else
	sed -i "s/SSL_CONFIG/https/g" ${dirName}/passbolt.php
fi
sed -i -e "s/PASSBOLT_GPG_KEY/${PASSBOLT_GPG_KEY}/g" \
       -e "s/ADMIN_EMAIL/${ADMIN_EMAIL}/g" \
       -e "s/FIRST_NAME/${FIRST_NAME}/g" \
       -e "s/PASSBOLT_URL/${PASSBOLT_URL}/g" \
       -e "s/DB_USERNAME/${DB_USERNAME}/g" \
       -e "s/DB_PASSWORD/${DB_PASSWORD}/g" \
       -e "s/DB_NAME/${DB_NAME}/g" \
       -e "s/SMTP_ADDRESS/${SMTP_ADDRESS}/g" \
       -e "s/SMTP_PORT/${SMTP_PORT}/g" \
       -e "s/SMTP_USER/${SMTP_USER}/g" \
       -e "s/SMTP_PASS/${SMTP_PASS}/g" \
       -e "s/PASSBOLT_EMAIL_USER/${PASSBOLT_EMAIL_USER}/g" \
       "${dirName}/passbolt.php"

cp ${dirName}/passbolt.php ${PARENTDIR}/${USERNAME}/config
ln -sf ${PARENTDIR}/${USERNAME} ${WEBDIR}/html/passbolt 
chown -R ${WEB_USER}.${WEB_USER} ${PARENTDIR}/${USERNAME} ${WEBDIR}

echo "[INFO] Installing Passbolt..."
sudo su -s /bin/bash -c "/opt/passbolt/bin/cake passbolt install \
	--force \
	--admin-first-name='${FIRST_NAME}' \
	--admin-last-name='${LAST_NAME}' \
	--admin-username='${ADMIN_EMAIL}'" ${WEB_USER}

echo "[INFO] Set Up Nginx Configuration..."
sed -i "s/%ADDRESS%/${PASSBOLT_URL}/g" ${dirName}/nginx.conf.template
cp ${dirName}/nginx.conf.template /etc/nginx/sites-enabled
systemctl reload nginx

