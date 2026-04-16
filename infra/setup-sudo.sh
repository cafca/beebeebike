#!/bin/bash
# Run this with: sudo DOMAIN=beebeebike.com bash ~/beebeebike/infra/setup-sudo.sh
# Sets up nginx + SSL for the configured BeeBeeBike domain.

set -euo pipefail

DOMAIN="${DOMAIN:-beebeebike.com}"
WWW_DOMAIN="www.$DOMAIN"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-beebeebike@vincentahrend.com}"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"

echo "==> Creating nginx config for $DOMAIN"
cat > "$NGINX_CONF" <<EOF
server {
    server_name $DOMAIN $WWW_DOMAIN;

    location /tiles/ {
        proxy_pass http://127.0.0.1:3847/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        proxy_pass http://127.0.0.1:3848;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
certbot --nginx --redirect \
    -d "$DOMAIN" \
    -d "$WWW_DOMAIN" \
    --non-interactive \
    --agree-tos \
    -m "$CERTBOT_EMAIL"

echo "==> Done! $DOMAIN and $WWW_DOMAIN are ready."
