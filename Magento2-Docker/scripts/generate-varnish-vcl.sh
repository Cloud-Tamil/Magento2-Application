#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo
echo "=================================================="
echo " Magento Varnish VCL Generator"
echo "=================================================="
echo

# ==========================================================
# VERIFY MAGENTO
# ==========================================================

if [[ ! -f src/app/etc/env.php ]]; then
    echo "ERROR: Magento is not installed."
    exit 1
fi

# ==========================================================
# VERIFY PHP CONTAINER
# ==========================================================

if ! docker compose ps --status running php >/dev/null 2>&1; then
    echo "ERROR: PHP container is not running."
    exit 1
fi

# ==========================================================
# GENERATE VCL
# ==========================================================

echo "Generating Magento Varnish configuration..."

docker compose exec -T \
    php \
    php bin/magento varnish:vcl:generate \
    > docker/varnish/generated.vcl

# ==========================================================
# VERIFY FILE
# ==========================================================

if [[ ! -s docker/varnish/generated.vcl ]]; then
    echo "ERROR: Varnish VCL generation failed."
    exit 1
fi

echo
echo "Generated:"
echo "docker/varnish/generated.vcl"

# ==========================================================
# VALIDATE VCL
# ==========================================================

echo
echo "Validating Varnish configuration..."

docker run --rm \
    -v "$(pwd)/docker/varnish/generated.vcl:/etc/varnish/default.vcl:ro" \
    varnish:8 \
    varnishd \
    -C \
    -f /etc/varnish/default.vcl \
    >/dev/null

echo "VCL validation: OK"

# ==========================================================
# APPLY
# ==========================================================

cp \
    docker/varnish/generated.vcl \
    docker/varnish/default.vcl

echo
echo "Restarting Varnish..."

docker compose restart varnish

echo
echo "Varnish configuration updated successfully."
echo
