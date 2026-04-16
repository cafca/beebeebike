#!/bin/bash
# Run on server with: sudo DOMAIN=beebeebike.com bash ~/beebeebike/infra/update-nginx.sh
# Adds /tiles/ proxy and updates backend port in the selected nginx config.
set -euo pipefail

DOMAIN="${DOMAIN:-beebeebike.com}"
CONF="/etc/nginx/sites-available/$DOMAIN"

if [ ! -f "$CONF" ]; then
    echo "Nginx config not found: $CONF" >&2
    exit 1
fi

if ! grep -Fq "location /tiles/" "$CONF"; then
    # Add /tiles/ location block before the catch-all location /
    sed -i '/location \/ {/i\
    location /tiles/ {\
        proxy_pass http://127.0.0.1:3847/;\
        proxy_http_version 1.1;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
    }\
' "$CONF"
fi

# Update backend port from 3000 to 3848
sed -i 's|proxy_pass http://127.0.0.1:3000;|proxy_pass http://127.0.0.1:3848;|' "$CONF"

echo "==> Updated nginx config:"
cat "$CONF"

echo "==> Testing nginx config"
nginx -t

echo "==> Reloading nginx"
systemctl reload nginx

echo "==> Done!"
