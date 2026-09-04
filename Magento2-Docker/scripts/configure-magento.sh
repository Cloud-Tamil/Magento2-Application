#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source .env
set +a


echo
echo "=================================================="
echo " Magento Configuration"
echo "=================================================="
echo


# ==========================================================
# DEVELOPER MODE
# ==========================================================

echo "[1] Developer mode"

docker compose exec -T php \
    php bin/magento deploy:mode:set developer


# ==========================================================
# VALKEY CACHE
# ==========================================================

echo "[2] Configuring Valkey cache"

docker compose exec -T php \
    php bin/magento setup:config:set \
    --cache-backend=redis \
    --cache-backend-redis-server="${REDIS_HOST}" \
    --cache-backend-redis-port="${REDIS_PORT}" \
    --cache-backend-redis-db=0


# ==========================================================
# SESSION
# ==========================================================

echo "[3] Configuring sessions"

docker compose exec -T php \
    php bin/magento setup:config:set \
    --session-save=redis \
    --session-save-redis-host="${REDIS_HOST}" \
    --session-save-redis-port="${REDIS_PORT}" \
    --session-save-redis-db=2


# ==========================================================
# HTTP CACHE
# ==========================================================

echo "[4] Configuring HTTP cache"

docker compose exec -T php \
    php bin/magento setup:config:set \
    --http-cache-hosts="varnish:80"


# ==========================================================
# CACHE ENABLE
# ==========================================================

echo "[5] Enabling cache"

docker compose exec -T php \
    php bin/magento cache:enable


# ==========================================================
# UPGRADE
# ==========================================================

echo "[6] Setup upgrade"

docker compose exec -T php \
    php bin/magento setup:upgrade


# ==========================================================
# COMPILE
# ==========================================================

echo "[7] DI compile"

docker compose exec -T php \
    php bin/magento setup:di:compile


# ==========================================================
# STATIC
# ==========================================================

echo "[8] Static content"

docker compose exec -T php \
    php bin/magento setup:static-content:deploy \
    -f \
    en_US


# ==========================================================
# INDEX
# ==========================================================

echo "[9] Reindex"

docker compose exec -T php \
    php bin/magento indexer:reindex


# ==========================================================
# CACHE
# ==========================================================

echo "[10] Cache flush"

docker compose exec -T php \
    php bin/magento cache:flush


# ==========================================================
# PERMISSIONS
# ==========================================================

echo "[11] Permissions"

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
echo "Magento configuration completed."
echo
