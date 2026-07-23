#!/bin/bash
# ============================================================
# thay-apikey.sh - Update API keys in Laravel .env
# Chạy: bash thay-apikey.sh
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

ENV_FILE="/var/www/via888/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}[ERR]${NC} Khong tim thay $ENV_FILE"
    exit 1
fi

echo ""
echo "========== API KEYS HIEN TAI =========="
grep -E "APP_API_TOKEN|THE_STATS_API_KEY|FOOTBALL_API_KEY|APP_API=" "$ENV_FILE"
echo ""

echo "Chon key can thay:"
echo "1) APP_API_TOKEN     - BetsAPI token"
echo "2) THE_STATS_API_KEY - Stats API key"
echo "3) FOOTBALL_API_KEY  - Football API key"
echo "4) Tat ca"
echo "0) Thoat"
echo ""
read -p "Nhap so (0-4): " choice

update_key() {
    local key=$1
    local name=$2
    local current=$(grep "^${key}=" "$ENV_FILE" | cut -d= -f2-)
    echo ""
    echo "Key hien tai: ${key}=${current}"
    read -p "Nhap ${name} moi (Enter de bo qua): " new_val
    if [ -n "$new_val" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i "" "s|^${key}=.*|${key}=${new_val}|" "$ENV_FILE"
        else
            sed -i "s|^${key}=.*|${key}=${new_val}|" "$ENV_FILE"
        fi
        log "Da cap nhat ${key}"
    fi
}

case $choice in
    1) update_key "APP_API_TOKEN" "BetsAPI token" ;;
    2) update_key "THE_STATS_API_KEY" "Stats API key" ;;
    3) update_key "FOOTBALL_API_KEY" "Football API key" ;;
    4)
        update_key "APP_API_TOKEN" "BetsAPI token"
        update_key "THE_STATS_API_KEY" "Stats API key"
        update_key "FOOTBALL_API_KEY" "Football API key"
        ;;
    0) echo "Thoat."; exit 0 ;;
    *) echo "Lua chon khong hop le."; exit 1 ;;
esac

echo ""
log "Da cap nhat xong. Keys hien tai:"
grep -E "APP_API_TOKEN|THE_STATS_API_KEY|FOOTBALL_API_KEY" "$ENV_FILE"

echo ""
log "Restart Laravel cache..."
cd /var/www/via888
php artisan optimize 2>/dev/null || true
echo ""
log "Xong! Key moi da co hieu luc."
