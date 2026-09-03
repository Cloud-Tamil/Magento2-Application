#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo
echo "=================================================="
echo " Generating Magento Varnish Configuration"
echo "=================================================="
echo

docker compose exec -T php \
    php bin/magento varnish:vcl:generate \
    --export-version=8 \
    > docker/varnish/generated.vcl

echo
echo "Generated:"
echo "  docker/varnish/generated.vcl"

echo
echo "Copying generated configuration..."

cp docker/varnish/generated.vcl \
   docker/varnish/default.vcl

echo
echo "Restarting Varnish..."

docker compose restart varnish

echo
echo "Varnish configuration updated."
