#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."


echo
echo "=================================================="
echo " Starting Magento Docker"
echo "=================================================="
echo


docker compose up -d


echo
echo "Waiting for containers..."
sleep 5


docker compose ps


echo
echo "Magento:"
echo "http://localhost:${VARNISH_PORT:-8080}"

echo
echo "Admin:"
echo "http://localhost:${VARNISH_PORT:-8080}/admin"

echo
echo "Direct Nginx:"
echo "http://localhost:${NGINX_PORT:-8081}"

echo
