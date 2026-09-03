#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose down

docker compose up -d

echo
echo "Magento Docker stack restarted."
echo

docker compose ps
