#!/bin/bash
# uninstall_hestia.sh — полное удаление HestiaCP с сервера Ubuntu
# Запускать от root: sudo bash uninstall_hestia.sh

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Запусти скрипт от root (sudo bash uninstall_hestia.sh)"
  exit 1
fi

echo ">>> Останавливаю сервисы Hestia..."
systemctl stop hestia 2>/dev/null || true
systemctl disable hestia 2>/dev/null || true

echo ">>> Удаляю пакеты, поставленные Hestia (nginx/apache/exim/dovecot/vsftpd/mysql, если ставились установщиком Hestia)..."
# ВНИМАНИЕ: если на сервере кроме Hestia есть другие сайты/базы — не гони этот блок,
# закомментируй то, что тебе жалко (например MySQL с боевыми базами).
apt-get remove --purge -y \
  hestia hestia-nginx hestia-php \
  nginx nginx-common \
  apache2 apache2-* \
  exim4 exim4-* \
  dovecot-core dovecot-imapd dovecot-pop3d \
  vsftpd proftpd-basic \
  roundcube roundcube-* \
  clamav clamav-daemon spamassassin \
  fail2ban \
  bind9 bind9utils \
  vzftp \
  2>/dev/null || true

echo ">>> Чищу директории Hestia..."
rm -rf /usr/local/hestia
rm -rf /etc/hestia
rm -rf /var/log/hestia
rm -rf /root/.bashrc.hestia
rm -f /etc/cron.d/hestia*

echo ">>> Убираю строки Hestia из /root/.bashrc и /etc/profile.d..."
sed -i '/hestia/Id' /root/.bashrc 2>/dev/null || true
rm -f /etc/profile.d/hestia.sh

echo ">>> Убираю firewall-правила Hestia (iptables/ufw)..."
if command -v ufw >/dev/null 2>&1; then
  ufw --force reset || true
fi
iptables -F 2>/dev/null || true

echo ">>> Чищу systemd unit-файлы, если остались..."
rm -f /etc/systemd/system/hestia.service
systemctl daemon-reload

echo ">>> Автоудаление ненужных зависимостей..."
apt-get autoremove -y
apt-get autoclean -y

echo ""
echo "=== Hestia удалена. ==="
echo "Проверь вручную:"
echo "  - crontab -l         (могли остаться задачи Hestia)"
echo "  - crontab -l -u admin"
echo "  - ls /home           (остались ли папки пользователей Hestia, например /home/admin/web)"
echo "  - mysql -u root -p -e 'show databases;'  (если стояла MySQL от Hestia и она тебе не нужна)"
echo ""
echo "Дальше ставь Hyper-Host: bash install.sh"
