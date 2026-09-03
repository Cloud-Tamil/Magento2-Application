#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose stop

echo
echo "Magento Docker stack stopped."
