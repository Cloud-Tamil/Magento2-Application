#!/usr/bin/env bash

set -Eeuo pipefail

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
BLUE='\033[0;34m'
NC='\033[0m'


info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}


trap '
error "Failed at line ${LINENO}"
error "Command: ${BASH_COMMAND}"
' ERR


# ==========================================================
# ENV
# ==========================================================

if [[ ! -f .env ]]; then

    error ".env file not found."

    echo
    echo "Run:"
    echo "cp .env.example .env"

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


for variable in "${required_vars[@]}"; do

    if [[ -z "${!variable:-}" ]]; then

        error "Missing variable: ${variable}"

        exit 1
    fi

done


# ==========================================================
# DOCKER
# ==========================================================

command -v docker >/dev/null 2>&1 ||
    {
        error "Docker is not installed."
        exit 1
    }


docker compose version


# ==========================================================
# COMPOSE VALIDATION
# ==========================================================

info "Validating Docker Compose..."

docker compose config >/dev/null

info "Docker Compose configuration: OK"


# ==========================================================
# DIRECTORIES
# ==========================================================

mkdir -p src

mkdir -p docker/php

mkdir -p docker/nginx

mkdir -p docker/varnish


# ==========================================================
# BUILD PHP
# ==========================================================

info "Building PHP image..."

docker compose build php


# ==========================================================
# START INFRASTRUCTURE
# ==========================================================

info "Starting database/cache/search..."

docker compose up -d db redis opensearch


# ==========================================================
# WAIT DATABASE
# ==========================================================

info "Waiting for MariaDB..."

until docker compose exec -T db \
    mariadb-admin ping \
    -h 127.0.0.1 \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --silent \
    >/dev/null 2>&1
do

    echo "MariaDB not ready..."

    sleep 5

done

info "MariaDB: READY"


# ==========================================================
# WAIT VALKEY
# ==========================================================

info "Waiting for Valkey..."

until docker compose exec -T redis \
    valkey-cli ping 2>/dev/null |
    grep -q PONG
do

    echo "Valkey not ready..."

    sleep 3

done

info "Valkey: READY"


# ==========================================================
# WAIT OPENSEARCH
# ==========================================================

info "Waiting for OpenSearch..."

until curl -fsS \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health" \
    >/dev/null 2>&1
do

    echo "OpenSearch not ready..."

    sleep 5

done

info "OpenSearch: READY"


# ==========================================================
# COMPOSER AUTH
# ==========================================================

COMPOSER_AUTH_JSON="$(
    printf '%s' \
    "$(jq -n \
        --arg username "${COMPOSER_AUTH_PUBLIC_KEY}" \
        --arg password "${COMPOSER_AUTH_PRIVATE_KEY}" \
        '{
            "http-basic": {
                "repo.magento.com": {
                    "username": $username,
                    "password": $password
                }
            }
        }'
    )"
)"


# ==========================================================
# MAGENTO SOURCE
# ==========================================================

if [[ ! -f src/composer.json ]]; then

    info "Magento source not found."

    info "Downloading Magento ${MAGENTO_VERSION}..."

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
        .


else

    info "Magento source already exists."

fi


# ==========================================================
# START PHP
# ==========================================================

info "Starting PHP..."

docker compose up -d php


# ==========================================================
# WAIT PHP
# ==========================================================

info "Waiting for PHP-FPM..."

until docker compose exec -T php \
    php-fpm -t >/dev/null 2>&1
do

    echo "PHP-FPM not ready..."

    sleep 3

done

info "PHP-FPM: READY"


# ==========================================================
# MAGENTO CLI
# ==========================================================

docker compose exec -T php \
    php bin/magento --version


# ==========================================================
# INSTALL
# ==========================================================

if [[ ! -f src/app/etc/env.php ]]; then

    info "Installing Magento..."

    docker compose exec \
        -T \
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

else

    info "Magento is already installed."

fi


# ==========================================================
# CONFIGURE MAGENTO
# ==========================================================

bash scripts/configure-magento.sh


# ==========================================================
# START NGINX
# ==========================================================

info "Starting Nginx..."

docker compose up -d nginx


# ==========================================================
# WAIT NGINX
# ==========================================================

info "Waiting for Nginx..."

until curl -fsS \
    "http://localhost:${NGINX_PORT}/health-check" \
    >/dev/null 2>&1
do

    echo "Nginx not ready..."

    sleep 3

done

info "Nginx: READY"


# ==========================================================
# START VARNISH
# ==========================================================

info "Starting Varnish..."

docker compose up -d varnish


# ==========================================================
# WAIT VARNISH
# ==========================================================

info "Waiting for Varnish..."

until curl -fsS \
    "http://localhost:${VARNISH_PORT}/health-check" \
    >/dev/null 2>&1
do

    echo "Varnish not ready..."

    sleep 3

done

info "Varnish: READY"


# ==========================================================
# FINAL CHECK
# ==========================================================

bash scripts/health-check.sh


echo
echo "=========================================================="
echo " Magento Installation Completed"
echo "=========================================================="
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
