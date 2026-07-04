#!/bin/bash
# create_domain.sh <domain> <docroot>
set -e
DOMAIN="$1"
DOCROOT="$2"

if [ -z "$DOMAIN" ] || [ -z "$DOCROOT" ]; then
  echo "usage: create_domain.sh <domain> <docroot>"
  exit 1
fi

mkdir -p "$DOCROOT"
chown -R www-data:www-data "$(dirname "$DOCROOT")"

if [ ! -f "$DOCROOT/index.html" ]; then
  cat > "$DOCROOT/index.html" <<EOF
<h1>${DOMAIN} works via Hyper-Host</h1>
EOF
fi

cat > "/etc/nginx/sites-available/${DOMAIN}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    root ${DOCROOT};
    index index.html index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf "/etc/nginx/sites-available/${DOMAIN}.conf" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
nginx -t
systemctl reload nginx
echo "domain ${DOMAIN} created"
