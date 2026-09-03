#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source .env
set +a

echo
echo "=================================================="
echo " Magento Docker Health Check"
echo "=================================================="
echo


echo "[1] Docker containers"
echo

docker compose ps


echo
echo "[2] MariaDB"
echo

docker compose exec -T db \
    mariadb-admin ping \
    -h 127.0.0.1 \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --silent

echo "PASS"


echo
echo "[3] Valkey"
echo

VALKEY_RESULT="$(
    docker compose exec -T redis \
    valkey-cli ping
)"

if [[ "$VALKEY_RESULT" == *"PONG"* ]]; then

    echo "PASS"

else

    echo "FAIL"

    exit 1

fi


echo
echo "[4] OpenSearch"
echo

curl -fs \
    "http://localhost:${OPENSEARCH_HTTP_PORT}/_cluster/health"

echo
echo "PASS"


echo
echo "[5] Magento"
echo

docker compose exec -T php \
    php bin/magento --version


echo
echo "[6] Nginx"
echo

if curl -fsI \
    "http://localhost:${NGINX_PORT}" \
    >/dev/null
then

    echo "PASS"

else

    echo "FAIL"

fi


echo
echo "[7] Varnish"
echo

if curl -fsI \
    "http://localhost:${VARNISH_PORT}" \
    >/dev/null
then

    echo "PASS"

else

    echo "FAIL"

fi


echo
echo "[8] Magento Store"
echo

if curl -fs \
    "http://localhost:${VARNISH_PORT}/" \
    >/dev/null
then

    echo "PASS"

else

    echo "FAIL"

fi


echo
echo "=================================================="
echo " Health Check Completed"
echo "=================================================="
