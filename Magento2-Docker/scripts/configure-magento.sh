#!/usr/bin/env bash

set -Eeuo pipefail


cd "$(dirname "${BASH_SOURCE[0]}")/.."


set -a

source .env

set +a


# ============================================================
# DEVELOPER MODE
# ============================================================

docker compose exec -T php \
    php bin/magento deploy:mode:set developer


# ============================================================
# BASE URL
# ============================================================

docker compose exec -T php \
    php bin/magento setup:store-config:set \
    --base-url="${MAGENTO_BASE_URL}"


docker compose exec -T php \
    php bin/magento config:set \
    web/unsecure/base_url \
    "${MAGENTO_BASE_URL}"


docker compose exec -T php \
    php bin/magento config:set \
    web/secure/base_url \
    "${MAGENTO_BASE_URL}"


docker compose exec -T php \
    php bin/magento config:set \
    web/secure/use_in_frontend \
    0


docker compose exec -T php \
    php bin/magento config:set \
    web/secure/use_in_adminhtml \
    0


# ============================================================
# OPENSEARCH
# ============================================================

docker compose exec -T php \
    php bin/magento config:set \
    catalog/search/engine \
    opensearch


docker compose exec -T php \
    php bin/magento config:set \
    catalog/search/opensearch_server_hostname \
    "${OPENSEARCH_HOST}"


docker compose exec -T php \
    php bin/magento config:set \
    catalog/search/opensearch_server_port \
    "${OPENSEARCH_PORT}"


docker compose exec -T php \
    php bin/magento config:set \
    catalog/search/opensearch_index_prefix \
    magento


docker compose exec -T php \
    php bin/magento config:set \
    catalog/search/opensearch_enable_auth \
    0


docker compose exec -T php \
    php bin/magento config:set \
    catalog/search/opensearch_server_timeout \
    15


# ============================================================
# REDIS / VALKEY CACHE
# ============================================================

docker compose exec -T php \
    php bin/magento setup:config:set \
    --cache-backend=redis \
    --cache-backend-redis-server="${REDIS_HOST}" \
    --cache-backend-redis-db="${REDIS_CACHE_DB}" \
    --cache-backend-redis-port="${REDIS_PORT}" \
    --page-cache=redis \
    --page-cache-redis-server="${REDIS_HOST}" \
    --page-cache-redis-db="${REDIS_CACHE_DB}" \
    --page-cache-redis-port="${REDIS_PORT}" \
    --session-save=redis \
    --session-save-redis-host="${REDIS_HOST}" \
    --session-save-redis-port="${REDIS_PORT}" \
    --session-save-redis-db="${REDIS_SESSION_DB}"


# ============================================================
# FULL PAGE CACHE
# ============================================================

docker compose exec -T php \
    php bin/magento config:set \
    system/full_page_cache/caching_application \
    2


docker compose exec -T php \
    php bin/magento config:set \
    system/full_page_cache/ttl \
    86400


# ============================================================
# MAGENTO UPGRADE
# ============================================================

docker compose exec -T php \
    php bin/magento setup:upgrade


# ============================================================
# DEPENDENCY INJECTION
# ============================================================

docker compose exec -T php \
    php bin/magento setup:di:compile


# ============================================================
# STATIC CONTENT
# ============================================================

docker compose exec -T php \
    php bin/magento setup:static-content:deploy \
    -f en_US


# ============================================================
# INDEXERS
# ============================================================

docker compose exec -T php \
    php bin/magento indexer:reindex


# ============================================================
# CACHE
# ============================================================

docker compose exec -T php \
    php bin/magento cache:flush


# ============================================================
# PERMISSIONS
# ============================================================

docker compose exec -T php \
    chown -R www-data:www-data \
    var \
    generated \
    pub/static \
    pub/media \
    app/etc


# ============================================================
# RESTART WEB LAYER
# ============================================================

docker compose restart nginx varnish


echo

echo "Magento configuration completed successfully."
