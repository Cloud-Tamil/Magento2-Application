#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."


set -a
source .env
set +a


PASS=0
FAIL=0


check_pass() {

    echo "PASS: $1"

    PASS=$((PASS + 1))
}


check_fail() {

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

    check_pass "MariaDB"

else

    check_fail "MariaDB"

fi


# ==========================================================
# VALKEY
# ==========================================================

echo
echo "[3] Valkey"

if docker compose exec -T redis \
    valkey-cli ping |
    grep -q PONG
then

    check_pass "Valkey"

else

    check_fail "Valkey"

fi


# ==========================================================
# OPENSEARCH
# ==========================================================

echo
echo "[4] OpenSearch"

if curl -fs \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health" \
    >/dev/null
then

    check_pass "OpenSearch"

else

    check_fail "OpenSearch"

fi


# ==========================================================
# PHP
# ==========================================================

echo
echo "[5] PHP"

if docker compose exec -T php \
    php -v \
    >/dev/null
then

    check_pass "PHP"

else

    check_fail "PHP"

fi


# ==========================================================
# MAGENTO
# ==========================================================

echo
echo "[6] Magento"

if docker compose exec -T php \
    php bin/magento --version
then

    check_pass "Magento"

else

    check_fail "Magento"

fi


# ==========================================================
# NGINX
# ==========================================================

echo
echo "[7] Nginx"

if curl -fs \
    "http://localhost:${NGINX_PORT}/health-check" \
    >/dev/null
then

    check_pass "Nginx"

else

    check_fail "Nginx"

fi


# ==========================================================
# VARNISH
# ==========================================================

echo
echo "[8] Varnish"

if curl -fs \
    "http://localhost:${VARNISH_PORT}/" \
    >/dev/null
then

    check_pass "Varnish"

else

    check_fail "Varnish"

fi


# ==========================================================
# STORE
# ==========================================================

echo
echo "[9] Magento Store"

HTTP_CODE="$(
    curl \
        -L \
        -s \
        -o /dev/null \
        -w "%{http_code}" \
        "http://localhost:${VARNISH_PORT}/"
)"


if [[ "$HTTP_CODE" =~ ^2|3 ]]; then

    check_pass "Magento Store HTTP ${HTTP_CODE}"

else

    check_fail "Magento Store HTTP ${HTTP_CODE}"

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


if [[ "$FAIL" -gt 0 ]]; then

    echo "Health check FAILED."

    exit 1

fi


echo "All health checks PASSED."

echo
