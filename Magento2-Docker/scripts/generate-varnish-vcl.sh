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
# GENERATE
# ==========================================================

echo "Generating Magento VCL..."


docker compose exec \
    -T \
    php \
    php bin/magento varnish:vcl:generate \
    > docker/varnish/generated.vcl


# ==========================================================
# VALIDATE
# ==========================================================

if [[ ! -s docker/varnish/generated.vcl ]]; then

    echo "ERROR: VCL generation failed."

    exit 1

fi


echo "Generated:"
echo "docker/varnish/generated.vcl"


# ==========================================================
# VALIDATE WITH VARNISH
# ==========================================================

echo
echo "Validating VCL..."


docker run \
    --rm \
    -v "$(pwd)/docker/varnish/generated.vcl:/etc/varnish/default.vcl:ro" \
    varnish:8 \
    varnishd \
    -C \
    -f /etc/varnish/default.vcl \
    >/dev/null


echo "VCL validation: OK"


echo
echo "NOTE:"
echo "The generated VCL has NOT replaced default.vcl."
echo
echo "Review it before production use."
echo
