#!/bin/bash
# install.sh — установка панели Hyper-Host на чистый Ubuntu (20.04/22.04/24.04)
# Запускать из корня репозитория: sudo bash install.sh

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Запусти от root: sudo bash install.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/hyper-host"

echo ">>> Обновляю систему и ставлю зависимости..."
apt-get update -y
apt-get install -y python3 python3-venv python3-pip nginx vsftpd certbot python3-certbot-nginx sudo

echo ">>> Копирую файлы панели в ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp -r "$REPO_DIR/app" "$INSTALL_DIR/app"
cp -r "$REPO_DIR/scripts" "$INSTALL_DIR/scripts"
chmod +x "$INSTALL_DIR"/scripts/*.sh

echo ">>> Создаю виртуальное окружение и ставлю зависимости Python..."
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/app/requirements.txt"

echo ">>> Инициализирую базу данных панели..."
"$INSTALL_DIR/venv/bin/python" -c "import sys; sys.path.insert(0,'$INSTALL_DIR/app'); from app import init_db; init_db()"

echo ""
echo ">>> Создание учётки администратора панели"
read -rp "Логин администратора: " HH_ADMIN_USER
read -rsp "Пароль администратора: " HH_ADMIN_PASS
echo ""
"$INSTALL_DIR/venv/bin/python" - <<PYEOF
import sys
sys.path.insert(0, "$INSTALL_DIR/app")
from app import get_db, init_db
import sqlite3
from werkzeug.security import generate_password_hash
db = sqlite3.connect("$INSTALL_DIR/app/hyperhost.db")
db.execute("INSERT OR REPLACE INTO users (id, username, password_hash) VALUES (1, ?, ?)",
           ("$HH_ADMIN_USER", generate_password_hash("$HH_ADMIN_PASS")))
db.commit()
PYEOF

echo ">>> Настраиваю vsftpd (chroot-режим для FTP-аккаунтов)..."
cp /etc/vsftpd.conf /etc/vsftpd.conf.bak.$(date +%s) 2>/dev/null || true
cat > /etc/vsftpd.conf <<'EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
userlist_enable=YES
userlist_deny=NO
userlist_file=/etc/vsftpd.userlist
pasv_enable=YES
pasv_min_port=21100
pasv_max_port=21110
EOF
touch /etc/vsftpd.userlist
systemctl restart vsftpd
systemctl enable vsftpd

echo ">>> Открываю нужные порты в ufw (если ufw активен)..."
if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  ufw allow 21/tcp || true
  ufw allow 21100:21110/tcp || true
fi

echo ">>> Настраиваю sudoers, чтобы панель (root-процесс) могла дергать скрипты без интерактивного пароля..."
cat > /etc/sudoers.d/hyper-host <<EOF
root ALL=(ALL) NOPASSWD: ${INSTALL_DIR}/scripts/*.sh
EOF
chmod 440 /etc/sudoers.d/hyper-host

echo ">>> Ставлю systemd unit для панели..."
RANDOM_SECRET=$(openssl rand -hex 24)
sed "s#CHANGE_ME_RANDOM_SECRET#${RANDOM_SECRET}#" "$REPO_DIR/systemd/hyper-host.service" > /etc/systemd/system/hyper-host.service
systemctl daemon-reload
systemctl enable hyper-host
systemctl restart hyper-host

echo ">>> Настраиваю nginx для домена hyper-host.pw..."
cp "$REPO_DIR/nginx/hyper-host.conf" /etc/nginx/sites-available/hyper-host.conf
ln -sf /etc/nginx/sites-available/hyper-host.conf /etc/nginx/sites-enabled/hyper-host.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
systemctl enable nginx

echo ""
echo "======================================================"
echo " Hyper-Host установлен!"
echo " Панель локально слушает: http://127.0.0.1:8088"
echo " Через nginx доступна по: http://hyper-host.pw"
echo ""
echo " ВАЖНО: чтобы hyper-host.pw реально открывался —"
echo " в DNS-панели домена создай A-запись:"
echo "   hyper-host.pw   ->  $(curl -s ifconfig.me || echo 'IP_ЭТОГО_СЕРВЕРА')"
echo "   www.hyper-host.pw -> тот же IP"
echo ""
echo " После того как DNS обновится (проверить: dig +short hyper-host.pw),"
echo " выпусти SSL командой:"
echo "   sudo certbot --nginx -d hyper-host.pw -d www.hyper-host.pw"
echo "======================================================"
