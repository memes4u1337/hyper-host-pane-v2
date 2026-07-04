#!/bin/bash
# issue_ssl.sh <domain>
set -e
DOMAIN="$1"
[ -z "$DOMAIN" ] && { echo "usage: issue_ssl.sh <domain>"; exit 1; }

command -v certbot >/dev/null 2>&1 || { echo "certbot не установлен"; exit 1; }

certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" --non-interactive --agree-tos -m admin@${DOMAIN} --redirect
echo "ssl issued for ${DOMAIN}"
