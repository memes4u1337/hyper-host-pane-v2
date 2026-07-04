#!/bin/bash
# diagnose.sh — быстрая проверка, почему панель не открывается снаружи
# Запускать на сервере: sudo bash diagnose.sh

echo "===== 1. Статус сервиса панели ====="
systemctl status hyper-host --no-pager | head -n 10

echo ""
echo "===== 2. Отвечает ли панель локально (127.0.0.1:8088) ====="
curl -s -o /dev/null -w "HTTP статус: %{http_code}\n" http://127.0.0.1:8088 || echo "НЕ ОТВЕЧАЕТ"

echo ""
echo "===== 2.5. Подключён ли конфиг панели в nginx ====="
if [ -f /etc/nginx/sites-enabled/hyper-host.conf ]; then
  echo "✅ /etc/nginx/sites-enabled/hyper-host.conf найден"
else
  echo "❌ Конфиг hyper-host.conf НЕ найден в sites-enabled — nginx не знает про панель."
  echo "   Запусти: sudo bash fix_nginx.sh"
fi

echo ""
echo "===== 3. Статус nginx ====="
systemctl status nginx --no-pager | head -n 10
nginx -t

echo ""
echo "===== 4. Отвечает ли nginx на 80 порту ====="
curl -s -o /dev/null -w "HTTP статус: %{http_code}\n" http://127.0.0.1:80 || echo "НЕ ОТВЕЧАЕТ"

echo ""
echo "===== 5. Локальный (внутренний, LAN) IP этого сервера ====="
hostname -I

echo ""
echo "===== 6. Внешний (белый) IP, который видит интернет ====="
EXT_IP=$(curl -s ifconfig.me)
echo "$EXT_IP"

echo ""
echo "===== 7. Что сейчас показывает DNS для hyper-host.pw ====="
DNS_IP=$(dig +short hyper-host.pw | tail -n1)
echo "DNS указывает на: ${DNS_IP:-(ничего не найдено)}"

if [ "$DNS_IP" == "$EXT_IP" ]; then
  echo "✅ DNS настроен верно — домен указывает на твой внешний IP."
else
  echo "⚠️  DNS НЕ совпадает с внешним IP сервера. Нужно поправить A-запись у регистратора домена."
fi

echo ""
echo "===== 8. Открыты ли порты изнутри (ufw) ====="
ufw status 2>/dev/null || echo "ufw не установлен/не активен"

echo ""
echo "===== ИТОГ ====="
echo "Внешний IP сервера: $EXT_IP"
echo "Локальный (LAN) IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "Если ты дома за роутером — проброс портов (port forwarding) 80,443,21,21100-21110"
echo "на локальный IP этого сервера ОБЯЗАТЕЛЕН, иначе снаружи ничего не достучится,"
echo "даже если все сервисы работают идеально."
