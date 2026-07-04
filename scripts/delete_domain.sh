#!/bin/bash
# delete_domain.sh <domain>
set -e
DOMAIN="$1"
[ -z "$DOMAIN" ] && { echo "usage: delete_domain.sh <domain>"; exit 1; }

rm -f "/etc/nginx/sites-enabled/${DOMAIN}.conf"
rm -f "/etc/nginx/sites-available/${DOMAIN}.conf"
nginx -t
systemctl reload nginx
echo "domain ${DOMAIN} removed (файлы сайта в /var/www/${DOMAIN} не тронуты, удали вручную если нужно)"
