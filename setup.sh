#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }

GIT_REPO="git@github.com:diemdangtuan/via88new.git"
DB_USER="bongda"; DB_PASS="Khoakhoa@1"; DB_NAME="bongda88"; MYSQL_ROOT_PASS="Khoakhoa@1"

log "Installing packages..."
apt-get update -qq
apt-get install -y -qq curl wget git nginx mariadb-server mariadb-client redis-server \
  php7.4 php7.4-fpm php7.4-cli php7.4-mysql php7.4-mbstring php7.4-xml php7.4-curl php7.4-bcmath php7.4-gd

log "Installing Node.js 20 + PM2..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs
npm install -g pm2

log "Installing Git LFS..."
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
apt-get install -y -qq git-lfs; git lfs install

log "Installing Composer..."
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer; rm composer-setup.php

log "MySQL setup..."
service mariadb start; sleep 2
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF
mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

log "Clone repo..."
cd /root; rm -rf backup789
git clone ${GIT_REPO} backup789; cd backup789; git lfs pull

log "Restore DB..."
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
gunzip < bongda88.sql.gz | mysql -u root -p"${MYSQL_ROOT_PASS}" ${DB_NAME}

log "Extract source..."
tar xzf src/taixiu-server.tgz -C /var/www/   # game server
tar xzf src/789club.tgz       -C /var/www/   # static game files (/taixiu-game/)
tar xzf src/via888.tgz        -C /var/www/   # Laravel website

log "npm install..."
cd /var/www/taixiu-server && npm install

log "Laravel setup..."
cd /var/www/via888
cp /root/backup789/.env.via888 .env
composer install --no-dev --no-interaction 2>&1 || true
php artisan optimize 2>/dev/null || true

log "Nginx config..."
mkdir -p /etc/nginx/conf.d
cp /root/backup789/nginx/conf.d/via888.conf /etc/nginx/conf.d/
cp /root/backup789/nginx/nginx.conf /etc/nginx/nginx.conf
# Write clean game config (chỉ giữ /taixiu-game/ + /client, bỏ /68ClubA/ + /apiv1/)
cat > /etc/nginx/conf.d/taixiu-game.inc << 'NGINX'
# TaiXiu Game - Cocos Creator build
location /taixiu-game/ {
    alias /var/www/789club/public/;
    try_files $uri $uri/ /taixiu-game/index.html;
}
# WebSocket proxy for TaiXiu game client
location /client {
    proxy_pass http://127.0.0.1:3001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 86400;
}
NGINX
nginx -t && systemctl restart nginx
systemctl restart php7.4-fpm

log "Starting PM2 (taixiu-server)..."
pm2 kill 2>/dev/null || true
cd /var/www/taixiu-server && pm2 start server.js --name taixiu-server
pm2 save

log "Crontab..."
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/via888/artisan schedule:run >> /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * curl -s --max-time 120 'http://127.0.0.1/api/cron/settle-bets?token=bongda88cron2024' >/dev/null 2>&1") | crontab -

IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
echo ""
log "=========================================="
log "RESTORE COMPLETE!"
log "=========================================="
echo ""
log "Trang chính:  http://${IP}/"
log "Game:         http://${IP}/tai-xiu-mobile"
log "Admin:        http://${IP}/portal/home"
log "Game assets:  http://${IP}/taixiu-game/"
log "PM2:          pm2 list (1 process: taixiu-server)"
echo ""
