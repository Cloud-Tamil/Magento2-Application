#!/bin/bash

set -Eeuo pipefail

echo "=================================================="
echo " Magento 2 Docker Installation"
echo "=================================================="


# ==========================================================
# REQUIREMENTS
# ==========================================================

if ! command -v docker >/dev/null 2>&1; then

    echo "ERROR: Docker is not installed."

    exit 1

fi


if ! docker compose version >/dev/null 2>&1; then

    echo "ERROR: Docker Compose v2 is required."

    exit 1

fi


# ==========================================================
# ENVIRONMENT
# ==========================================================

if [[ ! -f ".env" ]]; then

    echo ""
    echo "Creating .env from .env.example..."

    cp .env.example .env

    echo ""
    echo "IMPORTANT:"
    echo "Edit .env and configure:"
    echo ""
    echo "  COMPOSER_AUTH"
    echo "  MYSQL_PASSWORD"
    echo "  MYSQL_ROOT_PASSWORD"
    echo "  MAGENTO_ADMIN_PASSWORD"
    echo ""

    exit 1

fi


# ==========================================================
# SRC
# ==========================================================

mkdir -p src


# ==========================================================
# BUILD
# ==========================================================

echo ""
echo "Building Magento PHP image..."

docker compose build --no-cache php


# ==========================================================
# START
# ==========================================================

echo ""
echo "Starting Magento services..."

docker compose up -d


# ==========================================================
# STATUS
# ==========================================================

echo ""
echo "Waiting for containers..."

sleep 10

docker compose ps


echo ""
echo "=================================================="
echo " Installation process started"
echo "=================================================="

echo ""
echo "Magento:"
echo "http://localhost:8080"

echo ""
echo "Magento source:"
echo "./src"

echo ""
echo "Admin:"
echo "http://localhost:8080/<MAGENTO_ADMIN_URI>"
