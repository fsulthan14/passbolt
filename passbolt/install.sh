#!/bin/bash

## Global Variables
dirName=$(dirName "$0")
WEB_USER="www-data"
ADMIN_EMAIL="${1}" # qihh.sulthan@gmail.com
FIRST_NAME="${2}" # Faqih
LAST_NAME="${3}" # Sulthan
PASSBOLT_URL=$(hostname -I)
DB_USERNAME="${4}" # passbolt
DB_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
DB_NAME="${5}" # passbolt
SMTP_ADDRESS="${6}" # smtp.gmail.com
SMPT_PORT="${7}" # 587
SMTP_USER="${8}" # qihh.sulthan@gmail.com
SMTP_PASS="${9}" 
PASSBOLT_EMAIL_USER="${10}" # qihh.sulthan@gmail.com
USERNAME="passbolt"
PARENTDIR="/opt"
WEBDIR="/var/www"

# Create Databases & Users
echo "[INFO] Create Databases.."
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
cp /tmp/passbolt_api/* ${PARENTDIR}/${USERNAME}
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

