#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."


echo
echo "=================================================="
echo " WARNING - FULL MAGENTO RESET"
echo "=================================================="
echo

echo "This will DELETE:"
echo

echo "  Containers"
echo "  Networks"
echo "  MariaDB data"
echo "  Valkey data"
echo "  OpenSearch data"
echo "  Magento source"
echo

echo "This operation cannot be undone."
echo


read -r -p "Type DELETE to continue: " ANSWER


if [[ "${ANSWER}" != "DELETE" ]]
then

    echo
    echo "Cancelled."
    exit 0

fi


echo
echo "Stopping Magento..."
echo


docker compose down \
    --volumes \
    --remove-orphans


echo
echo "Removing Magento source..."
echo


if [[ -d src ]]
then

    find src \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf {} +

else

    mkdir -p src

fi


echo
echo "Reset completed."
echo
