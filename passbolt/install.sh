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

# Create Databases & Users
echo "[INFO] Create Databases.."
mysql --login-path=local -e "
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

echo "[INFO] Installing Passbolt..."
cd ${PARENTDIR}
sudo -u ${WEB_USER} git clone https://github.com/passbolt/passbolt_api.git
cd ${PARENTDIR}/${USERNAME}
sudo -u ${WEB_USER} composer install --no-dev --no-interaction
sudo su -s /bin/bash -c "/opt/passbolt/bin/cake passbolt install \
--force \
--admin-first-name='${FIRST_NAME}' \
--admin-last-name='${LAST_NAME}' \
--admin-username='${ADMIN_EMAIL}'" ${WEB_USER}

echo "[INFO] Installing GPG Key..."
sudo -u ${WEB_USER} gpg --quick-gen-key --pinentry-mode=loopback --passphrase '' '${FIRST_NAME} ${LAST_NAME} <${ADMIN_EMAIL}>' default default never

PASSBOLT_GPG_KEY="${11}"
sudo -u ${WEB_USER} gpg --armor --export ${ADMIN_EMAIL} | sudo tee /opt/passbolt/config/gpg/serverkey.asc > /dev/null
sudo -u ${WEB_USER} gpg --armor --export-secret-keys ${ADMIN_EMAIL} | sudo tee /opt/passbolt/config/gpg/serverkey_private.asc > /dev/nul

echo "[INFO] Set Up Passbolt Configuration..."
sed s/

chmod +x /opt/passbolt/bin/cake
chmod -w /opt/passbolt/config/jwt



