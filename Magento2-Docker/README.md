# Magento 2.4.8-p5 Docker Environment

Production-style local development environment for **Magento Open Source 2.4.8-p5** using Docker Compose.

## Architecture

```text
                         Browser
                            |
             +--------------+--------------+
             |                             |
       :8080 Varnish                  :8081 Nginx
             |                             |
             +-------------+---------------+
                           |
                        PHP-FPM
                           |
        +------------------+------------------+
        |                  |                  |
     MariaDB             Valkey           OpenSearch
      :3306               :6379              :9200
```

### Stack

| Component           | Version  |
| ------------------- | -------- |
| Magento Open Source | 2.4.8-p5 |
| PHP                 | 8.4      |
| MariaDB             | 11.8     |
| Valkey              | 8.1      |
| OpenSearch          | 3.x      |
| nginx               | 1.30     |
| Varnish             | 8.x      |
| Composer            | 2.10.x   |
| Docker Compose      | v2       |

---

# 1. Project Structure

```text
magento2-docker/
│
├── .env
├── .env.example
├── docker-compose.yml
├── README.md
│
├── docker/
│   ├── php/
│   │   ├── Dockerfile
│   │   ├── php.ini
│   │   ├── opcache.ini
│   │   └── www.conf
│   │
│   ├── nginx/
│   │   └── default.conf
│   │
│   └── varnish/
│       └── default.vcl
│
├── scripts/
│   ├── install-magento.sh
│   ├── configure-magento.sh
│   ├── generate-varnish.sh
│   ├── health-check.sh
│   ├── start.sh
│   ├── stop.sh
│   ├── restart.sh
│   ├── logs.sh
│   └── reset.sh
│
└── src/
    └── Magento source code
```

---

# 2. Prerequisites

Install:

* Docker
* Docker Compose v2
* Git
* curl
* bash

Check Docker:

```bash
docker --version
```

Check Docker Compose:

```bash
docker compose version
```

Check Git:

```bash
git --version
```

Check curl:

```bash
curl --version
```

---

# 3. Clone the Project

```bash
git clone <YOUR_REPOSITORY_URL>
```

Enter the project:

```bash
cd magento2-docker
```

Verify:

```bash
pwd
```

List files:

```bash
ls -la
```

---

# 4. Configure Environment

Create `.env` from the example:

```bash
cp .env.example .env
```

Edit:

```bash
nano .env
```

Example:

```env
MAGENTO_VERSION=2.4.8-p5

MAGENTO_BASE_URL=http://localhost:8080/

MYSQL_DATABASE=magento
MYSQL_USER=magento
MYSQL_PASSWORD=magento
MYSQL_ROOT_PASSWORD=magento_root

DB_HOST=db
DB_PORT=3306

REDIS_HOST=redis
REDIS_PORT=6379

OPENSEARCH_HOST=opensearch
OPENSEARCH_PORT=9200

HTTP_PORT=8080
NGINX_PORT=8081
VARNISH_PORT=8080

MAGENTO_ADMIN_FIRSTNAME=Admin
MAGENTO_ADMIN_LASTNAME=User
MAGENTO_ADMIN_EMAIL=admin@example.com
MAGENTO_ADMIN_USER=admin
MAGENTO_ADMIN_PASSWORD=Admin123!ChangeMe
MAGENTO_ADMIN_FRONTNAME=admin
```

> Do not commit `.env` if it contains real passwords or Composer credentials.

---

# 5. Verify Docker Compose Configuration

Before starting anything:

```bash
docker compose config
```

This command should complete without errors.

If you see:

```text
yaml: ...
```

or:

```text
environment variable ... is not set
```

fix the configuration before continuing.

---

# 6. Create Magento Source Directory

Make sure `src/` exists:

```bash
mkdir -p src
```

Verify:

```bash
ls -la
```

You should see:

```text
src/
```

---

# 7. Set Script Permissions

Run:

```bash
chmod +x scripts/*.sh
```

Verify:

```bash
ls -l scripts/
```

Expected:

```text
-rwxr-xr-x install-magento.sh
-rwxr-xr-x configure-magento.sh
-rwxr-xr-x generate-varnish.sh
-rwxr-xr-x health-check.sh
-rwxr-xr-x start.sh
-rwxr-xr-x stop.sh
-rwxr-xr-x restart.sh
-rwxr-xr-x logs.sh
-rwxr-xr-x reset.sh
```

---

# 8. First Installation

For a completely new project, run:

```bash
./scripts/install-magento.sh
```

The installation script should:

1. Check Docker
2. Check environment
3. Create `src/`
4. Start infrastructure
5. Wait for MariaDB
6. Wait for Valkey
7. Wait for OpenSearch
8. Download Magento
9. Configure Composer authentication
10. Install Magento
11. Configure Magento
12. Configure Redis/Valkey
13. Configure OpenSearch
14. Configure Varnish
15. Run Magento upgrade
16. Compile Magento
17. Deploy static content
18. Reindex Magento
19. Flush cache
20. Fix permissions
21. Run health checks

---

# 9. Clean Rebuild

If you already have a broken or partially installed Magento environment, **do not simply run `docker compose up -d`**.

Use the clean rebuild procedure below.

## Step 1 — Stop Containers

```bash
docker compose down --remove-orphans
```

---

## Step 2 — Full Reset

Run:

```bash
./scripts/reset.sh
```

If the script asks:

```text
Type DELETE to continue:
```

enter:

```text
DELETE
```

The reset should remove:

* Containers
* Networks
* Magento volumes
* Database data
* Redis/Valkey data
* OpenSearch data
* Existing Magento installation

> **Warning:** A full reset deletes local Magento database/index/cache data.

---

# 10. Manual Full Docker Cleanup

If `reset.sh` is unavailable or you need to manually clean the environment:

```bash
docker compose down --volumes --remove-orphans
```

Remove unused containers:

```bash
docker container prune -f
```

Remove unused networks:

```bash
docker network prune -f
```

Remove unused volumes:

```bash
docker volume prune -f
```

Check:

```bash
docker ps -a
```

---

# 11. Remove Existing Magento Source

If you want to completely reinstall Magento source:

```bash
rm -rf src/*
```

Recreate:

```bash
mkdir -p src
```

Verify:

```bash
ls -la src/
```

It should be empty before installation.

---

# 12. Rebuild Docker Images

After resetting:

```bash
docker compose build --no-cache
```

This forces Docker to rebuild the PHP/nginx/Varnish images instead of using cached layers.

Check images:

```bash
docker images
```

---

# 13. Start Infrastructure

Start containers:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

Expected services:

```text
magento-db
magento-redis
magento-opensearch
magento-php
magento-nginx
magento-varnish
```

---

# 14. Watch Container Startup

```bash
docker compose ps
```

Then:

```bash
docker compose logs --tail=100
```

For a specific service:

```bash
docker compose logs db
```

```bash
docker compose logs redis
```

```bash
docker compose logs opensearch
```

```bash
docker compose logs php
```

```bash
docker compose logs nginx
```

```bash
docker compose logs varnish
```

Follow logs:

```bash
docker compose logs -f
```

Press:

```text
CTRL+C
```

to stop following logs.

---

# 15. Verify MariaDB

Run:

```bash
docker compose exec db \
mariadb-admin ping \
-h 127.0.0.1 \
-u root \
-p"${MYSQL_ROOT_PASSWORD}" \
--silent
```

Expected:

```text
mysqld is alive
```

You can also connect:

```bash
docker compose exec db \
mariadb \
-u root \
-p"${MYSQL_ROOT_PASSWORD}"
```

Check databases:

```sql
SHOW DATABASES;
```

Exit:

```sql
exit
```

---

# 16. Verify Valkey

Run:

```bash
docker compose exec redis valkey-cli ping
```

Expected:

```text
PONG
```

Check Valkey:

```bash
docker compose exec redis valkey-cli info server
```

---

# 17. Verify OpenSearch

From the host:

```bash
curl http://localhost:9200
```

Check cluster health:

```bash
curl http://localhost:9200/_cluster/health
```

For readable JSON:

```bash
curl -s http://localhost:9200/_cluster/health | python3 -m json.tool
```

Expected status for the single-node development environment:

```json
{
    "status": "green"
}
```

Also check:

```bash
curl http://localhost:9200/_cat/nodes?v
```

And:

```bash
curl http://localhost:9200/_cat/indices?v
```

---

# 18. Verify PHP

Run:

```bash
docker compose exec php php -v
```

Expected:

```text
PHP 8.4.x
```

Check loaded modules:

```bash
docker compose exec php php -m
```

Check PHP configuration:

```bash
docker compose exec php php --ini
```

---

# 19. Verify Composer

```bash
docker compose exec php composer --version
```

Expected:

```text
Composer version 2.10.x
```

---

# 20. Verify Magento

After installation:

```bash
docker compose exec php php bin/magento --version
```

Expected:

```text
Magento CLI 2.4.8-p5
```

Check Magento modules:

```bash
docker compose exec php php bin/magento module:status
```

Check Magento mode:

```bash
docker compose exec php php bin/magento deploy:mode:show
```

---

# 21. Verify Magento Configuration

Check Magento configuration:

```bash
docker compose exec php \
php bin/magento config:show web/unsecure/base_url
```

Expected:

```text
http://localhost:8080/
```

Check secure base URL:

```bash
docker compose exec php \
php bin/magento config:show web/secure/base_url
```

For this HTTP-only local environment:

```text
http://localhost:8080/
```

---

# 22. Verify Nginx

Nginx is exposed directly on:

```text
http://localhost:8081
```

Open in your browser:

```text
http://localhost:8081
```

Or test using curl:

```bash
curl -I http://localhost:8081
```

Expected response should contain something similar to:

```text
HTTP/1.1 200 OK
```

If Magento returns a redirect, that can also be normal depending on the configuration.

---

# 23. Verify Varnish

Varnish is the main public Magento endpoint:

```text
http://localhost:8080
```

Test:

```bash
curl -I http://localhost:8080
```

Check Varnish headers:

```bash
curl -I http://localhost:8080
```

Look for:

```text
Via:
X-Magento-Cache-Debug:
```

or other cache-related headers depending on your VCL/configuration.

---

# 24. Open Magento Store

Open:

```text
http://localhost:8080
```

This is the main Magento URL.

Architecture:

```text
Browser
   |
   v
Varnish :8080
   |
   v
Nginx
   |
   v
PHP-FPM
   |
   +---- MariaDB
   +---- Valkey
   +---- OpenSearch
```

---

# 25. Open Magento Admin

The default admin URL is:

```text
http://localhost:8080/admin
```

If you configured:

```env
MAGENTO_ADMIN_FRONTNAME=admin
```

open:

```text
http://localhost:8080/admin
```

Login using:

```text
Username:
admin
```

Password:

```text
Value configured in MAGENTO_ADMIN_PASSWORD
```

---

# 26. Find Magento Admin URL

If you are not sure about the admin frontname:

```bash
docker compose exec php \
php bin/magento info:adminuri
```

Example:

```text
Admin URI: /admin
```

---

# 27. Magento Cache

Check cache:

```bash
docker compose exec php \
php bin/magento cache:status
```

Flush cache:

```bash
docker compose exec php \
php bin/magento cache:flush
```

Clean cache:

```bash
docker compose exec php \
php bin/magento cache:clean
```

---

# 28. Magento Indexers

Check indexers:

```bash
docker compose exec php \
php bin/magento indexer:status
```

Reindex:

```bash
docker compose exec php \
php bin/magento indexer:reindex
```

Reset indexers:

```bash
docker compose exec php \
php bin/magento indexer:reset
```

---

# 29. Magento Upgrade Commands

Run:

```bash
docker compose exec php \
php bin/magento setup:upgrade
```

Then:

```bash
docker compose exec php \
php bin/magento setup:di:compile
```

Then:

```bash
docker compose exec php \
php bin/magento setup:static-content:deploy -f
```

Then:

```bash
docker compose exec php \
php bin/magento indexer:reindex
```

Finally:

```bash
docker compose exec php \
php bin/magento cache:flush
```

---

# 30. Configure Magento Script

If your project contains:

```text
scripts/configure-magento.sh
```

run:

```bash
./scripts/configure-magento.sh
```

This should configure:

* Base URL
* Database
* Valkey
* OpenSearch
* Admin settings
* Magento application settings

---

# 31. Generate Varnish Configuration

Run:

```bash
./scripts/generate-varnish.sh
```

Verify the generated configuration:

```bash
cat docker/varnish/default.vcl
```

Validate VCL from inside the Varnish container if supported by your image:

```bash
docker compose exec varnish varnishd -C -f /etc/varnish/default.vcl
```

If your Varnish image uses a different configuration path, inspect:

```bash
docker compose exec varnish ls -la /etc/varnish/
```

---

# 32. Restart Everything

Use the project script:

```bash
./scripts/restart.sh
```

Or manually:

```bash
docker compose restart
```

Check:

```bash
docker compose ps
```

---

# 33. Stop Everything

Recommended:

```bash
./scripts/stop.sh
```

Or:

```bash
docker compose down
```

This stops and removes containers but normally preserves named volumes.

---

# 34. Start Everything Again

```bash
./scripts/start.sh
```

Or:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

---

# 35. View Logs

Use:

```bash
./scripts/logs.sh
```

Or:

```bash
docker compose logs -f
```

PHP logs:

```bash
docker compose logs -f php
```

Nginx:

```bash
docker compose logs -f nginx
```

MariaDB:

```bash
docker compose logs -f db
```

Valkey:

```bash
docker compose logs -f redis
```

OpenSearch:

```bash
docker compose logs -f opensearch
```

Varnish:

```bash
docker compose logs -f varnish
```

---

# 36. Automated Health Check

Run:

```bash
./scripts/health-check.sh
```

Expected:

```text
==================================================
 Magento Docker Health Check
==================================================

[1] Docker containers

magento-db          Up
magento-redis       Up
magento-opensearch  Up
magento-php         Up
magento-nginx       Up
magento-varnish     Up

[2] MariaDB

PASS

[3] Valkey

PASS

[4] OpenSearch

PASS

[5] Magento

Magento CLI 2.4.8-p5

[6] Nginx

PASS

[7] Varnish

PASS

[8] Magento Store

PASS

==================================================
 Health Check Completed
==================================================
```

---

# 37. Complete Clean Installation

For a completely fresh installation, use this sequence.

## Step 1

```bash
cd magento2-docker
```

## Step 2

```bash
chmod +x scripts/*.sh
```

## Step 3

```bash
docker compose config
```

## Step 4

Stop existing containers:

```bash
docker compose down --remove-orphans
```

## Step 5

Reset:

```bash
./scripts/reset.sh
```

Enter:

```text
DELETE
```

## Step 6

Check Docker:

```bash
docker --version
```

## Step 7

Check Compose:

```bash
docker compose version
```

## Step 8

Create source directory:

```bash
mkdir -p src
```

## Step 9

Build from scratch:

```bash
docker compose build --no-cache
```

## Step 10

Install Magento:

```bash
./scripts/install-magento.sh
```

## Step 11

Check containers:

```bash
docker compose ps
```

## Step 12

Run health check:

```bash
./scripts/health-check.sh
```

## Step 13

Open Store:

```text
http://localhost:8080
```

## Step 14

Open direct Nginx:

```text
http://localhost:8081
```

## Step 15

Open Admin:

```text
http://localhost:8080/admin
```

---

# 38. One-Command Rebuild

For future development, the complete reset/rebuild sequence is:

```bash
docker compose down --volumes --remove-orphans
```

```bash
rm -rf src/*
```

```bash
mkdir -p src
```

```bash
docker compose config
```

```bash
docker compose build --no-cache
```

```bash
./scripts/install-magento.sh
```

```bash
./scripts/health-check.sh
```

---

# 39. Check All Ports

Check Docker port mappings:

```bash
docker compose ps
```

Expected:

```text
8080 -> Varnish
8081 -> Nginx
9200 -> OpenSearch
```

Check OpenSearch:

```bash
curl http://localhost:9200
```

Check Nginx:

```bash
curl -I http://localhost:8081
```

Check Varnish:

```bash
curl -I http://localhost:8080
```

---

# 40. Troubleshooting

## Problem: Container keeps restarting

Check:

```bash
docker compose ps
```

Then:

```bash
docker compose logs --tail=200 <service>
```

For example:

```bash
docker compose logs --tail=200 nginx
```

---

## Problem: Magento PHP container fails

Check:

```bash
docker compose logs --tail=200 php
```

Enter container:

```bash
docker compose exec php bash
```

Check:

```bash
php -v
```

```bash
composer --version
```

```bash
ls -la
```

Exit:

```bash
exit
```

---

# 41. OpenSearch Troubleshooting

Check:

```bash
docker compose ps opensearch
```

Logs:

```bash
docker compose logs --tail=200 opensearch
```

Check:

```bash
curl http://localhost:9200
```

Check health:

```bash
curl http://localhost:9200/_cluster/health
```

If OpenSearch is not ready, wait and retry.

For a single-node development environment, eventually expect:

```text
green
```

---

# 42. Valkey Troubleshooting

Check:

```bash
docker compose ps redis
```

Run:

```bash
docker compose exec redis valkey-cli ping
```

Expected:

```text
PONG
```

Logs:

```bash
docker compose logs --tail=200 redis
```

---

# 43. MariaDB Troubleshooting

Check:

```bash
docker compose ps db
```

Run:

```bash
docker compose exec db \
mariadb-admin ping \
-h 127.0.0.1 \
-u root \
-p"${MYSQL_ROOT_PASSWORD}"
```

Logs:

```bash
docker compose logs --tail=200 db
```

---

# 44. Nginx Troubleshooting

Check:

```bash
docker compose logs --tail=200 nginx
```

Test:

```bash
curl -I http://localhost:8081
```

Check Nginx configuration:

```bash
docker compose exec nginx nginx -t
```

Expected:

```text
syntax is ok
test is successful
```

---

# 45. Varnish Troubleshooting

Check:

```bash
docker compose logs --tail=200 varnish
```

Test:

```bash
curl -I http://localhost:8080
```

Check Varnish configuration:

```bash
docker compose exec varnish ls -la /etc/varnish/
```

---

# 46. Magento Permission Troubleshooting

Inside PHP:

```bash
docker compose exec php bash
```

Check:

```bash
ls -ld var generated pub/static pub/media app/etc
```

Magento permissions can be repaired with:

```bash
chown -R www-data:www-data var generated pub/static pub/media app/etc
```

Then:

```bash
chmod -R u+rwX,g+rwX var generated pub/static pub/media app/etc
```

Exit:

```bash
exit
```

---

# 47. Check Magento Application Files

```bash
docker compose exec php ls -la
```

Check:

```bash
docker compose exec php ls -la bin/
```

Magento CLI should exist:

```text
bin/magento
```

Test:

```bash
docker compose exec php php bin/magento --version
```

---

# 48. Check Magento Installation

```bash
docker compose exec php \
php bin/magento setup:db:status
```

Check modules:

```bash
docker compose exec php \
php bin/magento module:status
```

Check mode:

```bash
docker compose exec php \
php bin/magento deploy:mode:show
```

---

# 49. Useful Daily Commands

### Start

```bash
./scripts/start.sh
```

### Stop

```bash
./scripts/stop.sh
```

### Restart

```bash
./scripts/restart.sh
```

### Logs

```bash
./scripts/logs.sh
```

### Health

```bash
./scripts/health-check.sh
```

### Magento CLI

```bash
docker compose exec php php bin/magento
```

### Magento version

```bash
docker compose exec php php bin/magento --version
```

### Cache flush

```bash
docker compose exec php php bin/magento cache:flush
```

### Reindex

```bash
docker compose exec php php bin/magento indexer:reindex
```

---

# 50. Complete Validation Checklist

Run:

```bash
docker compose config
```

```bash
docker compose ps
```

```bash
docker compose exec db mariadb-admin ping -h 127.0.0.1 -u root -p"${MYSQL_ROOT_PASSWORD}" --silent
```

```bash
docker compose exec redis valkey-cli ping
```

```bash
curl http://localhost:9200
```

```bash
curl http://localhost:9200/_cluster/health
```

```bash
docker compose exec php php -v
```

```bash
docker compose exec php composer --version
```

```bash
docker compose exec php php bin/magento --version
```

```bash
curl -I http://localhost:8081
```

```bash
curl -I http://localhost:8080
```

Finally:

```bash
./scripts/health-check.sh
```

---

# 51. Expected Final Environment

When everything is working:

```text
                    +----------------+
                    |    Browser     |
                    +-------+--------+
                            |
                    localhost:8080
                            |
                    +-------v--------+
                    |    Varnish     |
                    +-------+--------+
                            |
                    +-------v--------+
                    |     nginx      |
                    +-------+--------+
                            |
                    +-------v--------+
                    |    PHP-FPM     |
                    |    Magento     |
                    +---+----+----+--+
                        |    |    |
              +---------+    |    +----------+
              |              |               |
        +-----v-----+  +-----v-----+  +------v------+
        |  MariaDB  |  |  Valkey   |  | OpenSearch  |
        |   :3306   |  |   :6379   |  |    :9200    |
        +-----------+  +-----------+  +-------------+
```

---

# 52. Final URLs

| Purpose       | URL                           |
| ------------- | ----------------------------- |
| Magento Store | `http://localhost:8080`       |
| Magento Admin | `http://localhost:8080/admin` |
| Direct Nginx  | `http://localhost:8081`       |
| OpenSearch    | `http://localhost:9200`       |

---

# 53. Recommended First-Time Workflow

Use exactly this order:

```bash
cd magento2-docker
```

```bash
chmod +x scripts/*.sh
```

```bash
cp .env.example .env
```

Edit:

```bash
nano .env
```

Validate:

```bash
docker compose config
```

Create source directory:

```bash
mkdir -p src
```

Clean previous installation if one exists:

```bash
docker compose down --volumes --remove-orphans
```

If required:

```bash
./scripts/reset.sh
```

Then rebuild:

```bash
docker compose build --no-cache
```

Install:

```bash
./scripts/install-magento.sh
```

Check:

```bash
docker compose ps
```

Run:

```bash
./scripts/health-check.sh
```

Then open:

```text
http://localhost:8080
```

Admin:

```text
http://localhost:8080/admin
```

---

# 54. Important Safety Notes

Do **not** run:

```bash
docker system prune -a --volumes
```

unless you intentionally want to remove unrelated Docker resources from your machine.

For this project, prefer:

```bash
docker compose down --volumes --remove-orphans
```

This limits cleanup to the Compose project.

Also never commit:

```text
.env
auth.json
Composer credentials
database passwords
admin passwords
private keys
```

Use:

```bash
.gitignore
```

to exclude sensitive files.

---

# 55. Final Health Check

The project is considered ready when all of these succeed:

```bash
docker compose config
```

```bash
docker compose ps
```

```bash
docker compose exec db mariadb-admin ping -h 127.0.0.1 -u root -p"${MYSQL_ROOT_PASSWORD}" --silent
```

```bash
docker compose exec redis valkey-cli ping
```

```bash
curl http://localhost:9200/_cluster/health
```

```bash
docker compose exec php php bin/magento --version
```

```bash
curl -I http://localhost:8081
```

```bash
curl -I http://localhost:8080
```

```bash
./scripts/health-check.sh
```

Expected Magento version:

```text
Magento CLI 2.4.8-p5
```

Expected Valkey:

```text
PONG
```

Expected OpenSearch:

```text
green
```

Expected web endpoints:

```text
http://localhost:8080  -> PASS
http://localhost:8081  -> PASS
```

---

## Quick Reference

```bash
# Start
./scripts/start.sh

# Stop
./scripts/stop.sh

# Restart
./scripts/restart.sh

# Logs
./scripts/logs.sh

# Health
./scripts/health-check.sh

# Full reset
./scripts/reset.sh

# Validate Compose
docker compose config

# Rebuild
docker compose build --no-cache

# Install
./scripts/install-magento.sh

# Containers
docker compose ps

# Magento version
docker compose exec php php bin/magento --version

# Cache
docker compose exec php php bin/magento cache:flush

# Reindex
docker compose exec php php bin/magento indexer:reindex

# OpenSearch
curl http://localhost:9200/_cluster/health

# Valkey
docker compose exec redis valkey-cli ping

# MariaDB
docker compose exec db mariadb-admin ping -h 127.0.0.1 -u root -p"${MYSQL_ROOT_PASSWORD}" --silent

# Store
http://localhost:8080

# Admin
http://localhost:8080/admin

# Nginx
http://localhost:8081
```

**End of README**
