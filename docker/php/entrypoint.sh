#!/bin/bash

set -e

echo "=============================================="
echo " Magento Docker Container"
echo "=============================================="

cd /var/www/html


# ============================================================
# CHECK COMPOSER AUTH
# ============================================================

if [ -z "${COMPOSER_AUTH}" ]; then

    echo ""
    echo "ERROR: COMPOSER_AUTH is not configured."
    echo ""
    echo "Set your Adobe Commerce authentication keys:"
    echo ""
    echo 'export COMPOSER_AUTH='\''{"http-basic":{"repo.magento.com":{"username":"PUBLIC_KEY","password":"PRIVATE_KEY"}}}'\'''
    echo ""

    exit 1

fi


# ============================================================
# INSTALL MAGENTO SOURCE
# ============================================================

if [ ! -f "/var/www/html/bin/magento" ]; then

    echo "Magento source not found."

    echo "Installing Magento ${MAGENTO_VERSION}..."

    rm -rf /tmp/magento-install

    mkdir -p /tmp/magento-install

    cd /tmp/magento-install

    composer create-project \
        --repository-url=https://repo.magento.com/ \
        magento/project-community-edition="${MAGENTO_VERSION}" \
        .

    echo "Magento downloaded successfully."

    cp -a . /var/www/html/

    cd /var/www/html

fi


# ============================================================
# FILE PERMISSIONS
# ============================================================

mkdir -p \
    var \
    generated \
    pub/static \
    pub/media \
    app/etc

chown -R www-data:www-data /var/www/html

find var generated pub/static pub/media app/etc \
    -type d \
    -exec chmod 775 {} \; || true

find var generated pub/static pub/media app/etc \
    -type f \
    -exec chmod 664 {} \; || true

chmod +x bin/magento


# ============================================================
# WAIT FOR DATABASE
# ============================================================

echo "Waiting for MariaDB..."

until mysql \
    -h"${MYSQL_HOST:-db}" \
    -u"${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    -e "SELECT 1" >/dev/null 2>&1
do

    sleep 3

done

echo "MariaDB is ready."


# ============================================================
# WAIT FOR OPENSEARCH
# ============================================================

echo "Waiting for OpenSearch..."

until curl -fs \
    http://opensearch:9200/_cluster/health >/dev/null 2>&1
do

    sleep 5

done

echo "OpenSearch is ready."


# ============================================================
# WAIT FOR VALKEY
# ============================================================

echo "Waiting for Valkey..."

until php -r \
    '$r=new Redis(); $r->connect("valkey",6379); exit($r->ping()==="+PONG" ? 0 : 1);'
do

    sleep 3

done

echo "Valkey is ready."


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
            --base-url=\"${MAGENTO_BASE_URL}\" \
            --db-host=\"${MYSQL_HOST:-db}\" \
            --db-name=\"${MYSQL_DATABASE}\" \
            --db-user=\"${MYSQL_USER}\" \
            --db-password=\"${MYSQL_PASSWORD}\" \
            --admin-firstname=\"${MAGENTO_ADMIN_FIRSTNAME}\" \
            --admin-lastname=\"${MAGENTO_ADMIN_LASTNAME}\" \
            --admin-email=\"${MAGENTO_ADMIN_EMAIL}\" \
            --admin-user=\"${MAGENTO_ADMIN_USER}\" \
            --admin-password=\"${MAGENTO_ADMIN_PASSWORD}\" \
            --language=\"${MAGENTO_LANGUAGE}\" \
            --currency=\"${MAGENTO_CURRENCY}\" \
            --timezone=\"${MAGENTO_TIMEZONE}\" \
            --use-rewrites=1 \
            --search-engine=opensearch \
            --opensearch-host=\"opensearch\" \
            --opensearch-port=9200 \
            --opensearch-index-prefix=magento2 \
            --opensearch-timeout=15 \
            --session-save=redis \
            --redis-host=\"valkey\" \
            --redis-port=6379 \
            --cache-backend=redis \
            --cache-backend-redis-server=\"valkey\" \
            --cache-backend-redis-db=0 \
            --page-cache=redis \
            --page-cache-redis-server=\"valkey\" \
            --page-cache-redis-db=1 \
            --backend-frontname=\"${MAGENTO_ADMIN_URI}\"
    "

else

    echo "Magento is already installed."

fi


# ============================================================
# DEPLOY STATIC CONTENT
# ============================================================

if [ -f "/var/www/html/bin/magento" ]; then

    echo "Running Magento maintenance commands..."

    su -s /bin/bash www-data -c "
        cd /var/www/html

        php bin/magento deploy:mode:set developer --skip-compilation || true

        php bin/magento setup:upgrade --keep-generated || true

        php bin/magento cache:flush || true
    "

fi


echo ""
echo "=============================================="
echo " Magento is ready"
echo "=============================================="
echo ""
echo "Storefront:"
echo "${MAGENTO_BASE_URL}"
echo ""
echo "Admin:"
echo "${MAGENTO_BASE_URL}${MAGENTO_ADMIN_URI}"
echo ""

exec "$@"
