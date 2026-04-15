#!/bin/bash
# Run this with: sudo bash ~/beebeebike/server/setup-sudo.sh
# Sets up nginx + SSL for maps.001.land

set -euo pipefail

DOMAIN="maps.001.land"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"

echo "==> Creating nginx config for $DOMAIN"
cat > "$NGINX_CONF" <<'EOF'
server {
    server_name maps.001.land;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    listen 80;
}
EOF

if [ ! -L "$NGINX_LINK" ]; then
    echo "==> Enabling site"
    ln -s "$NGINX_CONF" "$NGINX_LINK"
fi

echo "==> Testing nginx config"
nginx -t

echo "==> Reloading nginx"
systemctl reload nginx

echo "==> Obtaining SSL certificate"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m claude-ai@vincentahrend.com

echo "==> Done! $DOMAIN is ready."
