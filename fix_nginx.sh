#!/bin/bash
# fix_nginx.sh — восстанавливает структуру sites-available/sites-enabled у nginx
# и заново прописывает конфиг панели Hyper-Host.
# Запускать: sudo bash fix_nginx.sh

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Запусти от root: sudo bash fix_nginx.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ">>> Создаю папки sites-available / sites-enabled, если их нет..."
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

echo ">>> Проверяю, подключены ли эти папки в nginx.conf..."
if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
  echo ">>> Добавляю include sites-enabled в http { } блок nginx.conf..."
  cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s)
  # добавляем include перед последней закрывающей скобкой http-блока
  sed -i '/http {/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
else
  echo "    уже подключено, пропускаю."
fi

echo ">>> Копирую конфиг панели..."
cp "$REPO_DIR/nginx/hyper-host.conf" /etc/nginx/sites-available/hyper-host.conf
ln -sf /etc/nginx/sites-available/hyper-host.conf /etc/nginx/sites-enabled/hyper-host.conf

echo ">>> Убираю дефолтный сайт, если мешает..."
rm -f /etc/nginx/sites-enabled/default

echo ">>> Проверяю синтаксис и перезапускаю nginx..."
nginx -t
systemctl restart nginx

echo ""
echo "Готово. Проверка:"
curl -s -o /dev/null -w "HTTP статус на 127.0.0.1:80 -> %{http_code}\n" http://127.0.0.1:80
echo ""
echo "Если статус 200/302/301 — nginx теперь отдаёт панель."
echo "Дальше не забудь поправить DNS домена hyper-host.pw на IP: $(curl -s ifconfig.me)"
