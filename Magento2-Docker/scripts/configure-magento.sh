#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo
echo "=================================================="
echo " Magento Configuration"
echo "=================================================="
echo

# ==========================================================
# VERIFY PHP
# ==========================================================

if ! docker compose exec -T php php -v >/dev/null 2>&1; then
    echo "ERROR: PHP container is not available."
    exit 1
fi

# ==========================================================
# SET DEVELOPER MODE
# ==========================================================

echo "[1] Developer mode"

docker compose exec -T php \
    php bin/magento deploy:mode:set developer

echo

# ==========================================================
# MAGENTO UPGRADE
# ==========================================================

echo "[2] Magento upgrade"

docker compose exec -T php \
    php bin/magento setup:upgrade

echo

# ==========================================================
# COMPILE
# ==========================================================

echo "[3] Dependency compilation"

docker compose exec -T php \
    php bin/magento setup:di:compile

echo

# ==========================================================
# STATIC CONTENT
# ==========================================================

echo "[4] Static content"

docker compose exec -T php \
    php bin/magento setup:static-content:deploy \
    -f \
    en_US

echo

# ==========================================================
# INDEX
# ==========================================================

echo "[5] Reindex"

docker compose exec -T php \
    php bin/magento indexer:reindex

echo

# ==========================================================
# CACHE
# ==========================================================

echo "[6] Cache flush"

docker compose exec -T php \
    php bin/magento cache:flush

echo

# ==========================================================
# PERMISSIONS
# ==========================================================

echo "[7] Permissions"

docker compose exec -T php \
    chown -R www-data:www-data \
    var \
    generated \
    pub/static \
    pub/media \
    app/etc

docker compose exec -T php \
    chmod -R ug+rwX \
    var \
    generated \
    pub/static \
    pub/media \
    app/etc

echo

# ==========================================================
# RESTART WEB
# ==========================================================

echo "Restarting web services..."

docker compose restart nginx varnish

echo
echo "=================================================="
echo " Magento configuration completed."
echo "=================================================="
echo
