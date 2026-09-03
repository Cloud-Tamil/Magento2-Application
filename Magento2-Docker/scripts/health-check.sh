#!/usr/bin/env bash

set -Eeuo pipefail


cd "$(dirname "${BASH_SOURCE[0]}")/.."


set -a

source .env

set +a


FAIL=0


echo
echo "============================================================"
echo "MAGENTO DOCKER HEALTH CHECK"
echo "============================================================"


# ============================================================
# CONTAINERS
# ============================================================

echo
echo "[1] Docker Containers"

docker compose ps


# ============================================================
# MARIADB
# ============================================================

echo
echo "[2] MariaDB"

if docker compose exec -T db \
    mariadb-admin ping \
    -h 127.0.0.1 \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --silent
then

    echo "MariaDB: PASS"

else

    echo "MariaDB: FAIL"

    FAIL=1

fi


# ============================================================
# VALKEY
# ============================================================

echo
echo "[3] Valkey"

if docker compose exec -T redis \
    valkey-cli ping 2>/dev/null | grep -q PONG
then

    echo "Valkey: PASS"

else

    echo "Valkey: FAIL"

    FAIL=1

fi


# ============================================================
# OPENSEARCH
# ============================================================

echo
echo "[4] OpenSearch"

if curl -fs \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health" \
    >/dev/null
then

    echo "OpenSearch: PASS"

else

    echo "OpenSearch: FAIL"

    FAIL=1

fi


# ============================================================
# MAGENTO
# ============================================================

echo
echo "[5] Magento"

if docker compose exec -T php \
    php bin/magento --version
then

    echo "Magento CLI: PASS"

else

    echo "Magento CLI: FAIL"

    FAIL=1

fi


# ============================================================
# NGINX
# ============================================================

echo
echo "[6] Nginx"

if curl -fsI \
    "http://localhost:${NGINX_PORT}" \
    >/dev/null
then

    echo "Nginx: PASS"

else

    echo "Nginx: FAIL"

    FAIL=1

fi


# ============================================================
# VARNISH
# ============================================================

echo
echo "[7] Varnish"

if curl -fsI \
    "http://localhost:${VARNISH_PORT}" \
    >/dev/null
then

    echo "Varnish: PASS"

else

    echo "Varnish: FAIL"

    FAIL=1

fi


# ============================================================
# STORE
# ============================================================

echo
echo "[8] Magento Store"

if curl -fs \
    "http://localhost:${VARNISH_PORT}/" \
    >/dev/null
then

    echo "Magento Store: PASS"

else

    echo "Magento Store: FAIL"

    FAIL=1

fi


# ============================================================
# FINAL RESULT
# ============================================================

echo

if [[ $FAIL -eq 0 ]]; then

    echo "============================================================"

    echo "ALL HEALTH CHECKS PASSED"

    echo "============================================================"

else

    echo "============================================================"

    echo "HEALTH CHECK FAILED"

    echo "============================================================"

    exit 1

fi
