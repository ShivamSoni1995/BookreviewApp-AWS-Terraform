#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl git nginx
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs build-essential

cd /opt
if [ ! -d /opt/book-review-app ]; then
  git clone ${repo_url} /opt/book-review-app
fi

cd /opt/book-review-app/frontend
cat > .env.production <<EOF
NEXT_PUBLIC_API_URL=${public_api_url}
EOF
npm install
npm run build

cat > /etc/systemd/system/bookreview-frontend.service <<'EOF'
[Unit]
Description=Book Review Frontend (Next.js)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/book-review-app/frontend
ExecStart=/usr/bin/npm run start -- --hostname 0.0.0.0 --port 3000
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/nginx/sites-available/bookreview-frontend <<EOF
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://${backend_alb_dns}:3001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/bookreview-frontend /etc/nginx/sites-enabled/bookreview-frontend
rm -f /etc/nginx/sites-enabled/default
systemctl daemon-reload
systemctl enable nginx
systemctl enable bookreview-frontend
systemctl restart bookreview-frontend
nginx -t
systemctl restart nginx