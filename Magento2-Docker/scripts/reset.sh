#!/usr/bin/env bash

set -Eeuo pipefail


cd "$(dirname "${BASH_SOURCE[0]}")/.."


echo
echo "WARNING!"
echo "This will delete:"
echo
echo "  - Docker containers"
echo "  - Docker volumes"
echo "  - Magento source"
echo "  - Database"
echo "  - Valkey data"
echo "  - OpenSearch data"
echo


read -r -p \
    "Type DELETE to continue: " \
    ANSWER


if [[ "$ANSWER" != "DELETE" ]]; then

    echo "Reset cancelled."

    exit 0

fi


docker compose down \
    --volumes \
    --remove-orphans


find src \
    -mindepth 1 \
    -maxdepth 1 \
    -exec rm -rf {} +


mkdir -p src


echo

echo "============================================================"

echo "RESET COMPLETED"

echo "============================================================"
