#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo
echo "=================================================="
echo " Magento 2.4.8-p5 Docker Installation"
echo "=================================================="
echo


# ==========================================================
# LOAD ENVIRONMENT
# ==========================================================

if [[ ! -f .env ]]; then

    echo "ERROR: .env file not found."

    echo
    echo "Run:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    echo

    exit 1

fi

set -a
source .env
set +a


# ==========================================================
# VALIDATE REQUIRED VARIABLES
# ==========================================================

required_vars=(

    MAGENTO_VERSION
    MAGENTO_BASE_URL

    MAGENTO_ADMIN_FIRSTNAME
    MAGENTO_ADMIN_LASTNAME
    MAGENTO_ADMIN_EMAIL
    MAGENTO_ADMIN_USER
    MAGENTO_ADMIN_PASSWORD

    MYSQL_DATABASE
    MYSQL_USER
    MYSQL_PASSWORD
    MYSQL_ROOT_PASSWORD

    DB_HOST

    REDIS_HOST
    REDIS_PORT

    OPENSEARCH_HOST
    OPENSEARCH_PORT

)

for var in "${required_vars[@]}"; do

    if [[ -z "${!var:-}" ]]; then

        echo "ERROR: Missing required variable: $var"

        exit 1

    fi

done


# ==========================================================
# DOCKER CHECK
# ==========================================================

echo "[1/14] Checking Docker..."

docker --version

docker compose version


# ==========================================================
# DIRECTORY SETUP
# ==========================================================

echo
echo "[2/14] Preparing directories..."

mkdir -p src

mkdir -p docker/php

mkdir -p docker/nginx

mkdir -p docker/varnish

mkdir -p scripts


# ==========================================================
# COMPOSER AUTH CHECK
# ==========================================================

echo
echo "[3/14] Checking Magento Composer credentials..."

if [[ -z "${COMPOSER_AUTH_PUBLIC_KEY:-}" ]] ||
   [[ -z "${COMPOSER_AUTH_PRIVATE_KEY:-}" ]]; then

    echo
    echo "ERROR: Magento Composer credentials are missing."
    echo
    echo "Set these in .env:"
    echo
    echo "COMPOSER_AUTH_PUBLIC_KEY=YOUR_PUBLIC_KEY"
    echo "COMPOSER_AUTH_PRIVATE_KEY=YOUR_PRIVATE_KEY"
    echo

    exit 1

fi


# ==========================================================
# VALIDATE COMPOSE
# ==========================================================

echo
echo "[4/14] Validating Docker Compose configuration..."

docker compose config >/dev/null

echo "Docker Compose configuration: OK"


# ==========================================================
# BUILD PHP
# ==========================================================

echo
echo "[5/14] Building PHP image..."

docker compose build --no-cache php


# ==========================================================
# START INFRASTRUCTURE
# ==========================================================

echo
echo "[6/14] Starting database, Valkey and OpenSearch..."

docker compose up -d db redis opensearch


# ==========================================================
# WAIT FOR DATABASE
# ==========================================================

echo
echo "[7/14] Waiting for MariaDB..."

until docker compose exec -T db \
    mariadb-admin ping \
    -h 127.0.0.1 \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --silent >/dev/null 2>&1
do

    echo "MariaDB not ready..."

    sleep 5

done

echo "MariaDB: READY"


# ==========================================================
# WAIT FOR VALKEY
# ==========================================================

echo
echo "[8/14] Waiting for Valkey..."

until docker compose exec -T redis \
    valkey-cli ping 2>/dev/null | grep -q PONG
do

    echo "Valkey not ready..."

    sleep 3

done

echo "Valkey: READY"


# ==========================================================
# WAIT FOR OPENSEARCH
# ==========================================================

echo
echo "[9/14] Waiting for OpenSearch..."

until curl -fs \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health" \
    >/dev/null 2>&1
do

    echo "OpenSearch not ready..."

    sleep 5

done

echo "OpenSearch: READY"

# ==========================================================
# INSTALL MAGENTO SOURCE
# ==========================================================

echo
echo "[10/14] Checking Magento source..."

if [[ ! -f src/composer.json ]]; then

    echo "Magento source not found."
    echo "Preparing Magento source directory..."

    mkdir -p src

    # Remove existing contents from the host source directory.
    # This is safe because Magento source was not detected above.
    find src -mindepth 1 -maxdepth 1 -exec rm -rf {} +

    COMPOSER_AUTH_JSON="$(
        printf '{"http-basic":{"repo.magento.com":{"username":"%s","password":"%s"}}}' \
        "$COMPOSER_AUTH_PUBLIC_KEY" \
        "$COMPOSER_AUTH_PRIVATE_KEY"
    )"

    echo "Downloading Magento ${MAGENTO_VERSION}..."

    # Create Magento in a temporary Docker volume.
    # This avoids Composer's "directory is not empty" error.
    docker volume rm magento-composer-tmp >/dev/null 2>&1 || true

    docker volume create magento-composer-tmp >/dev/null

    docker compose run \
        --rm \
        -e "COMPOSER_AUTH=${COMPOSER_AUTH_JSON}" \
        -v magento-composer-tmp:/tmp/magento \
        php \
        composer create-project \
        --repository-url=https://repo.magento.com \
        "magento/project-community-edition=${MAGENTO_VERSION}" \
        /tmp/magento

    echo "Copying Magento source to ./src..."

    docker run \
        --rm \
        -v magento-composer-tmp:/tmp/magento:ro \
        -v "$(pwd)/src:/var/www/html" \
        alpine:3.20 \
        sh -c 'cp -a /tmp/magento/. /var/www/html/'

    docker volume rm magento-composer-tmp >/dev/null 2>&1 || true

    echo
    echo "Magento source downloaded successfully."

else

    echo "Magento source already exists."

fi

# ==========================================================
# START COMPLETE STACK
# ==========================================================

echo
echo "[11/14] Starting complete Magento stack..."

docker compose up -d


# ==========================================================
# WAIT FOR APPLICATION
# ==========================================================

echo
echo "[12/14] Waiting for application..."

sleep 15


# ==========================================================
# MAGENTO INSTALL
# ==========================================================

echo
echo "[13/14] Installing Magento..."

if [[ ! -f src/app/etc/env.php ]]; then

    docker compose exec -T php \
        php bin/magento setup:install \
        --base-url="${MAGENTO_BASE_URL}" \
        --db-host="${DB_HOST}" \
        --db-name="${MYSQL_DATABASE}" \
        --db-user="${MYSQL_USER}" \
        --db-password="${MYSQL_PASSWORD}" \
        --backend-frontname="admin" \
        --admin-firstname="${MAGENTO_ADMIN_FIRSTNAME}" \
        --admin-lastname="${MAGENTO_ADMIN_LASTNAME}" \
        --admin-email="${MAGENTO_ADMIN_EMAIL}" \
        --admin-user="${MAGENTO_ADMIN_USER}" \
        --admin-password="${MAGENTO_ADMIN_PASSWORD}" \
        --language="${MAGENTO_LANGUAGE}" \
        --currency="${MAGENTO_CURRENCY}" \
        --timezone="${MAGENTO_TIMEZONE}" \
        --use-rewrites=1 \
        --search-engine=opensearch \
        --opensearch-host="${OPENSEARCH_HOST}" \
        --opensearch-port="${OPENSEARCH_PORT}" \
        --opensearch-index-prefix="magento" \
        --opensearch-timeout=15

    echo
    echo "Magento installation: COMPLETE"

else

    echo
    echo "Magento is already installed."

fi


# ==========================================================
# FINAL CONFIGURATION
# ==========================================================

echo
echo "[14/14] Finalizing Magento..."

docker compose exec -T php \
    php bin/magento deploy:mode:set developer

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


# ==========================================================
# RESTART NGINX/VARNISH
# ==========================================================

docker compose restart nginx varnish


# ==========================================================
# STATUS
# ==========================================================

echo
echo "=================================================="
echo " Magento Installation Completed"
echo "=================================================="
echo

docker compose ps

echo
echo "Store:"
echo "  ${MAGENTO_BASE_URL}"

echo
echo "Admin:"
echo "  ${MAGENTO_BASE_URL}admin"

echo
echo "Nginx:"
echo "  http://localhost:${NGINX_PORT}"

echo
echo "Varnish:"
echo "  http://localhost:${VARNISH_PORT}"

echo
echo "OpenSearch:"
echo "  http://localhost:${OPENSEARCH_HTTP_PORT}"

echo
