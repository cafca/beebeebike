#!/bin/bash
# Run on server with: sudo bash ~/beebeebike/infra/update-nginx.sh
# Adds /tiles/ proxy and updates backend port in existing nginx config
set -euo pipefail

CONF="/etc/nginx/sites-available/maps.001.land"

# Add /tiles/ location block before the catch-all location /
sed -i '/location \/ {/i\
    location /tiles/ {\
        proxy_pass http://127.0.0.1:3847/;\
        proxy_http_version 1.1;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
    }\
' "$CONF"

# Update backend port from 3000 to 3848
sed -i 's|proxy_pass http://127.0.0.1:3000;|proxy_pass http://127.0.0.1:3848;|' "$CONF"

echo "==> Updated nginx config:"
cat "$CONF"

echo "==> Testing nginx config"
nginx -t

echo "==> Reloading nginx"
systemctl reload nginx

echo "==> Done!"
