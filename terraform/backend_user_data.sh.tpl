#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl git
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs build-essential

cd /opt
if [ ! -d /opt/book-review-app ]; then
  git clone ${repo_url} /opt/book-review-app
fi

cd /opt/book-review-app/backend
cat > .env <<EOF
DB_HOST=${db_host}
DB_PORT=3306
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASS=${db_password}
DB_DIALECT=mysql
DB_SSL=false
PORT=3001
JWT_SECRET=${jwt_secret}
ALLOWED_ORIGINS=${allowed_origins}
EOF

npm install

cat > /etc/systemd/system/bookreview-backend.service <<'EOF'
[Unit]
Description=Book Review Backend (Node.js)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/book-review-app/backend
ExecStart=/usr/bin/node /opt/book-review-app/backend/src/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bookreview-backend
systemctl restart bookreview-backend