#!/bin/bash

set -Eeuo pipefail


# ==========================================================
# LOGGING
# ==========================================================

echo "=================================================="
echo " Magento PHP Container"
echo "=================================================="


# ==========================================================
# VARIABLES
# ==========================================================

APP_DIR="/var/www/html"

MYSQL_HOST="${MYSQL_HOST:-db}"
MYSQL_PORT="${MYSQL_PORT:-3306}"

MYSQL_DATABASE="${MYSQL_DATABASE:-magento}"
MYSQL_USER="${MYSQL_USER:-magento}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

VALKEY_HOST="${VALKEY_HOST:-valkey}"
VALKEY_PORT="${VALKEY_PORT:-6379}"

OPENSEARCH_HOST="${OPENSEARCH_HOST:-opensearch}"
OPENSEARCH_PORT="${OPENSEARCH_PORT:-9200}"

MAGENTO_VERSION="${MAGENTO_VERSION:-2.4.8-p5}"

MAGENTO_BASE_URL="${MAGENTO_BASE_URL:-http://localhost:8080/}"

MAGENTO_ADMIN_URI="${MAGENTO_ADMIN_URI:-admin}"

MAX_RETRIES="${MAX_RETRIES:-60}"


cd "${APP_DIR}"


# ==========================================================
# VALIDATION
# ==========================================================

if [[ -z "${MYSQL_PASSWORD}" ]]; then
    echo "ERROR: MYSQL_PASSWORD is missing."
    exit 1
fi

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    echo "ERROR: MYSQL_ROOT_PASSWORD is missing."
    exit 1
fi

if [[ -z "${COMPOSER_AUTH:-}" ]]; then
    echo "ERROR: COMPOSER_AUTH is missing."
    echo "Adobe Commerce repository credentials are required."
    exit 1
fi

echo ""
echo "Magento version : ${MAGENTO_VERSION}"
echo "Application     : ${APP_DIR}"
echo "Base URL        : ${MAGENTO_BASE_URL}"
echo "Database        : ${MYSQL_HOST}:${MYSQL_PORT}"
echo "Valkey          : ${VALKEY_HOST}:${VALKEY_PORT}"
echo "OpenSearch      : ${OPENSEARCH_HOST}:${OPENSEARCH_PORT}"


# ==========================================================
# CREATE SRC DIRECTORY
# ==========================================================

mkdir -p "${APP_DIR}"

chown -R www-data:www-data "${APP_DIR}"


# ==========================================================
# WAIT FOR DATABASE
# ==========================================================

echo ""
echo "Waiting for MariaDB..."

DB_READY=false

for i in $(seq 1 "${MAX_RETRIES}"); do

    if mysql \
        --protocol=tcp \
        -h"${MYSQL_HOST}" \
        -P"${MYSQL_PORT}" \
        -u"${MYSQL_USER}" \
        -p"${MYSQL_PASSWORD}" \
        -e "SELECT 1;" \
        >/dev/null 2>&1
    then
        DB_READY=true
        break
    fi

    echo "MariaDB not ready: ${i}/${MAX_RETRIES}"

    sleep 3

done


if [[ "${DB_READY}" != "true" ]]; then
    echo "ERROR: MariaDB did not become ready."
    exit 1
fi

echo "MariaDB is ready."


# ==========================================================
# WAIT FOR VALKEY
# ==========================================================

echo ""
echo "Waiting for Valkey..."

VALKEY_READY=false

for i in $(seq 1 "${MAX_RETRIES}"); do

    if php -r '
        $r = new Redis();

        try {
            if (!$r->connect(
                getenv("VALKEY_HOST"),
                (int)getenv("VALKEY_PORT"),
                5
            )) {
                exit(1);
            }

            $response = $r->ping();

            if (
                $response === true ||
                $response === "PONG" ||
                $response === "+PONG"
            ) {
                exit(0);
            }

        } catch (Throwable $e) {
        }

        exit(1);
    '
    then
        VALKEY_READY=true
        break
    fi

    echo "Valkey not ready: ${i}/${MAX_RETRIES}"

    sleep 3

done


if [[ "${VALKEY_READY}" != "true" ]]; then
    echo "ERROR: Valkey did not become ready."
    exit 1
fi

echo "Valkey is ready."


# ==========================================================
# WAIT FOR OPENSEARCH
# ==========================================================

echo ""
echo "Waiting for OpenSearch..."

OPENSEARCH_READY=false

for i in $(seq 1 "${MAX_RETRIES}"); do

    if curl \
        --silent \
        --show-error \
        --fail \
        --max-time 5 \
        "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/_cluster/health" \
        >/dev/null 2>&1
    then
        OPENSEARCH_READY=true
        break
    fi

    echo "OpenSearch not ready: ${i}/${MAX_RETRIES}"

    sleep 5

done


if [[ "${OPENSEARCH_READY}" != "true" ]]; then
    echo "ERROR: OpenSearch did not become ready."
    exit 1
fi

echo "OpenSearch is ready."


# ==========================================================
# INSTALL MAGENTO SOURCE
# ==========================================================

if [[ ! -f "${APP_DIR}/composer.json" ]]; then

    echo ""
    echo "=================================================="
    echo " Installing Magento ${MAGENTO_VERSION}"
    echo "=================================================="

    rm -rf /tmp/magento-install

    mkdir -p /tmp/magento-install

    chown -R www-data:www-data /tmp/magento-install

    gosu www-data bash -c "
        export COMPOSER_AUTH='${COMPOSER_AUTH}'

        composer create-project \
            --no-interaction \
            --prefer-dist \
            --repository-url=https://repo.magento.com/ \
            magento/project-community-edition=${MAGENTO_VERSION} \
            /tmp/magento-install
    "

    echo ""
    echo "Copying Magento source into ./src..."

    cp -a /tmp/magento-install/. "${APP_DIR}/"

    chown -R www-data:www-data "${APP_DIR}"

else

    echo ""
    echo "Magento source already exists in ./src."

fi


# ==========================================================
# VERIFY MAGENTO
# ==========================================================

if [[ ! -f "${APP_DIR}/bin/magento" ]]; then

    echo "ERROR: Magento CLI not found."

    exit 1

fi


echo ""
echo "Magento CLI:"
gosu www-data php "${APP_DIR}/bin/magento" --version


# ==========================================================
# DIRECTORIES
# ==========================================================

mkdir -p \
    "${APP_DIR}/var" \
    "${APP_DIR}/generated" \
    "${APP_DIR}/pub/static" \
    "${APP_DIR}/pub/media" \
    "${APP_DIR}/app/etc"


# ==========================================================
# PERMISSIONS
# ==========================================================

chown -R www-data:www-data "${APP_DIR}"

chmod -R 775 \
    "${APP_DIR}/var" \
    "${APP_DIR}/generated" \
    "${APP_DIR}/pub/static" \
    "${APP_DIR}/pub/media" \
    "${APP_DIR}/app/etc"


# ==========================================================
# MAGENTO INSTALLATION
# ==========================================================

if [[ ! -f "${APP_DIR}/app/etc/env.php" ]]; then

    echo ""
    echo "=================================================="
    echo " Running Magento setup:install"
    echo "=================================================="

    gosu www-data php "${APP_DIR}/bin/magento" setup:install \
        --base-url="${MAGENTO_BASE_URL}" \
        --db-host="${MYSQL_HOST}" \
        --db-name="${MYSQL_DATABASE}" \
        --db-user="${MYSQL_USER}" \
        --db-password="${MYSQL_PASSWORD}" \
        --admin-firstname="${MAGENTO_ADMIN_FIRSTNAME}" \
        --admin-lastname="${MAGENTO_ADMIN_LASTNAME}" \
        --admin-email="${MAGENTO_ADMIN_EMAIL}" \
        --admin-user="${MAGENTO_ADMIN_USER}" \
        --admin-password="${MAGENTO_ADMIN_PASSWORD}" \
        --language="${MAGENTO_LANGUAGE:-en_US}" \
        --currency="${MAGENTO_CURRENCY:-USD}" \
        --timezone="${MAGENTO_TIMEZONE:-Asia/Kolkata}" \
        --use-rewrites=1 \
        --search-engine=opensearch \
        --opensearch-host="${OPENSEARCH_HOST}" \
        --opensearch-port="${OPENSEARCH_PORT}" \
        --opensearch-index-prefix="magento2" \
        --opensearch-timeout=15 \
        --backend-frontname="${MAGENTO_ADMIN_URI}"

else

    echo ""
    echo "Magento is already installed."

fi


# ==========================================================
# VALKEY CONFIGURATION
# ==========================================================

echo ""
echo "Configuring Valkey..."

gosu www-data php "${APP_DIR}/bin/magento" setup:config:set \
    --session-save=redis \
    --session-save-redis-host="${VALKEY_HOST}" \
    --session-save-redis-port="${VALKEY_PORT}" \
    --session-save-redis-db=2 \
    --cache-backend=redis \
    --cache-backend-redis-server="${VALKEY_HOST}" \
    --cache-backend-redis-port="${VALKEY_PORT}" \
    --cache-backend-redis-db=0 \
    --page-cache=redis \
    --page-cache-redis-server="${VALKEY_HOST}" \
    --page-cache-redis-port="${VALKEY_PORT}" \
    --page-cache-redis-db=1


# ==========================================================
# DEVELOPER MODE
# ==========================================================

CURRENT_MODE="$(
    gosu www-data php "${APP_DIR}/bin/magento" deploy:mode:show \
    2>/dev/null || true
)"

if [[ "${CURRENT_MODE}" != *"developer"* ]]; then

    echo ""
    echo "Setting developer mode..."

    gosu www-data php \
        "${APP_DIR}/bin/magento" \
        deploy:mode:set developer \
        --skip-compilation

fi


# ==========================================================
# UPGRADE
# ==========================================================

echo ""
echo "Running setup:upgrade..."

gosu www-data php \
    "${APP_DIR}/bin/magento" \
    setup:upgrade


# ==========================================================
# COMPILE
# ==========================================================

echo ""
echo "Running DI compilation..."

gosu www-data php \
    "${APP_DIR}/bin/magento" \
    setup:di:compile


# ==========================================================
# STATIC CONTENT
# ==========================================================

echo ""
echo "Deploying static content..."

gosu www-data php \
    "${APP_DIR}/bin/magento" \
    setup:static-content:deploy \
    -f


# ==========================================================
# INDEX
# ==========================================================

echo ""
echo "Reindexing..."

gosu www-data php \
    "${APP_DIR}/bin/magento" \
    indexer:reindex


# ==========================================================
# CACHE
# ==========================================================

echo ""
echo "Flushing cache..."

gosu www-data php \
    "${APP_DIR}/bin/magento" \
    cache:flush


# ==========================================================
# FINAL PERMISSIONS
# ==========================================================

chown -R www-data:www-data "${APP_DIR}"

chmod -R 775 \
    "${APP_DIR}/var" \
    "${APP_DIR}/generated" \
    "${APP_DIR}/pub/static" \
    "${APP_DIR}/pub/media" \
    "${APP_DIR}/app/etc"


# ==========================================================
# PHP-FPM CHECK
# ==========================================================

echo ""
echo "Validating PHP-FPM..."

php-fpm -t


# ==========================================================
# READY
# ==========================================================

echo ""
echo "=================================================="
echo " Magento is READY"
echo "=================================================="

echo ""
echo "Storefront:"
echo "${MAGENTO_BASE_URL}"

echo ""
echo "Admin:"
echo "${MAGENTO_BASE_URL}${MAGENTO_ADMIN_URI}"

echo ""
echo "Magento source:"
echo "./src"

echo ""
echo "=================================================="


# ==========================================================
# START PHP-FPM
# ==========================================================

exec "$@"
