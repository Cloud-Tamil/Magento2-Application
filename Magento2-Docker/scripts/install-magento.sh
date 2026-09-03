#!/usr/bin/env bash

set -Eeuo pipefail


# ==========================================================
# PROJECT ROOT
# ==========================================================

ROOT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
    pwd
)"

cd "$ROOT_DIR"


# ==========================================================
# COLORS
# ==========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


log() {

    echo -e "${GREEN}[INFO]${NC} $1"
}


warn() {

    echo -e "${YELLOW}[WARN]${NC} $1"
}


error() {

    echo -e "${RED}[ERROR]${NC} $1"
}


# ==========================================================
# ENV
# ==========================================================

if [[ ! -f .env ]]; then

    error ".env file not found."

    echo
    echo "Run:"
    echo
    echo "cp .env.example .env"
    echo

    exit 1
fi


set -a

source .env

set +a


# ==========================================================
# REQUIRED VARIABLES
# ==========================================================

required_vars=(

    MAGENTO_VERSION
    MAGENTO_BASE_URL

    MAGENTO_ADMIN_FIRSTNAME
    MAGENTO_ADMIN_LASTNAME
    MAGENTO_ADMIN_EMAIL
    MAGENTO_ADMIN_USER
    MAGENTO_ADMIN_PASSWORD

    MAGENTO_LANGUAGE
    MAGENTO_CURRENCY
    MAGENTO_TIMEZONE

    MYSQL_DATABASE
    MYSQL_USER
    MYSQL_PASSWORD
    MYSQL_ROOT_PASSWORD

    DB_HOST
    DB_PORT

    REDIS_HOST
    REDIS_PORT

    OPENSEARCH_HOST
    OPENSEARCH_PORT

    NGINX_PORT
    VARNISH_PORT
    OPENSEARCH_HTTP_PORT
)


for var in "${required_vars[@]}"; do

    if [[ -z "${!var:-}" ]]; then

        error "Required variable missing: $var"

        exit 1
    fi

done


# ==========================================================
# DOCKER CHECK
# ==========================================================

log "Checking Docker..."

docker --version

docker compose version


# ==========================================================
# COMPOSE VALIDATION
# ==========================================================

log "Validating Docker Compose..."

docker compose config >/dev/null

log "Docker Compose configuration: OK"


# ==========================================================
# DIRECTORIES
# ==========================================================

log "Preparing directories..."

mkdir -p src

mkdir -p docker/php

mkdir -p docker/nginx

mkdir -p docker/varnish

mkdir -p scripts


# ==========================================================
# COMPOSER CREDENTIALS
# ==========================================================

if [[ -z "${COMPOSER_AUTH_PUBLIC_KEY:-}" ]] ||
   [[ -z "${COMPOSER_AUTH_PRIVATE_KEY:-}" ]]; then

    error "Magento Composer credentials are missing."

    echo
    echo "Add:"
    echo
    echo "COMPOSER_AUTH_PUBLIC_KEY=..."
    echo "COMPOSER_AUTH_PRIVATE_KEY=..."
    echo

    exit 1
fi


# ==========================================================
# BUILD PHP
# ==========================================================

log "Building PHP image..."

docker compose build php


# ==========================================================
# START INFRASTRUCTURE
# ==========================================================

log "Starting MariaDB, Valkey and OpenSearch..."

docker compose up -d db redis opensearch


# ==========================================================
# WAIT FOR DATABASE
# ==========================================================

log "Waiting for MariaDB..."

until docker compose exec -T db \
    mariadb-admin ping \
    -h 127.0.0.1 \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --silent \
    >/dev/null 2>&1
do

    echo "MariaDB is not ready..."

    sleep 5
done

log "MariaDB: READY"


# ==========================================================
# WAIT FOR VALKEY
# ==========================================================

log "Waiting for Valkey..."

until docker compose exec -T redis \
    valkey-cli ping \
    2>/dev/null |
    grep -q PONG
do

    echo "Valkey is not ready..."

    sleep 3
done

log "Valkey: READY"


# ==========================================================
# WAIT FOR OPENSEARCH
# ==========================================================

log "Waiting for OpenSearch..."

until curl -fs \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health" \
    >/dev/null 2>&1
do

    echo "OpenSearch is not ready..."

    sleep 5
done

log "OpenSearch: READY"


# ==========================================================
# MAGENTO SOURCE
# ==========================================================

if [[ ! -f src/composer.json ]]; then

    log "Magento source not found."

    COMPOSER_AUTH_JSON="$(
        printf \
        '{"http-basic":{"repo.magento.com":{"username":"%s","password":"%s"}}}' \
        "$COMPOSER_AUTH_PUBLIC_KEY" \
        "$COMPOSER_AUTH_PRIVATE_KEY"
    )"


    log "Creating temporary Composer volume..."

    docker volume rm magento-composer-tmp \
        >/dev/null 2>&1 || true

    docker volume create magento-composer-tmp \
        >/dev/null


    log "Downloading Magento ${MAGENTO_VERSION}..."

    docker compose run \
        --rm \
        -e "COMPOSER_AUTH=${COMPOSER_AUTH_JSON}" \
        -v magento-composer-tmp:/tmp/magento \
        php \
        composer create-project \
        --repository-url=https://repo.magento.com \
        "magento/project-community-edition=${MAGENTO_VERSION}" \
        /tmp/magento


    log "Copying Magento source..."

    docker run \
        --rm \
        -v magento-composer-tmp:/tmp/magento:ro \
        -v "$(pwd)/src:/var/www/html" \
        alpine:3.20 \
        sh -c \
        'cp -a /tmp/magento/. /var/www/html/'


    docker volume rm magento-composer-tmp \
        >/dev/null 2>&1 || true


    log "Magento source downloaded."

else

    log "Magento source already exists."
fi


# ==========================================================
# START PHP
# ==========================================================

log "Starting PHP..."

docker compose up -d php


# ==========================================================
# INSTALL MAGENTO
# ==========================================================

if [[ ! -f src/app/etc/env.php ]]; then

    log "Magento is not installed."

    log "Installing Magento..."

    docker compose exec -T php \
        php bin/magento setup:install \
        --base-url="${MAGENTO_BASE_URL}" \
        --db-host="${DB_HOST}" \
        --db-name="${MYSQL_DATABASE}" \
        --db-user="${MYSQL_USER}" \
        --db-password="${MYSQL_PASSWORD}" \
        --backend-frontname="${MAGENTO_ADMIN_FRONTNAME}" \
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

    log "Magento installation completed."

else

    log "Magento already installed."
fi


# ==========================================================
# MAGENTO CONFIGURATION
# ==========================================================

log "Configuring Magento..."


docker compose exec -T php \
    php bin/magento deploy:mode:set developer


# ==========================================================
# VALKEY CACHE
# ==========================================================

docker compose exec -T php \
    php bin/magento setup:config:set \
    --cache-backend=redis \
    --cache-backend-redis-server="${REDIS_HOST}" \
    --cache-backend-redis-port="${REDIS_PORT}" \
    --cache-backend-redis-db=0 \
    --page-cache=redis \
    --page-cache-redis-server="${REDIS_HOST}" \
    --page-cache-redis-port="${REDIS_PORT}" \
    --page-cache-redis-db=1


# ==========================================================
# SESSION STORAGE
# ==========================================================

docker compose exec -T php \
    php bin/magento setup:config:set \
    --session-save=redis \
    --session-save-redis-host="${REDIS_HOST}" \
    --session-save-redis-port="${REDIS_PORT}" \
    --session-save-redis-db=2


# ==========================================================
# UPGRADE
# ==========================================================

docker compose exec -T php \
    php bin/magento setup:upgrade


# ==========================================================
# COMPILE
# ==========================================================

docker compose exec -T php \
    php bin/magento setup:di:compile


# ==========================================================
# STATIC CONTENT
# ==========================================================

docker compose exec -T php \
    php bin/magento setup:static-content:deploy -f en_US


# ==========================================================
# INDEX
# ==========================================================

docker compose exec -T php \
    php bin/magento indexer:reindex


# ==========================================================
# CACHE
# ==========================================================

docker compose exec -T php \
    php bin/magento cache:flush


# ==========================================================
# PERMISSIONS
# ==========================================================

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


# ==========================================================
# START WEB STACK
# ==========================================================

log "Starting Nginx and Varnish..."

docker compose up -d nginx varnish


# ==========================================================
# WAIT
# ==========================================================

sleep 10


# ==========================================================
# FINAL STATUS
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
echo "  ${MAGENTO_BASE_URL}${MAGENTO_ADMIN_FRONTNAME}"

echo
echo "Direct Nginx:"
echo "  http://localhost:${NGINX_PORT}"

echo
echo "OpenSearch:"
echo "  http://localhost:${OPENSEARCH_HTTP_PORT}"

echo
echo "=================================================="
