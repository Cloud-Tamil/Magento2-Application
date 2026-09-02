# Magento 2.4.8-p5 Docker

Magento Open Source 2.4.8-p5 local Docker environment.

## Stack

- Magento Open Source 2.4.8-p5
- PHP 8.4
- Composer 2.10
- MariaDB 11.8
- OpenSearch 3
- Valkey 8.1
- Nginx 1.30
- Docker Compose v2

## Architecture

Browser
|
v
Nginx
|
v
PHP-FPM
|
+--> MariaDB
|
+--> Valkey
|
+--> OpenSearch

## Prerequisites

- Docker
- Docker Compose v2
- Adobe Commerce Marketplace account
- Magento authentication keys

## Authentication

Do not commit authentication keys.

Set:

```bash
export COMPOSER_AUTH='{
  "http-basic": {
    "repo.magento.com": {
      "username": "YOUR_PUBLIC_KEY",
      "password": "YOUR_PRIVATE_KEY"
    }
  }
}
```bash

# 3. Start the Application

## Start all containers

```bash
docker compose up -d
```

## Start and watch logs

```bash
docker compose up
```

## Build images

```bash
docker compose build
```

## Rebuild PHP image

```bash
docker compose build --no-cache php
```

## Start after rebuild

```bash
docker compose up -d
```

---

# 4. Stop the Application

## Stop containers

```bash
docker compose stop
```

## Stop and remove containers

```bash
docker compose down
```

## Stop and remove containers + networks

```bash
docker compose down --remove-orphans
```

---

# 5. ⚠️ Complete Clean Installation

Use this ONLY when you want to delete the existing Magento database, Valkey data, OpenSearch data, and Magento application volume.

```bash
docker compose down -v --remove-orphans
```

Then:

```bash
docker compose build --no-cache php
```

Then:

```bash
docker compose up -d
```

Watch installation:

```bash
docker compose logs -f php
```

> ⚠️ `docker compose down -v` deletes Docker volumes. Do not use it on an installation containing data you want to preserve.

---

# 6. Access Magento

## Storefront

```text
http://localhost:8080/
```

## Magento Admin

```text
http://localhost:8080/admin
```

The admin path is controlled by:

```env
MAGENTO_ADMIN_URI=admin
```

---

# 7. Check Container Status

```bash
docker compose ps
```

Detailed:

```bash
docker compose ps -a
```

Expected:

```text
magento-db
magento-valkey
magento-opensearch
magento-php
magento-nginx
```

---

# 8. Check Docker Resources

```bash
docker stats
```

Check disk usage:

```bash
docker system df
```

Check Docker volumes:

```bash
docker volume ls
```

Check Docker networks:

```bash
docker network ls
```

---

# 9. Access PHP Container

Open an interactive shell:

```bash
docker compose exec php bash
```

If `bash` is unavailable:

```bash
docker compose exec php sh
```

Inside the container:

```bash
cd /var/www/html
```

Check files:

```bash
ls -la
```

Check Magento:

```bash
php bin/magento --version
```

Exit:

```bash
exit
```

---

# 10. Access PHP as `www-data`

Magento commands should generally run as the Magento filesystem owner.

```bash
docker compose exec php \
  su -s /bin/bash www-data
```

Then:

```bash
cd /var/www/html
```

Check:

```bash
php bin/magento --version
```

Exit:

```bash
exit
```

---

# 11. Magento CLI Commands

## Magento version

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento --version"
```

## List commands

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento list"
```

## Check deployment mode

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento deploy:mode:show"
```

## Set developer mode

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento deploy:mode:set developer"
```

## Set production mode

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento deploy:mode:set production"
```

---

# 12. Magento Cache

## Cache status

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:status"
```

## Flush cache

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:flush"
```

## Clean cache

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:clean"
```

---

# 13. Magento Indexers

## Check indexer status

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento indexer:status"
```

## Show indexers

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento indexer:info"
```

## Reindex everything

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento indexer:reindex"
```

## Reset indexers

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento indexer:reset"
```

---

# 14. Magento Setup Commands

## Setup upgrade

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:upgrade"
```

## Dependency compilation

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:di:compile"
```

## Static content deployment

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:static-content:deploy -f"
```

## Database status

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:db:status"
```

---

# 15. Check Magento Installation

Check `env.php`:

```bash
docker compose exec php \
  test -f /var/www/html/app/etc/env.php \
  && echo "Magento installed" \
  || echo "Magento NOT installed"
```

Check Magento CLI:

```bash
docker compose exec php \
  php /var/www/html/bin/magento --version
```

---

# 16. PHP Information

## PHP version

```bash
docker compose exec php php -v
```

## PHP modules

```bash
docker compose exec php php -m
```

## Check Redis extension

```bash
docker compose exec php \
  php -m | grep -i redis
```

Expected:

```text
redis
```

## Check important Magento extensions

```bash
docker compose exec php php -m | grep -Ei \
'bcmath|ctype|curl|dom|fileinfo|gd|iconv|intl|mbstring|openssl|pdo_mysql|simplexml|soap|sockets|xml|xsl|zip|redis'
```

---

# 17. PHP-FPM Verification

Test PHP-FPM:

```bash
docker compose exec php php-fpm -t
```

Expected:

```text
configuration file ... test is successful
```

Check PHP-FPM listening port:

```bash
docker compose exec php \
  php-fpm -tt 2>&1 | grep "listen ="
```

Expected:

```text
listen = 9000
```

---

# 18. Access Nginx Container

```bash
docker compose exec nginx bash
```

Check document root:

```bash
ls -la /var/www/html/pub
```

Exit:

```bash
exit
```

---

# 19. Nginx Configuration Test

```bash
docker compose exec nginx nginx -t
```

Expected:

```text
syntax is ok
test is successful
```

Show complete configuration:

```bash
docker compose exec nginx nginx -T
```

---

# 20. Check Nginx → PHP-FPM Connectivity

From Nginx:

```bash
docker compose exec nginx \
  getent hosts php
```

Expected:

```text
php <container-ip>
```

Check port:

```bash
docker compose exec nginx \
  bash -c 'cat < /dev/null > /dev/tcp/php/9000' \
  && echo "PHP-FPM reachable" \
  || echo "PHP-FPM NOT reachable"
```

---

# 21. Nginx Logs

## Follow logs

```bash
docker compose logs -f nginx
```

## Last 100 lines

```bash
docker compose logs --tail=100 nginx
```

## With timestamps

```bash
docker compose logs -f -t nginx
```

---

# 22. PHP Logs

```bash
docker compose logs -f php
```

Last 200 lines:

```bash
docker compose logs --tail=200 php
```

---

# 23. MariaDB Logs

```bash
docker compose logs -f db
```

---

# 24. Valkey Logs

```bash
docker compose logs -f valkey
```

---

# 25. OpenSearch Logs

```bash
docker compose logs -f opensearch
```

---

# 26. MariaDB Access

Open MariaDB shell:

```bash
docker compose exec db \
  mariadb \
  -u"${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  "${MYSQL_DATABASE}"
```

If environment variables are not available in your host shell, use:

```bash
docker compose exec db \
  mariadb \
  -umagento \
  -p \
  magento
```

It will prompt for the password.

---

# 27. MariaDB Basic Commands

Inside MariaDB:

```sql
SHOW DATABASES;
```

Select Magento database:

```sql
USE magento;
```

Show tables:

```sql
SHOW TABLES;
```

Check Magento tables:

```sql
SHOW TABLES LIKE 'catalog%';
```

Check database:

```sql
SELECT DATABASE();
```

Exit:

```sql
EXIT;
```

---

# 28. MariaDB Health Check

```bash
docker compose exec db \
  mariadb-admin \
  ping \
  -umagento \
  -p
```

Expected:

```text
mysqld is alive
```

---

# 29. Test PHP → MariaDB

From PHP:

```bash
docker compose exec php \
  mysql \
  -h db \
  -P 3306 \
  -u"${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  -e "SELECT 1;"
```

If host environment variables aren't exported:

```bash
docker compose exec php \
  mysql \
  -h db \
  -P 3306 \
  -umagento \
  -p \
  -e "SELECT 1;"
```

---

# 30. Valkey Access

Open Valkey CLI:

```bash
docker compose exec valkey valkey-cli
```

Test:

```text
PING
```

Expected:

```text
PONG
```

Exit:

```text
exit
```

---

# 31. Valkey Commands

```bash
docker compose exec valkey valkey-cli ping
```

Expected:

```text
PONG
```

Check server:

```bash
docker compose exec valkey \
  valkey-cli INFO server
```

Check memory:

```bash
docker compose exec valkey \
  valkey-cli INFO memory
```

Check keys:

```bash
docker compose exec valkey \
  valkey-cli DBSIZE
```

---

# 32. Test PHP → Valkey

```bash
docker compose exec php php -r '
$r = new Redis();
$r->connect("valkey", 6379);
$r->set("test", "success", 60);
echo $r->get("test"), PHP_EOL;
'
```

Expected:

```text
success
```

---

# 33. OpenSearch Access

From host:

```bash
curl http://localhost:9200/
```

Health:

```bash
curl http://localhost:9200/_cluster/health
```

Pretty output:

```bash
curl -s http://localhost:9200/_cluster/health | python -m json.tool
```

---

# 34. OpenSearch Cluster Status

```bash
curl http://localhost:9200/_cluster/health?pretty
```

Expected:

```json
{
  "status": "green"
}
```

`yellow` can be acceptable in some single-node development configurations, but investigate unexpected persistent `red` status.

---

# 35. OpenSearch Indices

```bash
curl http://localhost:9200/_cat/indices?v
```

Magento indices:

```bash
curl http://localhost:9200/_cat/indices?v | grep magento
```

---

# 36. Test PHP → OpenSearch

```bash
docker compose exec php \
  curl -fsS \
  http://opensearch:9200/_cluster/health
```

Expected JSON containing:

```text
"status":"green"
```

---

# 37. Docker Network

Show network:

```bash
docker network ls
```

Inspect Magento network:

```bash
docker network inspect test-magento2_magento
```

If the network has a different generated name:

```bash
docker compose config --networks
```

---

# 38. Test Container DNS

From PHP:

```bash
docker compose exec php getent hosts db
```

```bash
docker compose exec php getent hosts valkey
```

```bash
docker compose exec php getent hosts opensearch
```

```bash
docker compose exec php getent hosts php
```

Expected: each service resolves to a Docker IP address.

---

# 39. Test Network Connectivity

PHP → MariaDB:

```bash
docker compose exec php \
  bash -c 'cat < /dev/null > /dev/tcp/db/3306' \
  && echo "MariaDB reachable"
```

PHP → Valkey:

```bash
docker compose exec php \
  bash -c 'cat < /dev/null > /dev/tcp/valkey/6379' \
  && echo "Valkey reachable"
```

PHP → OpenSearch:

```bash
docker compose exec php \
  bash -c 'cat < /dev/null > /dev/tcp/opensearch/9200' \
  && echo "OpenSearch reachable"
```

---

# 40. Health Checks

Check Compose status:

```bash
docker compose ps
```

Inspect MariaDB health:

```bash
docker inspect magento-db \
  --format='{{json .State.Health}}'
```

Valkey:

```bash
docker inspect magento-valkey \
  --format='{{json .State.Health}}'
```

OpenSearch:

```bash
docker inspect magento-opensearch \
  --format='{{json .State.Health}}'
```

PHP:

```bash
docker inspect magento-php \
  --format='{{json .State.Health}}'
```

---

# 41. Magento File Permissions

Check ownership:

```bash
docker compose exec php \
  ls -ld /var/www/html
```

Check:

```bash
docker compose exec php \
  ls -ld \
  /var/www/html/var \
  /var/www/html/generated \
  /var/www/html/pub/static \
  /var/www/html/pub/media \
  /var/www/html/app/etc
```

Expected owner:

```text
www-data www-data
```

---

# 42. Fix Magento Permissions

```bash
docker compose exec php \
  chown -R www-data:www-data /var/www/html
```

Then:

```bash
docker compose exec php \
  chmod -R 775 \
  /var/www/html/var \
  /var/www/html/generated \
  /var/www/html/pub/static \
  /var/www/html/pub/media \
  /var/www/html/app/etc
```

---

# 43. Magento Cache Directory Cleanup

For development troubleshooting:

```bash
docker compose exec php \
  rm -rf \
  var/cache/* \
  var/page_cache/* \
  generated/code/* \
  generated/metadata/*
```

Then:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:flush"
```

---

# 44. Static Content Problems

If CSS/JS is missing:

```bash
docker compose exec php \
  rm -rf pub/static/_cache
```

Then:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:static-content:deploy -f"
```

Then:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:flush"
```

---

# 45. Magento Compilation Problems

Run:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:di:compile"
```

If generated files are corrupted:

```bash
docker compose exec php \
  rm -rf generated/code/* generated/metadata/*
```

Then:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:di:compile"
```

---

# 46. OpenSearch `red` Resolution

Check:

```bash
curl http://localhost:9200/_cluster/health?pretty
```

Check indices:

```bash
curl http://localhost:9200/_cat/indices?v
```

Check OpenSearch logs:

```bash
docker compose logs --tail=200 opensearch
```

Restart OpenSearch:

```bash
docker compose restart opensearch
```

Wait:

```bash
docker compose ps
```

Then:

```bash
curl http://localhost:9200/_cluster/health?pretty
```

---

# 47. Magento Search Troubleshooting

Check indexers:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento indexer:status"
```

Reindex:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento indexer:reindex"
```

Flush cache:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:flush"
```

---

# 48. `CrashLoopBackOff` / Container Restarting

Check:

```bash
docker compose ps
```

Then:

```bash
docker compose logs --tail=200 php
```

Look for:

```text
ERROR
entrypoint.sh failed
PHP Fatal error
SQLSTATE
Connection refused
OpenSearch
Valkey
```

Check restart count:

```bash
docker inspect magento-php \
  --format='RestartCount={{.RestartCount}}'
```

---

# 49. Magento PHP Container Keeps Restarting

First:

```bash
docker compose logs --tail=300 php
```

Then check:

```bash
docker compose ps
```

Check dependencies:

```bash
docker compose ps db valkey opensearch
```

Test database:

```bash
docker compose exec db mariadb-admin ping -uroot -p
```

Test Valkey:

```bash
docker compose exec valkey valkey-cli ping
```

Test OpenSearch:

```bash
curl http://localhost:9200/_cluster/health
```

---

# 50. `Connection refused` — MariaDB

Check:

```bash
docker compose ps db
```

Check logs:

```bash
docker compose logs --tail=200 db
```

Check health:

```bash
docker inspect magento-db \
  --format='{{json .State.Health}}'
```

Restart:

```bash
docker compose restart db
```

Wait for health:

```bash
docker compose ps
```

---

# 51. `Connection refused` — Valkey

Check:

```bash
docker compose ps valkey
```

Test:

```bash
docker compose exec valkey valkey-cli ping
```

Expected:

```text
PONG
```

Logs:

```bash
docker compose logs --tail=200 valkey
```

Restart:

```bash
docker compose restart valkey
```

---

# 52. `Connection refused` — OpenSearch

Check:

```bash
docker compose ps opensearch
```

Logs:

```bash
docker compose logs --tail=300 opensearch
```

Test:

```bash
curl http://localhost:9200/_cluster/health
```

Restart:

```bash
docker compose restart opensearch
```

---

# 53. Nginx Returns `502 Bad Gateway`

Check PHP:

```bash
docker compose ps php
```

Check PHP logs:

```bash
docker compose logs --tail=200 php
```

Check PHP-FPM:

```bash
docker compose exec php php-fpm -t
```

Check listening port:

```bash
docker compose exec php \
  php-fpm -tt 2>&1 | grep "listen ="
```

Expected:

```text
listen = 9000
```

Check Nginx:

```bash
docker compose exec nginx nginx -t
```

Check connectivity:

```bash
docker compose exec nginx \
  bash -c 'cat < /dev/null > /dev/tcp/php/9000'
```

---

# 54. Nginx Returns `403 Forbidden`

Check document root:

```bash
docker compose exec nginx \
  ls -la /var/www/html/pub
```

Check Magento:

```bash
docker compose exec php \
  ls -la /var/www/html/pub/index.php
```

Check permissions:

```bash
docker compose exec php \
  ls -ld /var/www/html/pub
```

Check Nginx logs:

```bash
docker compose logs --tail=200 nginx
```

---

# 55. Nginx Returns `404`

Check:

```bash
docker compose exec nginx \
  nginx -t
```

Check:

```bash
docker compose exec nginx \
  ls -la /var/www/html/pub
```

Check Magento CLI:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento --version"
```

Check:

```bash
docker compose exec php \
  test -f /var/www/html/pub/index.php \
  && echo "index.php exists"
```

---

# 56. Browser Shows Magento Installation Error

Run:

```bash
docker compose logs --tail=300 php
```

Check:

```bash
docker compose exec php \
  test -f /var/www/html/app/etc/env.php \
  && echo "Installed"
```

Check database:

```bash
docker compose exec db \
  mariadb -uroot -p \
  -e "SHOW DATABASES;"
```

---

# 57. `setup:install` Failed

Check:

```bash
docker compose logs --tail=300 php
```

Check database:

```bash
docker compose exec db mariadb-admin ping -uroot -p
```

Check OpenSearch:

```bash
curl http://localhost:9200/_cluster/health
```

Check Valkey:

```bash
docker compose exec valkey valkey-cli ping
```

Check Magento CLI:

```bash
docker compose exec php \
  php /var/www/html/bin/magento --version
```

If this is a disposable development installation, reset:

```bash
docker compose down -v --remove-orphans
```

Then:

```bash
docker compose build --no-cache php
```

Then:

```bash
docker compose up -d
```

---

# 58. Composer Authentication Problems

Check whether the variable exists inside PHP:

```bash
docker compose exec php \
  sh -c 'test -n "$COMPOSER_AUTH" && echo "COMPOSER_AUTH configured" || echo "COMPOSER_AUTH missing"'
```

Validate Composer:

```bash
docker compose exec php composer diagnose
```

Do NOT print the actual Composer credentials.

If authentication fails:

1. Generate/verify Adobe Commerce Marketplace credentials.
2. Update `.env`.
3. Recreate the PHP container.

```bash
docker compose up -d --force-recreate php
```

---

# 59. Check Composer

```bash
docker compose exec php composer --version
```

Check Magento package:

```bash
docker compose exec php \
  composer show magento/project-community-edition
```

---

# 60. Check Magento Environment

```bash
docker compose exec php \
  env | grep -E \
  'MAGENTO_|MYSQL_|VALKEY_|OPENSEARCH_'
```

Do not use this command if your terminal output could be logged or shared, because it may expose passwords.

Safer:

```bash
docker compose exec php \
  sh -c 'echo "MYSQL_HOST=$MYSQL_HOST"; echo "VALKEY_HOST=$VALKEY_HOST"; echo "OPENSEARCH_HOST=$OPENSEARCH_HOST"; echo "MAGENTO_BASE_URL=$MAGENTO_BASE_URL"'
```

---

# 61. Check Docker Compose Configuration

Before starting:

```bash
docker compose config
```

Validate without starting:

```bash
docker compose config --quiet
```

If successful, no output is expected.

---

# 62. Check Mounted Volumes

```bash
docker inspect magento-php \
  --format='{{json .Mounts}}'
```

Check application volume:

```bash
docker volume ls | grep magento
```

---

# 63. Check Application Files from Nginx

```bash
docker compose exec nginx \
  ls -la /var/www/html
```

Check:

```bash
docker compose exec nginx \
  ls -la /var/www/html/pub
```

Important:

```text
Nginx root = /var/www/html/pub
```

---

# 64. Check Magento URL

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento config:show web/unsecure/base_url"
```

For HTTPS configuration:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento config:show web/secure/base_url"
```

---

# 65. Change Magento Base URL

Example:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:store-config:set --base-url=http://localhost:8080/"
```

Then:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:flush"
```

---

# 66. Check Admin URL

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento info:adminuri"
```

Expected:

```text
Admin URI: /admin/
```

---

# 67. Change Admin URI

Example:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:config:set --backend-frontname=admin"
```

Then:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:flush"
```

---

# 68. Check Magento Logs

Inside PHP:

```bash
docker compose exec php \
  ls -lah /var/www/html/var/log
```

System log:

```bash
docker compose exec php \
  tail -f /var/www/html/var/log/system.log
```

Exception log:

```bash
docker compose exec php \
  tail -f /var/www/html/var/log/exception.log
```

---

# 69. Check Report Files

```bash
docker compose exec php \
  ls -lah /var/www/html/var/report
```

---

# 70. Complete Troubleshooting Sequence

When Magento is not working, use this order.

## Step 1 — Container status

```bash
docker compose ps
```

## Step 2 — PHP logs

```bash
docker compose logs --tail=200 php
```

## Step 3 — Nginx logs

```bash
docker compose logs --tail=200 nginx
```

## Step 4 — Database

```bash
docker compose exec db mariadb-admin ping -uroot -p
```

## Step 5 — Valkey

```bash
docker compose exec valkey valkey-cli ping
```

## Step 6 — OpenSearch

```bash
curl http://localhost:9200/_cluster/health?pretty
```

## Step 7 — Magento

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento --version"
```

## Step 8 — Magento installation

```bash
docker compose exec php \
  test -f /var/www/html/app/etc/env.php \
  && echo "Installed" \
  || echo "Not installed"
```

## Step 9 — Nginx configuration

```bash
docker compose exec nginx nginx -t
```

## Step 10 — Browser

```text
http://localhost:8080/
```

---

# 71. One-Command Diagnostic Collection

Run:

```bash
docker compose ps

echo "========== PHP =========="
docker compose logs --tail=100 php

echo "========== NGINX =========="
docker compose logs --tail=100 nginx

echo "========== DATABASE =========="
docker compose logs --tail=50 db

echo "========== VALKEY =========="
docker compose exec valkey valkey-cli ping

echo "========== OPENSEARCH =========="
curl -s http://localhost:9200/_cluster/health?pretty

echo "========== MAGENTO =========="
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento --version"

echo "========== NGINX TEST =========="
docker compose exec nginx nginx -t
```

---

# 72. Recommended Daily Workflow

Start:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs -f php nginx
```

Magento CLI:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento --version"
```

Storefront:

```text
http://localhost:8080/
```

Admin:

```text
http://localhost:8080/admin
```

Stop:

```bash
docker compose stop
```

---

# 73. Recommended Development Workflow

After changing PHP/Dockerfile:

```bash
docker compose build --no-cache php
docker compose up -d
```

After changing Nginx:

```bash
docker compose exec nginx nginx -t
docker compose restart nginx
```

After Magento configuration changes:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento cache:flush"
```

After module changes:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:upgrade"
```

After production compilation:

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento setup:di:compile"
```

---

# 74. ⚠️ Never Use These Commands Casually

The following can destroy application data:

```bash
docker compose down -v
```

```bash
docker volume prune
```

```bash
docker system prune -a --volumes
```

```bash
rm -rf var/*
```

```bash
rm -rf generated/*
```

Use destructive commands only when you understand exactly what data is being removed.

---

# 75. Security Checklist

Before committing the project:

```bash
git status
```

Make sure `.env` is ignored:

```bash
git check-ignore .env
```

Check for accidentally committed secrets:

```bash
git grep -n "repo.magento.com"
```

```bash
git grep -n "MYSQL_PASSWORD"
```

Never commit:

```text
.env
auth.json
Composer private keys
Database passwords
Magento admin passwords
API keys
Cloud credentials
AWS access keys
GCP service-account keys
Azure credentials
```

If a real credential has already been exposed, **rotate/revoke it**.

---

# 76. Final Verification Checklist

Run all of these:

```bash
docker compose config --quiet
```

```bash
docker compose ps
```

```bash
docker compose exec nginx nginx -t
```

```bash
docker compose exec php php-fpm -t
```

```bash
docker compose exec valkey valkey-cli ping
```

```bash
curl http://localhost:9200/_cluster/health
```

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento --version"
```

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento deploy:mode:show"
```

```bash
docker compose exec php \
  su -s /bin/bash www-data \
  -c "php bin/magento indexer:status"
```

Then test:

```text
http://localhost:8080/
```

and:

```text
http://localhost:8080/admin
```

---

# 77. Quick Command Reference

| Task            | Command                                          |
| --------------- | ------------------------------------------------ |
| Start           | `docker compose up -d`                           |
| Stop            | `docker compose stop`                            |
| Remove          | `docker compose down`                            |
| Clean install   | `docker compose down -v`                         |
| Status          | `docker compose ps`                              |
| PHP logs        | `docker compose logs -f php`                     |
| Nginx logs      | `docker compose logs -f nginx`                   |
| DB logs         | `docker compose logs -f db`                      |
| Valkey logs     | `docker compose logs -f valkey`                  |
| OpenSearch logs | `docker compose logs -f opensearch`              |
| PHP shell       | `docker compose exec php bash`                   |
| Magento version | `php bin/magento --version`                      |
| Cache flush     | `php bin/magento cache:flush`                    |
| Reindex         | `php bin/magento indexer:reindex`                |
| Setup upgrade   | `php bin/magento setup:upgrade`                  |
| DI compile      | `php bin/magento setup:di:compile`               |
| Static deploy   | `php bin/magento setup:static-content:deploy -f` |
| DB test         | `mariadb-admin ping`                             |
| Valkey test     | `valkey-cli ping`                                |
| OpenSearch test | `curl http://localhost:9200/_cluster/health`     |
| Nginx test      | `nginx -t`                                       |
| PHP-FPM test    | `php-fpm -t`                                     |
| Storefront      | `http://localhost:8080/`                         |
| Admin           | `http://localhost:8080/admin`                    |

---

# 78. Golden Troubleshooting Rule

When something fails, **do not immediately run `docker compose down -v`**.

Use:

```text
1. docker compose ps
        ↓
2. docker compose logs
        ↓
3. Check DB
        ↓
4. Check Valkey
        ↓
5. Check OpenSearch
        ↓
6. Check PHP-FPM
        ↓
7. Check Nginx
        ↓
8. Check Magento CLI
        ↓
9. Fix the actual error
        ↓
10. Reset volumes ONLY if necessary
```

This approach prevents accidental data loss and makes the Docker environment much easier to troubleshoot.

