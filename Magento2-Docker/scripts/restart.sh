#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo
echo "Restarting Magento Docker..."
echo
docker compose restart

echo
echo "Waiting..."
sleep 5
docker compose ps

echo
echo "Store:"
echo "http://localhost:${VARNISH_PORT:-8080}"
echo
