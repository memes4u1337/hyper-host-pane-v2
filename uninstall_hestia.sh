#!/bin/bash
# uninstall_hestia.sh — полное удаление HestiaCP с сервера Ubuntu (v2, надёжная версия)
# Запускать от root: sudo bash uninstall_hestia.sh
#
# В отличие от первой версии: не падает на первой ошибке (set +e),
# чистит apt-репозитории Hestia/nginx.org/MariaDB (из-за них nginx мог браться
# не из Ubuntu, а из левого источника со старыми конфигами доменов),
# полностью сносит /etc/nginx (включая conf.d/domains — там Hestia хранит вебсайты),
# удаляет системных пользователей admin/sites, которых создаёт Hestia.

set +e

if [ "$EUID" -ne 0 ]; then
  echo "Запусти скрипт от root (sudo bash uninstall_hestia.sh)"
  exit 1
fi

echo "=== 1. Останавливаю зависшие процессы Hestia ==="
pkill -9 -f "v-add-letsencrypt" 2>/dev/null
pkill -9 -f "hestia" 2>/dev/null
pkill -9 -f "certbot" 2>/dev/null
pkill -9 -f "acme" 2>/dev/null

echo "=== 2. Останавливаю сервисы ==="
for s in hestia hestia-nginx hestia-php nginx apache2 mariadb mysql bind9 named vsftpd fail2ban; do
  systemctl stop "$s" 2>/dev/null
  systemctl disable "$s" 2>/dev/null
done

echo "=== 3. Удаляю пакеты Hestia и веб-стека ==="
apt-get purge -y 'hestia*' 2>/dev/null
apt-get purge -y nginx nginx-common nginx-core nginx-full 2>/dev/null
apt-get purge -y apache2 apache2-bin apache2-data apache2-utils 'libapache2-mod-*' 2>/dev/null
apt-get purge -y mariadb-server mariadb-client mariadb-common mysql-server mysql-client mysql-common 2>/dev/null
apt-get purge -y phpmyadmin adminer 2>/dev/null
apt-get purge -y 'php8.*' php-common 2>/dev/null
apt-get purge -y bind9 bind9-utils bind9-host 2>/dev/null
apt-get purge -y vsftpd fail2ban 2>/dev/null
apt-get purge -y certbot python3-certbot-apache python3-certbot-nginx 2>/dev/null

echo "=== 4. Удаляю файлы и папки Hestia ==="
rm -rf /usr/local/hestia
rm -rf /etc/hestiacp
rm -rf /etc/hestia
rm -rf /var/log/hestia
rm -rf /root/hst_backups
rm -rf /usr/local/cron/hestia
rm -rf /usr/local/share/doc/hestia
rm -f /etc/cron.d/hestia*
sed -i '/hestia/Id' /root/.bashrc 2>/dev/null
rm -f /etc/profile.d/hestia.sh

echo "=== 5. Удаляю системных пользователей admin/sites (создавались Hestia) ==="
killall -u admin 2>/dev/null
killall -u sites 2>/dev/null
userdel -r admin 2>/dev/null
userdel -r sites 2>/dev/null
groupdel admin 2>/dev/null
groupdel sites 2>/dev/null

echo "=== 6. Полностью сношу nginx вместе с папками доменов (conf.d/domains и т.п.) ==="
rm -rf /etc/nginx
rm -rf /var/log/nginx
rm -rf /var/cache/nginx
rm -rf /usr/share/nginx

echo "=== 7. Сношу Apache/MySQL/PHP/BIND/vsftpd конфиги, если остались ==="
rm -rf /etc/apache2 /var/log/apache2 /var/www/html
rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/log/mariadb
rm -rf /etc/php /var/lib/php /var/log/php*
rm -rf /etc/bind /var/cache/bind /var/lib/bind
rm -rf /etc/vsftpd.conf /etc/vsftpd* /var/log/vsftpd*
rm -rf /etc/fail2ban /var/log/fail2ban.log
rm -rf /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt

echo "=== 8. ГЛАВНОЕ: удаляю apt-репозитории Hestia/nginx.org/MariaDB/PHP(ondrej) ==="
rm -f /etc/apt/sources.list.d/*hestia*
rm -f /etc/apt/sources.list.d/*nginx*
rm -f /etc/apt/sources.list.d/*mariadb*
rm -f /etc/apt/sources.list.d/*ondrej*
rm -f /usr/share/keyrings/*hestia*
rm -f /usr/share/keyrings/*nginx*
rm -f /usr/share/keyrings/*mariadb*
rm -f /etc/apt/trusted.gpg.d/*hestia*
rm -f /etc/apt/trusted.gpg.d/*nginx*
rm -f /etc/apt/trusted.gpg.d/*mariadb*

echo "=== 9. Чищу systemd unit-файлы ==="
rm -f /etc/systemd/system/hestia.service
systemctl daemon-reload
systemctl reset-failed

echo "=== 10. Обновляю apt (теперь только из стандартных репозиториев Ubuntu) ==="
apt-get autoremove --purge -y
apt-get autoclean -y
apt-get update

echo ""
echo "=== 11. Финальная проверка ==="
echo "--- Оставшиеся пакеты hestia: ---"
dpkg -l | grep -i hestia
echo "--- Оставшиеся apt-источники: ---"
grep -r "hestia\|nginx.org\|mariadb" /etc/apt/sources.list.d/ 2>/dev/null
echo "--- Занятые порты 80/443/8083/3306/53/21: ---"
ss -tulpn | grep -E ':80|:443|:8083|:3306|:53|:21'
echo ""
echo "=== Hestia удалена и apt-репозитории очищены. ==="
echo "РЕКОМЕНДУЮ ПЕРЕЗАГРУЗИТЬ СЕРВЕР: reboot"
echo "После перезагрузки ставь Hyper-Host заново: cd ~/hyper-host && sudo bash install.sh"
