#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."


echo
echo "=================================================="
echo " Magento Configuration"
echo "=================================================="
echo


echo "[1] Magento upgrade"

docker compose exec -T php \
    php bin/magento setup:upgrade


echo
echo "[2] Dependency compilation"

docker compose exec -T php \
    php bin/magento setup:di:compile


echo
echo "[3] Static content"

docker compose exec -T php \
    php bin/magento setup:static-content:deploy -f en_US


echo
echo "[4] Reindex"

docker compose exec -T php \
    php bin/magento indexer:reindex


echo
echo "[5] Cache"

docker compose exec -T php \
    php bin/magento cache:flush


echo
echo "[6] Permissions"

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
echo "Restarting web services..."

docker compose restart nginx varnish


echo
echo "Magento configuration completed."
echo
