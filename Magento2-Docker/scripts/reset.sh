#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo
echo "=================================================="
echo " WARNING"
echo "=================================================="
echo
echo "This will DELETE:"
echo
echo "  Docker containers"
echo "  Magento database"
echo "  Valkey data"
echo "  OpenSearch data"
echo
echo "Magento source under src/ will also be removed."
echo

read -r -p "Type DELETE to continue: " ANSWER

if [[ "$ANSWER" != "DELETE" ]]; then

    echo
    echo "Cancelled."

    exit 0

fi

echo
echo "Stopping containers..."

docker compose down -v --remove-orphans

echo
echo "Removing Magento source..."

rm -rf src/*

echo
echo "Reset completed."
