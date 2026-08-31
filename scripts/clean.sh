#!/bin/bash

set -e

echo "Stopping Magento..."

docker compose down

echo ""
echo "Remove containers and volumes?"

read -r answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then

    docker compose down -v

    echo "All Magento Docker volumes removed."

fi
