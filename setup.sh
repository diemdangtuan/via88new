#!/bin/bash
# ============================================================
# setup.sh - Restore full VPS from GitHub backup (via88new)
# Chạy: bash setup.sh
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

# --- Config ---
GIT_REPO="git@github.com:diemdangtuan/via88new.git"
DB_USER="bongda"
DB_PASS="Khoakhoa@1"
DB_NAME="bongda88"
MYSQL_ROOT_PASS="Khoakhoa@1"

# --- 1. Install dependencies ---
log "Installing system packages..."
apt-get update -qq
apt-get install -y -qq curl wget git nginx python3 python3-pip mariadb-server mariadb-client

log "Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs

log "Installing PM2..."
npm install -g pm2

log "Installing Git LFS..."
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
apt-get install -y -qq git-lfs
git lfs install

# --- 2. MySQL setup ---
log "Setting up MySQL..."
service mariadb start
sleep 2

mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF

mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# --- 3. Clone backup ---
log "Cloning backup repo..."
cd /root
rm -rf backup789
git clone ${GIT_REPO} backup789
cd backup789
git lfs pull

# --- 4. Restore DB ---
log "Restoring database..."
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
gunzip < bongda88.sql.gz | mysql -u root -p"${MYSQL_ROOT_PASS}" ${DB_NAME}
log "Database restored."

# --- 5. Extract source code ---
log "Extracting source code..."
mkdir -p /var/www /root/apisunwin

tar xzf src/taixiu-server.tgz   -C /var/www/
tar xzf src/789club.tgz         -C /var/www/
tar xzf src/via888.tgz          -C /var/www/
tar xzf src/apisunwin.tgz       -C /root/   # extracts to /root/apisunwin/
tar xzf src/redx-server.tgz     -C /root/
tar xzf src/traffic-tool.tgz    -C /root/

# --- 6. npm install ---
log "Installing npm dependencies..."
cd /var/www/taixiu-server        && npm install
cd /var/www/789club              && npm install
cd /root/apisunwin               && npm install
cd /root/apisunwin/b52bomtan-main && npm install
cd /root/apisunwin/taixiuapi789-main && npm install
cd /root/redx-server             && npm install
cd /root/traffic-tool            && npm install

# --- 7. Python deps for betvip-api ---
log "Installing Python deps..."
pip3 install -r /root/apisunwin/betvip-api/requirements.txt 2>/dev/null || true

# --- 8. Nginx config ---
log "Restoring nginx config..."
cp -r nginx/conf.d/* /etc/nginx/conf.d/
cp nginx/nginx.conf /etc/nginx/nginx.conf
nginx -t && systemctl restart nginx

# --- 9. Restore .env ---
log "Restoring .env..."
cp .env.via888 /var/www/via888/.env 2>/dev/null || true

# --- 10. Start all PM2 processes ---
log "Starting PM2 processes..."
pm2 kill 2>/dev/null || true

cd /var/www/taixiu-server        && pm2 start server.js --name taixiu-server
cd /root                         && pm2 start apisunwin/b52bomtan-main/index.js --name b52bomtan
cd /root                         && pm2 start apisunwin/taixiuapi789-main/server.js --name taixiu789 -- -p 10000
cd /root/apisunwin               && pm2 start server.js --name apisunwin
cd /root/apisunwin/betvip-api    && pm2 start main.py --name betvip-api --interpreter python3 -- --port 5001
cd /root/redx-server             && pm2 start index.js --name redx-server
cd /root/traffic-tool            && pm2 start index.js --name traffic
cd /var/www/via888/crawl         && pm2 start workers/index.js --name crawl

pm2 save

# --- 11. Done ---
IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
echo ""
log "=========================================="
log "RESTORE COMPLETE!"
log "=========================================="
echo ""
log "Game:          http://${IP}/client"
log "PM2:           pm2 list"
log "MySQL:         mysql -u ${DB_USER} -p${DB_PASS} ${DB_NAME}"
log "Backup dir:    /root/backup789"
echo ""
