#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose up -d

echo
echo "Magento Docker stack started."
echo

docker compose ps
