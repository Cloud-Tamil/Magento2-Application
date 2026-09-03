#!/usr/bin/env bash

set -Eeuo pipefail


cd "$(dirname "${BASH_SOURCE[0]}")/.."


echo

echo "============================================================"

echo "VARNISH CONFIGURATION"

echo "============================================================"

echo

echo "Using maintained local VCL:"

echo "docker/varnish/default.vcl"

echo

echo "Restarting Varnish..."


docker compose restart varnish


echo

echo "Varnish restarted."
