#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."


echo
echo "=================================================="
echo " Magento Varnish VCL Generator"
echo "=================================================="
echo


if [[ ! -f src/app/etc/env.php ]]; then

    echo "ERROR: Magento is not installed."

    exit 1
fi


echo "Generating Magento Varnish configuration..."


docker compose exec -T php \
    php bin/magento varnish:vcl:generate \
    --export-version=8 \
    > docker/varnish/generated.vcl


echo
echo "Generated:"
echo
echo "docker/varnish/generated.vcl"
echo


echo "Applying generated VCL..."


cp \
    docker/varnish/generated.vcl \
    docker/varnish/default.vcl


echo
echo "Restarting Varnish..."


docker compose restart varnish


echo
echo "Varnish configuration updated."
echo
