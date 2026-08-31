#!/bin/bash

set -e

echo "=============================================="
echo " Magento Docker Health Check"
echo "=============================================="


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

curl -fs http://localhost:9200/_cluster/health


echo ""
echo "Magento"
echo "-------"

docker compose exec php \
    php bin/magento --version


echo ""
echo "=============================================="
echo " Health check completed"
echo "=============================================="
