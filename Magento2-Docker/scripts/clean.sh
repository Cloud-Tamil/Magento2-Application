#!/bin/bash

set -Eeuo pipefail

echo "Stopping Magento..."

docker compose down

echo ""
read -r -p "Remove database/search/cache volumes? [y/N]: " answer

if [[ "${answer}" == "y" || "${answer}" == "Y" ]]; then

    docker compose down -v

    echo ""
    echo "Docker volumes removed."

else

    echo ""
    echo "Volumes preserved."

fi
