#!/bin/bash

set -Eeuo pipefail

echo "=================================================="
echo " Magento Docker Health Check"
echo "=================================================="


echo ""
echo "Containers"
echo "----------"

docker compose ps


echo ""
echo "MariaDB"
echo "-------"

docker compose exec db \
    mariadb-admin ping \
    -uroot \
    -p"${MYSQL_ROOT_PASSWORD}"


echo ""
echo "Valkey"
echo "------"

docker compose exec valkey \
    valkey-cli ping


echo ""
echo "OpenSearch"
echo "----------"

curl -fsS \
    http://localhost:9200/_cluster/health

echo ""


echo ""
echo "Magento"
echo "-------"

docker compose exec php \
    php bin/magento --version


echo ""
echo "Magento source"
echo "--------------"

if [[ -f "./src/bin/magento" ]]; then
    echo "OK: ./src/bin/magento exists"
else
    echo "ERROR: Magento source not found."
    exit 1
fi


echo ""
echo "Nginx"
echo "-----"

curl -fsS \
    http://localhost:8080/ \
    >/dev/null

echo "Nginx storefront is reachable."


echo ""
echo "=================================================="
echo " HEALTH CHECK PASSED"
echo "=================================================="
