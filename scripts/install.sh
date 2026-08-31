#!/bin/bash

set -e

echo "=============================================="
echo " Magento 2 Docker Installation"
echo "=============================================="


if ! command -v docker >/dev/null 2>&1; then

    echo "Docker is not installed."

    exit 1

fi


if ! docker compose version >/dev/null 2>&1; then

    echo "Docker Compose v2 is not available."

    exit 1

fi


if [ -z "${COMPOSER_AUTH}" ]; then

    echo ""
    echo "COMPOSER_AUTH is not configured."
    echo ""
    echo "Example:"
    echo ""
    echo 'export COMPOSER_AUTH='\''{"http-basic":{"repo.magento.com":{"username":"PUBLIC_KEY","password":"PRIVATE_KEY"}}}'\'''
    echo ""

    exit 1

fi


echo "Building Magento image..."

docker compose build --no-cache


echo "Starting containers..."

docker compose up -d


echo ""
echo "Waiting for Magento..."

sleep 15


docker compose ps


echo ""
echo "=============================================="
echo " Magento installation started"
echo "=============================================="
echo ""
echo "Open:"
echo ""
echo "http://localhost:8080"
echo ""
