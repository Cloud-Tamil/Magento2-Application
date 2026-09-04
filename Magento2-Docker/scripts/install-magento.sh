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

# ==========================================================
# LOGGING
# ==========================================================

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
# ERROR HANDLER
# ==========================================================

trap 'error "Installation failed at line ${LINENO}. Command: ${BASH_COMMAND}"' ERR

# ==========================================================
# ENVIRONMENT
# ==========================================================

if [[ ! -f .env ]]; then

    error ".env file not found."

    echo
    echo "Create it using:"
    echo
    echo "cp .env.example .env"
    echo

    exit 1
fi

log "Loading environment variables..."

set -a
# shellcheck disable=SC1091
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
    MAGENTO_ADMIN_FRONTNAME

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

    COMPOSER_AUTH_PUBLIC_KEY
    COMPOSER_AUTH_PRIVATE_KEY
)

for var in "${required_vars[@]}"; do

    if [[ -z "${!var:-}" ]]; then

        error "Required variable missing: ${var}"

        exit 1
    fi

done

log "Environment validation: OK"

# ==========================================================
# VALIDATE BASE URL
# ==========================================================

if [[ "${MAGENTO_BASE_URL}" != */ ]]; then
    error "MAGENTO_BASE_URL must end with /"
    error "Example: http://localhost:${VARNISH_PORT}/"
    exit 1
fi

# ==========================================================
# DOCKER CHECK
# ==========================================================

log "Checking Docker..."

if ! command -v docker >/dev/null 2>&1; then
    error "Docker command not found."
    exit 1
fi

docker --version
docker compose version

# ==========================================================
# COMPOSE VALIDATION
# ==========================================================

log "Validating Docker Compose configuration..."

docker compose config >/dev/null

log "Docker Compose configuration: OK"

# ==========================================================
# DIRECTORIES
# ==========================================================

log "Preparing project directories..."

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
    echo "Add the following to .env:"
    echo
    echo "COMPOSER_AUTH_PUBLIC_KEY=your_public_key"
    echo "COMPOSER_AUTH_PRIVATE_KEY=your_private_key"
    echo

    exit 1
fi

# ==========================================================
# BUILD PHP IMAGE
# ==========================================================

log "Building PHP image..."

docker compose build php

log "PHP image build completed."

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
    valkey-cli ping 2>/dev/null |
    grep -q "PONG"
do

    echo "Valkey is not ready..."

    sleep 3

done

log "Valkey: READY"

# ==========================================================
# WAIT FOR OPENSEARCH
# ==========================================================

log "Waiting for OpenSearch..."

until curl -fsS \
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

    log "Downloading Magento ${MAGENTO_VERSION}..."

    COMPOSER_AUTH_JSON="$(
        printf '%s' \
        '{"http-basic":{"repo.magento.com":{"username":"%s","password":"%s"}}}' \
        "${COMPOSER_AUTH_PUBLIC_KEY}" \
        "${COMPOSER_AUTH_PRIVATE_KEY}"
    )"

    log "Creating temporary Composer container..."

    docker compose run \
        --rm \
        --no-deps \
        --entrypoint composer \
        -w /var/www/html \
        -e "COMPOSER_AUTH=${COMPOSER_AUTH_JSON}" \
        php \
        create-project \
        --repository-url=https://repo.magento.com \
        "magento/project-community-edition=${MAGENTO_VERSION}" \
        /var/www/html

    log "Magento source downloaded."

else

    log "Magento source already exists."

fi

# ==========================================================
# VERIFY MAGENTO SOURCE
# ==========================================================

log "Verifying Magento source..."

if [[ ! -f src/composer.json ]]; then

    error "Magento composer.json was not created."

    exit 1
fi

if [[ ! -d src/bin ]]; then

    error "Magento bin directory was not created."

    exit 1
fi

if [[ ! -f src/bin/magento ]]; then

    error "Magento CLI was not created."

    exit 1
fi

log "Magento source verification: OK"

# ==========================================================
# START PHP
# ==========================================================

log "Starting PHP-FPM..."

docker compose up -d php

# ==========================================================
# WAIT FOR PHP-FPM
# ==========================================================

log "Waiting for PHP-FPM..."

until docker compose exec -T php \
    pgrep -x php-fpm >/dev/null 2>&1
do

    echo "PHP-FPM is not ready..."

    sleep 3

done

log "PHP-FPM: READY"

# ==========================================================
# VERIFY PHP WORKING DIRECTORY
# ==========================================================

log "Verifying Magento working directory..."

PHP_WORKDIR="$(
    docker compose exec -T php \
    pwd |
    tr -d '\r'
)"

if [[ "$PHP_WORKDIR" != "/var/www/html" ]]; then

    error "Invalid PHP working directory: ${PHP_WORKDIR}"

    exit 1
fi

log "PHP working directory: /var/www/html"

# ==========================================================
# INSTALL MAGENTO
# ==========================================================

if [[ ! -f src/app/etc/env.php ]]; then

    log "Magento is not installed."

    log "Installing Magento..."

    docker compose exec \
        -T \
        -w /var/www/html \
        php \
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

    log "Magento is already installed."

fi

# ==========================================================
# VERIFY MAGENTO INSTALLATION
# ==========================================================

log "Verifying Magento installation..."

if ! docker compose exec -T -w /var/www/html php \
    php bin/magento --version >/dev/null 2>&1
then

    error "Magento CLI verification failed."

    exit 1
fi

log "Magento CLI: READY"

# ==========================================================
# MAGENTO MODE
# ==========================================================

log "Setting Magento developer mode..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento deploy:mode:set developer

# ==========================================================
# REDIS / VALKEY APPLICATION CACHE
# ==========================================================

log "Configuring Valkey application cache..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento setup:config:set \
    --cache-backend=redis \
    --cache-backend-redis-server="${REDIS_HOST}" \
    --cache-backend-redis-port="${REDIS_PORT}" \
    --cache-backend-redis-db=0

# ==========================================================
# VARNISH CONFIGURATION
# ==========================================================

log "Configuring Varnish as Magento page cache..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento setup:config:set \
    --http-cache-hosts="${NGINX_HOST:-nginx}:80"

# ==========================================================
# SESSION STORAGE
# ==========================================================

log "Configuring Redis/Valkey sessions..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento setup:config:set \
    --session-save=redis \
    --session-save-redis-host="${REDIS_HOST}" \
    --session-save-redis-port="${REDIS_PORT}" \
    --session-save-redis-db=2

# ==========================================================
# ENABLE CACHE
# ==========================================================

log "Enabling Magento cache..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento cache:enable

# ==========================================================
# SETUP UPGRADE
# ==========================================================

log "Running setup:upgrade..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento setup:upgrade

# ==========================================================
# DI COMPILE
# ==========================================================

log "Compiling Magento..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento setup:di:compile

# ==========================================================
# STATIC CONTENT
# ==========================================================

log "Deploying static content..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento setup:static-content:deploy \
    -f \
    en_US

# ==========================================================
# INDEXERS
# ==========================================================

log "Running Magento indexers..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento indexer:reindex

# ==========================================================
# CACHE FLUSH
# ==========================================================

log "Flushing Magento cache..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    php bin/magento cache:flush

# ==========================================================
# PERMISSIONS
# ==========================================================

log "Fixing Magento permissions..."

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    chown -R \
    www-data:www-data \
    var \
    generated \
    pub/static \
    pub/media \
    app/etc

docker compose exec \
    -T \
    -w /var/www/html \
    php \
    chmod -R \
    ug+rwX \
    var \
    generated \
    pub/static \
    pub/media \
    app/etc

log "Magento permissions: OK"

# ==========================================================
# START NGINX
# ==========================================================

log "Starting Nginx..."

docker compose up -d nginx

# ==========================================================
# WAIT FOR NGINX
# ==========================================================

log "Waiting for Nginx..."

until docker compose exec -T nginx \
    curl -fsS \
    http://127.0.0.1/health-check \
    >/dev/null 2>&1
do

    echo "Nginx is not ready..."

    sleep 3

done

log "Nginx: READY"

# ==========================================================
# GENERATE MAGENTO VARNISH VCL
# ==========================================================

log "Generating Magento Varnish VCL..."

if docker compose exec -T -w /var/www/html php \
    php bin/magento help varnish:vcl:generate \
    >/dev/null 2>&1
then

    docker compose exec -T \
        -w /var/www/html \
        php \
        php bin/magento varnish:vcl:generate \
        > docker/varnish/generated.vcl

    cp \
        docker/varnish/generated.vcl \
        docker/varnish/default.vcl

    log "Magento Varnish VCL generated."

else

    warn "Magento Varnish VCL command is not available."
    warn "Keeping existing docker/varnish/default.vcl."
fi

# ==========================================================
# START VARNISH
# ==========================================================

log "Starting Varnish..."

docker compose up -d varnish

# ==========================================================
# WAIT FOR VARNISH
# ==========================================================

log "Waiting for Varnish..."

until curl -fsS \
    "http://localhost:${VARNISH_PORT}/" \
    >/dev/null 2>&1
do

    echo "Varnish is not ready..."

    sleep 3

done

log "Varnish: READY"

# ==========================================================
# FINAL HEALTH CHECK
# ==========================================================

log "Running final Magento health check..."

HTTP_STATUS="$(
    curl \
        -k \
        -L \
        -s \
        -o /dev/null \
        -w "%{http_code}" \
        "${MAGENTO_BASE_URL}"
)"

if [[ ! "$HTTP_STATUS" =~ ^[23][0-9][0-9]$ ]]; then

    error "Magento returned HTTP status: ${HTTP_STATUS}"

    docker compose ps

    exit 1
fi

log "Magento HTTP status: ${HTTP_STATUS}"

# ==========================================================
# FINAL STATUS
# ==========================================================

echo

echo "=========================================================="
echo "        Magento Installation Completed Successfully"
echo "=========================================================="

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

echo "Varnish:"
echo "  http://localhost:${VARNISH_PORT}"

echo

echo "OpenSearch:"
echo "  http://localhost:${OPENSEARCH_HTTP_PORT}"

echo

echo "=========================================================="
echo "                    Installation OK"
echo "=========================================================="
