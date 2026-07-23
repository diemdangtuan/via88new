#!/bin/bash
# ============================================================
# setup.sh - Restore VPS (chỉ port 80)
# Chạy: bash setup.sh
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $1"; }

GIT_REPO="git@github.com:diemdangtuan/via88new.git"
DB_USER="bongda"
DB_PASS="Khoakhoa@1"
DB_NAME="bongda88"
MYSQL_ROOT_PASS="Khoakhoa@1"

# ===== 1. System packages =====
log "Installing packages..."
apt-get update -qq
apt-get install -y -qq curl wget git nginx mariadb-server mariadb-client \
  redis-server \
  php7.4 php7.4-fpm php7.4-cli php7.4-mysql php7.4-mbstring php7.4-xml php7.4-curl php7.4-bcmath php7.4-gd

# ===== 2. Node.js 20 =====
log "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs
npm install -g pm2

# ===== 3. Git LFS =====
log "Installing Git LFS..."
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
apt-get install -y -qq git-lfs
git lfs install

# ===== 4. Composer =====
log "Installing Composer..."
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# ===== 5. MySQL =====
log "Setting up MySQL..."
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

# ===== 6. Clone backup =====
log "Cloning repo..."
cd /root; rm -rf backup789
git clone ${GIT_REPO} backup789; cd backup789; git lfs pull

# ===== 7. Restore DB =====
log "Restoring database..."
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
gunzip < bongda88.sql.gz | mysql -u root -p"${MYSQL_ROOT_PASS}" ${DB_NAME}

# ===== 8. Extract source =====
log "Extracting source..."
tar xzf src/taixiu-server.tgz -C /var/www/
tar xzf src/via888.tgz        -C /var/www/

# ===== 9. npm install =====
log "npm install..."
cd /var/www/taixiu-server  && npm install

# ===== 10. Laravel =====
log "Laravel setup..."
cd /var/www/via888
cp /root/backup789/.env.via888 .env
composer install --no-dev --no-interaction 2>&1 || true
php artisan optimize 2>/dev/null || true

# ===== 11. Nginx =====
log "Nginx config..."
cp /root/backup789/nginx/conf.d/* /etc/nginx/conf.d/
cp /root/backup789/nginx/nginx.conf /etc/nginx/nginx.conf
# Remove proxy to port 3002 (b52bomtan not used)
sed -i '/location \/68ClubA\//,/^    }/d' /etc/nginx/conf.d/taixiu-game.inc
sed -i '/location \/apiv1\//,/^    }/d' /etc/nginx/conf.d/taixiu-game.inc
nginx -t && systemctl restart nginx
systemctl restart php7.4-fpm

# ===== 12. PM2 (chỉ game) =====
log "Starting PM2..."
pm2 kill 2>/dev/null || true
cd /var/www/taixiu-server  && pm2 start server.js --name taixiu-server
pm2 save

# ===== 13. Crontab =====
log "Crontab..."
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/via888/artisan schedule:run >> /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * curl -s --max-time 120 'http://127.0.0.1/api/cron/settle-bets?token=bongda88cron2024' >/dev/null 2>&1") | crontab -

# ===== 14. Done =====
IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
echo ""
log "=========================================="
log "RESTORE COMPLETE - CHỈ PORT 80"
log "=========================================="
echo ""
log "Website:  http://${IP}/"
log "Game:     http://${IP}/client"
log "PM2:      pm2 list (1 process: taixiu-server)"
echo ""
