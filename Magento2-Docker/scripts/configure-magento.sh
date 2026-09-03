#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo
echo "=================================================="
echo " Magento Configuration"
echo "=================================================="
echo

docker compose exec -T php \
    php bin/magento setup:upgrade

docker compose exec -T php \
    php bin/magento setup:di:compile

docker compose exec -T php \
    php bin/magento setup:static-content:deploy -f en_US

docker compose exec -T php \
    php bin/magento indexer:reindex

docker compose exec -T php \
    php bin/magento cache:flush

docker compose exec -T php \
    chown -R www-data:www-data \
    var generated pub/static pub/media app/etc

docker compose restart nginx varnish

echo
echo "Magento configuration completed."
echo
