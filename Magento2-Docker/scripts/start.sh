#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source .env
set +a


echo
echo "=================================================="
echo " Starting Magento Docker"
echo "=================================================="
echo


docker compose up -d


echo
echo "Containers:"
echo

docker compose ps


echo
echo "Store:"
echo "http://localhost:${VARNISH_PORT}"


echo
echo "Admin:"
echo "http://localhost:${VARNISH_PORT}/${MAGENTO_ADMIN_FRONTNAME}"


echo
echo "Direct Nginx:"
echo "http://localhost:${NGINX_PORT}"


echo
