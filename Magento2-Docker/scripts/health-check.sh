#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source .env
set +a


PASS=0
FAIL=0


pass() {

    echo "PASS: $1"

    PASS=$((PASS + 1))
}


fail() {

    echo "FAIL: $1"

    FAIL=$((FAIL + 1))
}


echo
echo "=================================================="
echo " Magento Docker Health Check"
echo "=================================================="
echo


# ==========================================================
# CONTAINERS
# ==========================================================

echo "[1] Containers"

docker compose ps


# ==========================================================
# DATABASE
# ==========================================================

echo
echo "[2] MariaDB"

if docker compose exec -T db \
    mariadb-admin ping \
    -h 127.0.0.1 \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --silent \
    >/dev/null 2>&1
then

    pass "MariaDB"

else

    fail "MariaDB"

fi


# ==========================================================
# VALKEY
# ==========================================================

echo
echo "[3] Valkey"

if docker compose exec -T redis \
    valkey-cli ping 2>/dev/null |
    grep -q PONG
then

    pass "Valkey"

else

    fail "Valkey"

fi


# ==========================================================
# OPENSEARCH
# ==========================================================

echo
echo "[4] OpenSearch"

if curl -fsS \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health" \
    >/dev/null 2>&1
then

    pass "OpenSearch"

else

    fail "OpenSearch"

fi


# ==========================================================
# PHP
# ==========================================================

echo
echo "[5] PHP"

if docker compose exec -T php \
    php -v \
    >/dev/null 2>&1
then

    pass "PHP"

else

    fail "PHP"

fi


# ==========================================================
# PHP-FPM
# ==========================================================

echo
echo "[6] PHP-FPM"

if docker compose exec -T php \
    php-fpm -t \
    >/dev/null 2>&1
then

    pass "PHP-FPM"

else

    fail "PHP-FPM"

fi


# ==========================================================
# MAGENTO
# ==========================================================

echo
echo "[7] Magento"

if docker compose exec -T php \
    php bin/magento --version
then

    pass "Magento"

else

    fail "Magento"

fi


# ==========================================================
# NGINX HEALTH
# ==========================================================

echo
echo "[8] Nginx health"

if curl -fsS \
    "http://localhost:${NGINX_PORT}/health-check" \
    >/dev/null
then

    pass "Nginx"

else

    fail "Nginx"

fi


# ==========================================================
# NGINX -> PHP
# ==========================================================

echo
echo "[9] Nginx -> PHP"

NGINX_STATUS="$(
    curl \
        -s \
        -o /dev/null \
        -w "%{http_code}" \
        "http://localhost:${NGINX_PORT}/"
)"


if [[ "${NGINX_STATUS}" =~ ^[23][0-9][0-9]$ ]]
then

    pass "Nginx -> PHP HTTP ${NGINX_STATUS}"

else

    fail "Nginx -> PHP HTTP ${NGINX_STATUS}"

fi


# ==========================================================
# VARNISH HEALTH
# ==========================================================

echo
echo "[10] Varnish health"

if curl -fsS \
    "http://localhost:${VARNISH_PORT}/health-check" \
    >/dev/null
then

    pass "Varnish"

else

    fail "Varnish"

fi


# ==========================================================
# VARNISH -> NGINX
# ==========================================================

echo
echo "[11] Varnish -> Nginx"

VARNISH_STATUS="$(
    curl \
        -s \
        -o /dev/null \
        -w "%{http_code}" \
        "http://localhost:${VARNISH_PORT}/"
)"


if [[ "${VARNISH_STATUS}" =~ ^[23][0-9][0-9]$ ]]
then

    pass "Varnish -> Nginx HTTP ${VARNISH_STATUS}"

else

    fail "Varnish -> Nginx HTTP ${VARNISH_STATUS}"

fi


# ==========================================================
# VARNISH CACHE HEADER
# ==========================================================

echo
echo "[12] Varnish cache header"

CACHE_HEADER="$(
    curl \
        -s \
        -I \
        "http://localhost:${VARNISH_PORT}/" |
        tr -d '\r' |
        grep -i "^X-Magento-Cache-Debug:" ||
        true
)"


if [[ -n "${CACHE_HEADER}" ]]
then

    pass "${CACHE_HEADER}"

else

    fail "X-Magento-Cache-Debug header"

fi


# ==========================================================
# MAGENTO STORE
# ==========================================================

echo
echo "[13] Magento Store"

HTTP_CODE="$(
    curl \
        -L \
        -s \
        -o /dev/null \
        -w "%{http_code}" \
        "http://localhost:${VARNISH_PORT}/"
)"


if [[ "${HTTP_CODE}" =~ ^[23][0-9][0-9]$ ]]
then

    pass "Magento Store HTTP ${HTTP_CODE}"

else

    fail "Magento Store HTTP ${HTTP_CODE}"

fi


# ==========================================================
# RESULT
# ==========================================================

echo
echo "=================================================="
echo " Result"
echo "=================================================="
echo

echo "PASS: ${PASS}"

echo "FAIL: ${FAIL}"

echo


if [[ "${FAIL}" -gt 0 ]]
then

    echo "Health check FAILED."

    exit 1

fi


echo "All health checks PASSED."
echo
