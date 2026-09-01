#!/bin/bash

set -Eeuo pipefail

echo "=============================================="
echo " Magento Docker Container"
echo "=============================================="

cd /var/www/html


# ============================================================
# CONFIGURATION
# ============================================================

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


# ============================================================
# ERROR HANDLER
# ============================================================

error_handler() {

    local exit_code=$?

    echo ""
    echo "=============================================="
    echo " ERROR"
    echo "=============================================="
    echo "entrypoint.sh failed."
    echo "Exit code : ${exit_code}"
    echo "Line      : ${BASH_LINENO[0]}"
    echo "Command   : ${BASH_COMMAND}"
    echo "=============================================="

    exit "${exit_code}"
}

trap error_handler ERR


# ============================================================
# BASIC VALIDATION
# ============================================================

echo ""
echo "Checking Magento environment..."

if [ -z "${MYSQL_PASSWORD}" ]; then
    echo "ERROR: MYSQL_PASSWORD is not configured."
    exit 1
fi

if [ -z "${MYSQL_ROOT_PASSWORD:-}" ]; then
    echo "ERROR: MYSQL_ROOT_PASSWORD is not configured."
    exit 1
fi

if [ -z "${MAGENTO_ADMIN_PASSWORD:-}" ]; then
    echo "ERROR: MAGENTO_ADMIN_PASSWORD is not configured."
    exit 1
fi

if [ -z "${MAGENTO_ADMIN_EMAIL:-}" ]; then
    echo "ERROR: MAGENTO_ADMIN_EMAIL is not configured."
    exit 1
fi

if [ -z "${COMPOSER_AUTH:-}" ]; then

    echo ""
    echo "ERROR: COMPOSER_AUTH is not configured."
    echo ""
    echo "Adobe Commerce Composer authentication is required."
    echo ""

    exit 1

fi


echo ""
echo "Magento version : ${MAGENTO_VERSION}"
echo "Magento URL     : ${MAGENTO_BASE_URL}"
echo "Database        : ${MYSQL_HOST}:${MYSQL_PORT}"
echo "Valkey          : ${VALKEY_HOST}:${VALKEY_PORT}"
echo "OpenSearch      : ${OPENSEARCH_HOST}:${OPENSEARCH_PORT}"


# ============================================================
# INSTALL MAGENTO SOURCE
# ============================================================

if [ ! -f "/var/www/html/bin/magento" ]; then

    echo ""
    echo "=============================================="
    echo " Magento source not found"
    echo " Installing Magento ${MAGENTO_VERSION}"
    echo "=============================================="

    rm -rf /tmp/magento-install

    mkdir -p /tmp/magento-install

    cd /tmp/magento-install

    composer create-project \
        --no-interaction \
        --prefer-dist \
        --repository-url=https://repo.magento.com/ \
        "magento/project-community-edition=${MAGENTO_VERSION}" \
        .

    echo ""
    echo "Magento source downloaded."

    cp -a /tmp/magento-install/. /var/www/html/

    cd /var/www/html

else

    echo ""
    echo "Magento source already exists."

fi


# ============================================================
# VERIFY MAGENTO
# ============================================================

if [ ! -f "/var/www/html/bin/magento" ]; then

    echo "ERROR: Magento CLI was not found."

    exit 1

fi

echo ""
echo "Magento CLI found."

php bin/magento --version || true


# ============================================================
# CREATE DIRECTORIES
# ============================================================

echo ""
echo "Creating Magento directories..."

mkdir -p \
    /var/www/html/var \
    /var/www/html/generated \
    /var/www/html/pub/static \
    /var/www/html/pub/media \
    /var/www/html/app/etc


# ============================================================
# PERMISSIONS
# ============================================================

echo ""
echo "Setting permissions..."

chown -R www-data:www-data /var/www/html

chmod -R 775 \
    /var/www/html/var \
    /var/www/html/generated \
    /var/www/html/pub/static \
    /var/www/html/pub/media \
    /var/www/html/app/etc

chmod +x /var/www/html/bin/magento


# ============================================================
# WAIT FOR MARIADB
# ============================================================

echo ""
echo "=============================================="
echo " Waiting for MariaDB"
echo "=============================================="

DB_READY=0

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

        DB_READY=1
        break

    fi

    echo "MariaDB not ready... ${i}/${MAX_RETRIES}"

    sleep 3

done


if [ "${DB_READY}" -ne 1 ]; then

    echo ""
    echo "ERROR: MariaDB did not become ready."

    exit 1

fi

echo "MariaDB is ready."


# ============================================================
# WAIT FOR OPENSEARCH
# ============================================================

echo ""
echo "=============================================="
echo " Waiting for OpenSearch"
echo "=============================================="

OPENSEARCH_READY=0

for i in $(seq 1 "${MAX_RETRIES}"); do

    if curl \
        --silent \
        --show-error \
        --fail \
        --max-time 5 \
        "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/_cluster/health" \
        >/dev/null 2>&1
    then

        OPENSEARCH_READY=1
        break

    fi

    echo "OpenSearch not ready... ${i}/${MAX_RETRIES}"

    sleep 5

done


if [ "${OPENSEARCH_READY}" -ne 1 ]; then

    echo ""
    echo "ERROR: OpenSearch did not become ready."

    exit 1

fi

echo "OpenSearch is ready."


# ============================================================
# WAIT FOR VALKEY
# ============================================================

echo ""
echo "=============================================="
echo " Waiting for Valkey"
echo "=============================================="

VALKEY_READY=0

for i in $(seq 1 "${MAX_RETRIES}"); do

    if php -r '
        $host = getenv("VALKEY_HOST") ?: "valkey";
        $port = (int)(getenv("VALKEY_PORT") ?: 6379);

        try {

            $redis = new Redis();

            if (!$redis->connect($host, $port, 5)) {
                exit(1);
            }

            $response = $redis->ping();

            if (
                $response === true ||
                $response === 1 ||
                $response === "1" ||
                $response === "+PONG" ||
                $response === "PONG"
            ) {
                exit(0);
            }

            exit(1);

        } catch (Throwable $e) {

            exit(1);

        }
    '
    then

        VALKEY_READY=1
        break

    fi

    echo "Valkey not ready... ${i}/${MAX_RETRIES}"

    sleep 3

done


if [ "${VALKEY_READY}" -ne 1 ]; then

    echo ""
    echo "ERROR: Valkey did not become ready."

    exit 1

fi

echo "Valkey is ready."


# ============================================================
# VERIFY PHP REDIS EXTENSION
# ============================================================

echo ""
echo "Checking PHP Redis extension..."

if ! php -m | grep -qi "^redis$"; then

    echo "ERROR: PHP Redis extension is not installed."

    exit 1

fi

echo "PHP Redis extension is available."


# ============================================================
# VALKEY READ/WRITE TEST
# ============================================================

echo ""
echo "Testing Valkey read/write..."

php -r '

$redis = new Redis();

$redis->connect(
    getenv("VALKEY_HOST") ?: "valkey",
    (int)(getenv("VALKEY_PORT") ?: 6379),
    5
);

if (!$redis->set("magento_docker_test", "ok", 30)) {
    fwrite(STDERR, "Valkey SET failed.\n");
    exit(1);
}

if ($redis->get("magento_docker_test") !== "ok") {
    fwrite(STDERR, "Valkey GET failed.\n");
    exit(1);
}

echo "Valkey read/write test successful.\n";

'


# ============================================================
# MAGENTO INSTALLATION
# ============================================================

if [ ! -f "/var/www/html/app/etc/env.php" ]; then

    echo ""
    echo "=============================================="
    echo " Installing Magento"
    echo "=============================================="

    su -s /bin/bash www-data -c "
        cd /var/www/html

        php bin/magento setup:install \
            --base-url='${MAGENTO_BASE_URL}' \
            --db-host='${MYSQL_HOST}' \
            --db-name='${MYSQL_DATABASE}' \
            --db-user='${MYSQL_USER}' \
            --db-password='${MYSQL_PASSWORD}' \
            --admin-firstname='${MAGENTO_ADMIN_FIRSTNAME}' \
            --admin-lastname='${MAGENTO_ADMIN_LASTNAME}' \
            --admin-email='${MAGENTO_ADMIN_EMAIL}' \
            --admin-user='${MAGENTO_ADMIN_USER}' \
            --admin-password='${MAGENTO_ADMIN_PASSWORD}' \
            --language='${MAGENTO_LANGUAGE:-en_US}' \
            --currency='${MAGENTO_CURRENCY:-USD}' \
            --timezone='${MAGENTO_TIMEZONE:-Asia/Kolkata}' \
            --use-rewrites=1 \
            --search-engine='opensearch' \
            --opensearch-host='${OPENSEARCH_HOST}' \
            --opensearch-port='${OPENSEARCH_PORT}' \
            --opensearch-index-prefix='magento2' \
            --opensearch-timeout=15 \
            --backend-frontname='${MAGENTO_ADMIN_URI}'
    "

    echo ""
    echo "Magento database installation completed."

else

    echo ""
    echo "Magento is already installed."

fi


# ============================================================
# VERIFY ENV.PHP
# ============================================================

if [ ! -f "/var/www/html/app/etc/env.php" ]; then

    echo ""
    echo "ERROR: Magento installation failed."
    echo "env.php was not created."

    exit 1

fi

echo ""
echo "Magento env.php exists."


# ============================================================
# CONFIGURE VALKEY
# ============================================================

echo ""
echo "=============================================="
echo " Configuring Valkey"
echo "=============================================="


su -s /bin/bash www-data -c "
    cd /var/www/html

    php bin/magento setup:config:set \
        --session-save=redis \
        --session-save-redis-host='${VALKEY_HOST}' \
        --session-save-redis-port='${VALKEY_PORT}' \
        --session-save-redis-db=2 \
        --cache-backend=redis \
        --cache-backend-redis-server='${VALKEY_HOST}' \
        --cache-backend-redis-port='${VALKEY_PORT}' \
        --cache-backend-redis-db=0 \
        --page-cache=redis \
        --page-cache-redis-server='${VALKEY_HOST}' \
        --page-cache-redis-port='${VALKEY_PORT}' \
        --page-cache-redis-db=1
"


echo ""
echo "Valkey configuration completed."


# ============================================================
# MAGENTO CLI
# ============================================================

echo ""
echo "Testing Magento CLI..."

su -s /bin/bash www-data -c "
    cd /var/www/html
    php bin/magento --version
"


# ============================================================
# DEVELOPER MODE
# ============================================================

echo ""
echo "Setting developer mode..."

su -s /bin/bash www-data -c "
    cd /var/www/html
    php bin/magento deploy:mode:set developer --skip-compilation
"


# ============================================================
# SETUP UPGRADE
# ============================================================

echo ""
echo "Running setup:upgrade..."

su -s /bin/bash www-data -c "
    cd /var/www/html
    php bin/magento setup:upgrade
"


# ============================================================
# DI COMPILE
# ============================================================

echo ""
echo "Running dependency injection compilation..."

su -s /bin/bash www-data -c "
    cd /var/www/html
    php bin/magento setup:di:compile
"


# ============================================================
# STATIC CONTENT
# ============================================================

echo ""
echo "Deploying static content..."

su -s /bin/bash www-data -c "
    cd /var/www/html
    php bin/magento setup:static-content:deploy -f
"


# ============================================================
# INDEXERS
# ============================================================

echo ""
echo "Running indexers..."

su -s /bin/bash www-data -c "
    cd /var/www/html
    php bin/magento indexer:reindex
"


# ============================================================
# CACHE
# ============================================================

echo ""
echo "Flushing cache..."

su -s /bin/bash www-data -c "
    cd /var/www/html
    php bin/magento cache:flush
"


# ============================================================
# FINAL PERMISSIONS
# ============================================================

echo ""
echo "Applying final permissions..."

chown -R www-data:www-data /var/www/html

chmod -R 775 \
    /var/www/html/var \
    /var/www/html/generated \
    /var/www/html/pub/static \
    /var/www/html/pub/media \
    /var/www/html/app/etc

chmod +x /var/www/html/bin/magento


# ============================================================
# PHP-FPM VALIDATION
# ============================================================

echo ""
echo "Testing PHP-FPM configuration..."

php-fpm -t


# ============================================================
# FINAL STATUS
# ============================================================

echo ""
echo "=============================================="
echo " Magento is READY"
echo "=============================================="

echo ""
echo "Storefront:"
echo "${MAGENTO_BASE_URL}"

echo ""
echo "Admin:"
echo "${MAGENTO_BASE_URL}${MAGENTO_ADMIN_URI}"

echo ""
echo "PHP-FPM:"
echo "9000"

echo ""
echo "MariaDB:"
echo "${MYSQL_HOST}:${MYSQL_PORT}"

echo ""
echo "Valkey:"
echo "${VALKEY_HOST}:${VALKEY_PORT}"

echo ""
echo "OpenSearch:"
echo "${OPENSEARCH_HOST}:${OPENSEARCH_PORT}"

echo ""
echo "=============================================="


# ============================================================
# START PHP-FPM
# ============================================================

exec "$@"
