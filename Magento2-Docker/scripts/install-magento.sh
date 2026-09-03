#!/usr/bin/env bash

set -Eeuo pipefail


# ============================================================
# PROJECT ROOT
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"


# ============================================================
# ENVIRONMENT
# ============================================================

if [[ ! -f .env ]]; then

    echo "ERROR: .env file not found."

    echo "Run: cp .env.example .env"

    exit 1

fi


set -a

source .env

set +a


# ============================================================
# REQUIRED VARIABLES
# ============================================================

required=(

    MAGENTO_VERSION

    MAGENTO_BASE_URL

    MAGENTO_ADMIN_FIRSTNAME

    MAGENTO_ADMIN_LASTNAME

    MAGENTO_ADMIN_EMAIL

    MAGENTO_ADMIN_USER

    MAGENTO_ADMIN_PASSWORD

    MAGENTO_ADMIN_FRONTNAME

    MYSQL_DATABASE

    MYSQL_USER

    MYSQL_PASSWORD

    MYSQL_ROOT_PASSWORD

    DB_HOST

    REDIS_HOST

    REDIS_PORT

    OPENSEARCH_HOST

    OPENSEARCH_PORT

    MAGENTO_LANGUAGE

    MAGENTO_CURRENCY

    MAGENTO_TIMEZONE

    COMPOSER_AUTH_PUBLIC_KEY

    COMPOSER_AUTH_PRIVATE_KEY

)


for v in "${required[@]}"; do

    if [[ -z "${!v:-}" ]]; then

        echo "ERROR: missing $v"

        exit 1

    fi

done


# ============================================================
# COMPOSER CREDENTIAL CHECK
# ============================================================

if [[ \
    "$COMPOSER_AUTH_PUBLIC_KEY" == "YOUR_MAGENTO_PUBLIC_KEY" \
    || \
    "$COMPOSER_AUTH_PRIVATE_KEY" == "YOUR_MAGENTO_PRIVATE_KEY"
]]; then

    echo "ERROR: Configure Magento Marketplace keys in .env"

    exit 1

fi


# ============================================================
# VALIDATE COMPOSE
# ============================================================

docker compose config >/dev/null


mkdir -p src


# ============================================================
# STEP 1
# ============================================================

echo

echo "============================================================"

echo "STEP 1: BUILD PHP"

echo "============================================================"


docker compose build php


# ============================================================
# STEP 2
# ============================================================

echo

echo "============================================================"

echo "STEP 2: START DATABASE SERVICES"

echo "============================================================"


docker compose up -d db redis opensearch


# ============================================================
# STEP 3
# ============================================================

echo

echo "============================================================"

echo "STEP 3: WAIT FOR DATABASE SERVICES"

echo "============================================================"


until docker compose exec -T db \
    mariadb-admin ping \
    -h 127.0.0.1 \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --silent >/dev/null 2>&1
do

    echo "Waiting for MariaDB..."

    sleep 3

done


until docker compose exec -T redis \
    valkey-cli ping 2>/dev/null | grep -q PONG
do

    echo "Waiting for Valkey..."

    sleep 2

done


until curl -fs \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health" \
    >/dev/null 2>&1
do

    echo "Waiting for OpenSearch..."

    sleep 5

done


# ============================================================
# STEP 4
# ============================================================

echo

echo "============================================================"

echo "STEP 4: DOWNLOAD MAGENTO"

echo "============================================================"


if [[ ! -f src/composer.json ]]; then


    AUTH_JSON="$(
        printf \
        '{"http-basic":{"repo.magento.com":{"username":"%s","password":"%s"}}}' \
        "$COMPOSER_AUTH_PUBLIC_KEY" \
        "$COMPOSER_AUTH_PRIVATE_KEY"
    )"


    docker volume create magento-composer-tmp >/dev/null


    docker compose run \
        --rm \
        -e "COMPOSER_AUTH=${AUTH_JSON}" \
        -v magento-composer-tmp:/tmp/magento \
        php \
        composer create-project \
        --repository-url=https://repo.magento.com \
        "magento/project-community-edition=${MAGENTO_VERSION}" \
        /tmp/magento


    docker run \
        --rm \
        -v magento-composer-tmp:/tmp/magento:ro \
        -v "$(pwd)/src:/var/www/html" \
        alpine:3.20 \
        sh -c \
        'cp -a /tmp/magento/. /var/www/html/'


    docker volume rm magento-composer-tmp >/dev/null 2>&1 || true

fi


# ============================================================
# STEP 5
# ============================================================

echo

echo "============================================================"

echo "STEP 5: START COMPLETE STACK"

echo "============================================================"


docker compose up -d


# ============================================================
# STEP 6
# ============================================================

echo

echo "============================================================"

echo "STEP 6: INSTALL MAGENTO"

echo "============================================================"


if [[ ! -f src/app/etc/env.php ]]; then


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
        --opensearch-index-prefix=magento \
        --opensearch-timeout=15

fi


# ============================================================
# STEP 7
# ============================================================

echo

echo "============================================================"

echo "STEP 7: CONFIGURE MAGENTO"

echo "============================================================"


./scripts/configure-magento.sh


# ============================================================
# STEP 8
# ============================================================

echo

echo "============================================================"

echo "STEP 8: FINAL HEALTH CHECK"

echo "============================================================"


./scripts/health-check.sh
