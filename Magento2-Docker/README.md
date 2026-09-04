# Magento 2.4.8-p5 Docker Environment

Production-style local development environment for **Magento Open Source 2.4.8-p5** using Docker Compose.

---

## Changelog / Fixes Applied

This version fixes three issues found in the original setup:

| # | File | Problem | Fix |
|---|------|---------|-----|
| 1 | `docker/php/Dockerfile` | `COPY` line for `www.conf` contained stray markdown link syntax (`[www.conf](https://www.conf)`), which is not valid Dockerfile syntax and breaks the build. | Changed to plain `COPY www.conf /usr/local/etc/php-fpm.d/www.conf`. |
| 2 | `docker-compose.yml` (nginx service) | Healthcheck used `curl`, but the stock `nginx:1.30` image does not ship curl. Nginx would never report healthy, and Varnish (which depends on nginx's health) would never start. | Added `docker/nginx/Dockerfile` (installs curl on top of `nginx:1.30`) and changed the `nginx` service to `build: ./docker/nginx` instead of `image: nginx:1.30`. |
| 3 | `scripts/health-check.sh` | HTTP status check used `[[ "$HTTP_CODE" =~ ^2|3 ]]`, which bash parses as "starts with 2, OR contains a 3 anywhere" — so a real failure like `503` incorrectly passed. | Changed to `[[ "$HTTP_CODE" =~ ^[23] ]]`. |

---

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
| nginx               | 1.30 (custom image, + curl) |
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
├── .gitignore
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
│   │   ├── Dockerfile
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

Key variables:

```env
MAGENTO_VERSION=2.4.8-p5
MAGENTO_BASE_URL=http://localhost:8080/

MYSQL_DATABASE=magento
MYSQL_USER=magento
MYSQL_PASSWORD=change_me
MYSQL_ROOT_PASSWORD=change_root_me

DB_HOST=db
DB_PORT=3306

REDIS_HOST=redis
REDIS_PORT=6379

OPENSEARCH_HOST=opensearch
OPENSEARCH_PORT=9200
OPENSEARCH_HTTP_PORT=9200

NGINX_PORT=8081
VARNISH_PORT=8080

MAGENTO_ADMIN_FIRSTNAME=Admin
MAGENTO_ADMIN_LASTNAME=User
MAGENTO_ADMIN_EMAIL=admin@example.com
MAGENTO_ADMIN_USER=admin
MAGENTO_ADMIN_PASSWORD=ChangeMe123!ChangeMe
MAGENTO_ADMIN_FRONTNAME=admin

COMPOSER_AUTH_PUBLIC_KEY=your_public_key
COMPOSER_AUTH_PRIVATE_KEY=your_private_key
```

> Do not commit `.env` if it contains real passwords or Composer credentials. `.gitignore` already excludes it.

Get Magento Marketplace Composer keys from:
`https://commercemarketplace.adobe.com/customer/accessKeys/`

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

fix the configuration (usually a missing `.env` variable) before continuing.

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

The installation script will:

1. Check Docker
2. Check environment / required variables
3. Create `src/`
4. Build the PHP image
5. Start MariaDB, Valkey, OpenSearch
6. Wait for MariaDB
7. Wait for Valkey
8. Wait for OpenSearch
9. Download Magento via Composer
10. Configure Composer authentication
11. Start PHP
12. Install Magento (`setup:install`)
13. Configure Magento (developer mode)
14. Configure Valkey cache/page-cache
15. Configure Valkey sessions
16. Run `setup:upgrade`
17. Compile Magento (`setup:di:compile`)
18. Deploy static content
19. Reindex Magento
20. Flush cache
21. Fix permissions
22. Start Nginx and Varnish
23. Print final URLs

---

# 9. Clean Rebuild

If you already have a broken or partially installed Magento environment, **do not simply run `docker compose up -d`**.

Use the clean rebuild procedure below.

## Step 1 — Stop Containers

```bash
docker compose down --remove-orphans
```

## Step 2 — Full Reset

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

The reset removes:

* Containers
* Networks
* Magento volumes
* Database data
* Valkey data
* OpenSearch data
* Existing Magento source in `src/`

> **Warning:** A full reset deletes local Magento database/index/cache data and source code. This cannot be undone.

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

Check nothing is left over:

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

This forces Docker to rebuild the PHP and Nginx images (both are custom-built) instead of using cached layers.

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

Per-service:

```bash
docker compose logs db
docker compose logs redis
docker compose logs opensearch
docker compose logs php
docker compose logs nginx
docker compose logs varnish
```

Follow logs live:

```bash
docker compose logs -f
```

Press `CTRL+C` to stop following.

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

Connect interactively:

```bash
docker compose exec db mariadb -u root -p"${MYSQL_ROOT_PASSWORD}"
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

```bash
docker compose exec redis valkey-cli ping
```

Expected:

```text
PONG
```

Check server info:

```bash
docker compose exec redis valkey-cli info server
```

Check keys in a specific DB (0 = cache, 1 = page cache, 2 = sessions):

```bash
docker compose exec redis valkey-cli -n 0 dbsize
docker compose exec redis valkey-cli -n 1 dbsize
docker compose exec redis valkey-cli -n 2 dbsize
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

Readable JSON:

```bash
curl -s http://localhost:9200/_cluster/health | python3 -m json.tool
```

Expected status for the single-node dev environment:

```json
{
    "status": "green"
}
```

Nodes:

```bash
curl http://localhost:9200/_cat/nodes?v
```

Indices:

```bash
curl http://localhost:9200/_cat/indices?v
```

---

# 18. Verify PHP

```bash
docker compose exec php php -v
```

Expected:

```text
PHP 8.4.x
```

Loaded modules:

```bash
docker compose exec php php -m
```

PHP configuration:

```bash
docker compose exec php php --ini
```

Confirm the redis extension loaded:

```bash
docker compose exec php php -m | grep -i redis
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

```bash
docker compose exec php php bin/magento --version
```

Expected:

```text
Magento CLI 2.4.8-p5
```

Module status:

```bash
docker compose exec php php bin/magento module:status
```

Deploy mode:

```bash
docker compose exec php php bin/magento deploy:mode:show
```

---

# 21. Verify Magento Configuration

Base URL:

```bash
docker compose exec php php bin/magento config:show web/unsecure/base_url
```

Expected:

```text
http://localhost:8080/
```

Secure base URL (HTTP-only local environment, so it matches unsecure):

```bash
docker compose exec php php bin/magento config:show web/secure/base_url
```

---

# 22. Verify Nginx

Nginx is exposed directly on:

```text
http://localhost:8081
```

Test with curl (curl is now baked into the custom Nginx image):

```bash
curl -I http://localhost:8081
```

Expected:

```text
HTTP/1.1 200 OK
```

A redirect can also be normal depending on Magento's configured base URL.

Check the dedicated health endpoint used by `health-check.sh`:

```bash
curl -I http://localhost:8081/health-check
```

Expected:

```text
HTTP/1.1 200 OK
OK
```

Test the Nginx config syntax inside the container:

```bash
docker compose exec nginx nginx -t
```

Expected:

```text
syntax is ok
test is successful
```

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

Look for cache-related headers:

```text
Via:
X-Magento-Cache-Debug:
Age:
```

Check the Varnish admin ping (used by its healthcheck):

```bash
docker compose exec varnish varnishadm ping
```

---

# 24. Open Magento Store

Open in your browser:

```text
http://localhost:8080
```

Request path:

```text
Browser -> Varnish (:8080) -> Nginx -> PHP-FPM -> MariaDB / Valkey / OpenSearch
```

---

# 25. Open Magento Admin

Default admin URL:

```text
http://localhost:8080/admin
```

If you set a custom `MAGENTO_ADMIN_FRONTNAME`, use that instead of `admin`.

Login:

```text
Username: value of MAGENTO_ADMIN_USER
Password: value of MAGENTO_ADMIN_PASSWORD
```

---

# 26. Find Magento Admin URL

If you're not sure about the admin frontname:

```bash
docker compose exec php php bin/magento info:adminuri
```

Example output:

```text
Admin URI: /admin
```

---

# 27. Magento Cache

Check cache status:

```bash
docker compose exec php php bin/magento cache:status
```

Flush all cache (clears storage completely):

```bash
docker compose exec php php bin/magento cache:flush
```

Clean cache (invalidates, keeps storage):

```bash
docker compose exec php php bin/magento cache:clean
```

Enable/disable specific cache types:

```bash
docker compose exec php php bin/magento cache:enable full_page
docker compose exec php php bin/magento cache:disable full_page
```

---

# 28. Magento Indexers

Check indexer status:

```bash
docker compose exec php php bin/magento indexer:status
```

Reindex everything:

```bash
docker compose exec php php bin/magento indexer:reindex
```

Reindex a single indexer:

```bash
docker compose exec php php bin/magento indexer:reindex catalog_product_price
```

Reset indexers (forces full reindex on next run):

```bash
docker compose exec php php bin/magento indexer:reset
```

Switch to schedule (cron) mode:

```bash
docker compose exec php php bin/magento indexer:set-mode schedule
```

---

# 29. Magento Upgrade Commands

After pulling code changes or installing a module:

```bash
docker compose exec php php bin/magento setup:upgrade
docker compose exec php php bin/magento setup:di:compile
docker compose exec php php bin/magento setup:static-content:deploy -f
docker compose exec php php bin/magento indexer:reindex
docker compose exec php php bin/magento cache:flush
```

---

# 30. Configure Magento Script

```bash
./scripts/configure-magento.sh
```

This runs `setup:upgrade`, `setup:di:compile`, static content deploy, reindex, cache flush, fixes permissions, and restarts Nginx/Varnish.

---

# 31. Generate Varnish Configuration

```bash
./scripts/generate-varnish.sh
```

This uses Magento's own `varnish:vcl:generate` command, saves it to `docker/varnish/generated.vcl`, copies it over `docker/varnish/default.vcl`, and restarts Varnish.

Verify the generated configuration:

```bash
cat docker/varnish/default.vcl
```

Validate VCL from inside the container:

```bash
docker compose exec varnish varnishd -C -f /etc/varnish/default.vcl
```

Inspect the Varnish config directory:

```bash
docker compose exec varnish ls -la /etc/varnish/
```

---

# 32. Restart Everything

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

```bash
./scripts/stop.sh
```

Or:

```bash
docker compose stop
```

This stops containers but preserves them (and named volumes) so `start.sh` can bring them back quickly.

To fully remove containers (keeping volumes):

```bash
docker compose down
```

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

```bash
./scripts/logs.sh
```

All services follow-mode:

```bash
docker compose logs -f
```

Single service:

```bash
./scripts/logs.sh php
./scripts/logs.sh nginx
./scripts/logs.sh db
./scripts/logs.sh redis
./scripts/logs.sh opensearch
./scripts/logs.sh varnish
```

Or directly:

```bash
docker compose logs -f php
docker compose logs -f nginx
docker compose logs -f db
docker compose logs -f redis
docker compose logs -f opensearch
docker compose logs -f varnish
```

---

# 36. Automated Health Check

```bash
./scripts/health-check.sh
```

Expected:

```text
==================================================
 Magento Docker Health Check
==================================================

[1] Containers
magento-db          Up
magento-redis       Up
magento-opensearch  Up
magento-php         Up
magento-nginx       Up
magento-varnish     Up

[2] MariaDB
PASS: MariaDB

[3] Valkey
PASS: Valkey

[4] OpenSearch
PASS: OpenSearch

[5] PHP
PASS: PHP

[6] Magento
Magento CLI 2.4.8-p5
PASS: Magento

[7] Nginx
PASS: Nginx

[8] Varnish
PASS: Varnish

[9] Magento Store
PASS: Magento Store HTTP 200

==================================================
 Result
==================================================
PASS: 9
FAIL: 0

All health checks PASSED.
```

The script exits with code `1` if any check fails, so it's safe to use in CI.

---

# 37. Complete Clean Installation

For a completely fresh installation, use this exact sequence.

```bash
# Step 1
cd magento2-docker

# Step 2
chmod +x scripts/*.sh

# Step 3
docker compose config

# Step 4 — stop existing containers
docker compose down --remove-orphans

# Step 5 — reset (type DELETE when prompted)
./scripts/reset.sh

# Step 6 — sanity checks
docker --version
docker compose version

# Step 7 — create source directory
mkdir -p src

# Step 8 — build from scratch
docker compose build --no-cache

# Step 9 — install
./scripts/install-magento.sh

# Step 10 — verify
docker compose ps
./scripts/health-check.sh
```

Then open:

```text
Store: http://localhost:8080
Admin: http://localhost:8080/admin
Nginx: http://localhost:8081
```

---

# 38. One-Command Rebuild

For future development, the complete reset/rebuild sequence is:

```bash
docker compose down --volumes --remove-orphans
rm -rf src/*
mkdir -p src
docker compose config
docker compose build --no-cache
./scripts/install-magento.sh
./scripts/health-check.sh
```

---

# 39. Check All Ports

```bash
docker compose ps
```

Expected:

```text
8080 -> Varnish
8081 -> Nginx
9200 -> OpenSearch
```

```bash
curl http://localhost:9200
curl -I http://localhost:8081
curl -I http://localhost:8080
```

---

# 40. Troubleshooting — General

## Problem: Container keeps restarting

```bash
docker compose ps
docker compose logs --tail=200 <service>
```

Example:

```bash
docker compose logs --tail=200 nginx
```

## Problem: PHP container fails

```bash
docker compose logs --tail=200 php
docker compose exec php bash
php -v
composer --version
ls -la
exit
```

## Problem: Nginx never becomes "healthy" / Varnish never starts

This was the original bug in this project (see Changelog #2). Confirm the fix is in place:

```bash
grep -A2 "nginx:" docker-compose.yml | grep build
```

Should show `build: ./docker/nginx`, not `image: nginx:1.30`. Then rebuild:

```bash
docker compose build --no-cache nginx
docker compose up -d nginx
docker compose ps
```

Confirm curl now exists in the nginx container:

```bash
docker compose exec nginx curl --version
```

---

# 41. OpenSearch Troubleshooting

```bash
docker compose ps opensearch
docker compose logs --tail=200 opensearch
curl http://localhost:9200
curl http://localhost:9200/_cluster/health
```

If OpenSearch is not ready, wait and retry — for a single-node dev environment, expect `green` once startup finishes (can take 30–60s on first boot).

Common cause of a crash-looping OpenSearch container: insufficient `vm.max_map_count` on the Docker host. Fix (Linux host):

```bash
sudo sysctl -w vm.max_map_count=262144
```

---

# 42. Valkey Troubleshooting

```bash
docker compose ps redis
docker compose exec redis valkey-cli ping
docker compose logs --tail=200 redis
```

Expected:

```text
PONG
```

---

# 43. MariaDB Troubleshooting

```bash
docker compose ps db
docker compose exec db mariadb-admin ping -h 127.0.0.1 -u root -p"${MYSQL_ROOT_PASSWORD}"
docker compose logs --tail=200 db
```

If MariaDB won't start after a bad shutdown, and you're OK losing local data:

```bash
docker compose down
docker volume rm magento2-docker_db_data
docker compose up -d db
```

---

# 44. Nginx Troubleshooting

```bash
docker compose logs --tail=200 nginx
curl -I http://localhost:8081
docker compose exec nginx nginx -t
```

Expected:

```text
syntax is ok
test is successful
```

If you edit `docker/nginx/default.conf`, reload without a full restart:

```bash
docker compose exec nginx nginx -s reload
```

---

# 45. Varnish Troubleshooting

```bash
docker compose logs --tail=200 varnish
curl -I http://localhost:8080
docker compose exec varnish ls -la /etc/varnish/
```

Reload VCL after editing `docker/varnish/default.vcl` without downtime:

```bash
./scripts/generate-varnish.sh
```

or manually:

```bash
docker compose restart varnish
```

---

# 46. Magento Permission Troubleshooting

```bash
docker compose exec php bash
ls -ld var generated pub/static pub/media app/etc
```

Repair permissions:

```bash
chown -R www-data:www-data var generated pub/static pub/media app/etc
chmod -R u+rwX,g+rwX var generated pub/static pub/media app/etc
exit
```

Or from the host in one shot:

```bash
docker compose exec -T php chown -R www-data:www-data var generated pub/static pub/media app/etc
docker compose exec -T php chmod -R ug+rwX var generated pub/static pub/media app/etc
```

---

# 47. Check Magento Application Files

```bash
docker compose exec php ls -la
docker compose exec php ls -la bin/
docker compose exec php php bin/magento --version
```

`bin/magento` should exist and be executable.

---

# 48. Check Magento Installation

```bash
docker compose exec php php bin/magento setup:db:status
docker compose exec php php bin/magento module:status
docker compose exec php php bin/magento deploy:mode:show
```

---

# 49. Useful Daily Commands

### Start / Stop / Restart

```bash
./scripts/start.sh
./scripts/stop.sh
./scripts/restart.sh
```

### Logs / Health

```bash
./scripts/logs.sh
./scripts/health-check.sh
```

### Magento CLI

```bash
docker compose exec php php bin/magento
docker compose exec php php bin/magento --version
docker compose exec php php bin/magento cache:flush
docker compose exec php php bin/magento indexer:reindex
```

### Enter a shell in any container

```bash
docker compose exec php bash
docker compose exec nginx bash
docker compose exec db bash
docker compose exec redis sh
docker compose exec opensearch bash
docker compose exec varnish bash
```

### Composer inside the PHP container

```bash
docker compose exec php composer install
docker compose exec php composer update
docker compose exec php composer require <vendor/package>
```

### Create an additional admin user

```bash
docker compose exec php php bin/magento admin:user:create \
  --admin-user="newadmin" \
  --admin-password="Password123!" \
  --admin-email="newadmin@example.com" \
  --admin-firstname="New" \
  --admin-lastname="Admin"
```

### Enable Magento's built-in cron

```bash
docker compose exec php php bin/magento cron:install
```

### Switch deploy mode

```bash
docker compose exec php php bin/magento deploy:mode:set developer
docker compose exec php php bin/magento deploy:mode:set production
```

> Production mode requires a full `setup:di:compile` and `setup:static-content:deploy` beforehand.

---

# 50. Complete Validation Checklist

Run each of these in order — all should succeed before you consider the environment "ready":

```bash
docker compose config
docker compose ps
docker compose exec db mariadb-admin ping -h 127.0.0.1 -u root -p"${MYSQL_ROOT_PASSWORD}" --silent
docker compose exec redis valkey-cli ping
curl http://localhost:9200
curl http://localhost:9200/_cluster/health
docker compose exec php php -v
docker compose exec php composer --version
docker compose exec php php bin/magento --version
curl -I http://localhost:8081
curl -I http://localhost:8080
./scripts/health-check.sh
```

---

# 51. Expected Final Environment

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
                    |   (+ curl)     |
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
| ------------- | ------------------------------ |
| Magento Store | `http://localhost:8080`       |
| Magento Admin | `http://localhost:8080/admin` |
| Direct Nginx  | `http://localhost:8081`       |
| Nginx health  | `http://localhost:8081/health-check` |
| OpenSearch    | `http://localhost:9200`       |

---

# 53. Recommended First-Time Workflow

```bash
cd magento2-docker
chmod +x scripts/*.sh
cp .env.example .env
nano .env                                    # fill in Composer keys, passwords
docker compose config                        # validate
mkdir -p src
docker compose down --volumes --remove-orphans   # only if re-running
./scripts/reset.sh                           # only if a previous install exists
docker compose build --no-cache
./scripts/install-magento.sh
docker compose ps
./scripts/health-check.sh
```

Then open:

```text
Store: http://localhost:8080
Admin: http://localhost:8080/admin
```

---

# 54. Important Safety Notes

Do **not** run:

```bash
docker system prune -a --volumes
```

unless you intentionally want to remove unrelated Docker resources from your machine.

For this project, prefer the scoped cleanup:

```bash
docker compose down --volumes --remove-orphans
```

Never commit:

```text
.env
auth.json
Composer credentials
database passwords
admin passwords
private keys
```

`.gitignore` already excludes these — don't remove those entries.

---

# 55. Final Health Check

The project is considered ready when all of these succeed:

```bash
docker compose config
docker compose ps
docker compose exec db mariadb-admin ping -h 127.0.0.1 -u root -p"${MYSQL_ROOT_PASSWORD}" --silent
docker compose exec redis valkey-cli ping
curl http://localhost:9200/_cluster/health
docker compose exec php php bin/magento --version
curl -I http://localhost:8081
curl -I http://localhost:8080
./scripts/health-check.sh
```

Expected results:

```text
Magento version : Magento CLI 2.4.8-p5
Valkey          : PONG
OpenSearch      : green
Nginx (:8081)   : PASS
Varnish (:8080) : PASS
```

---

## Quick Reference

```bash
# Start / stop / restart
./scripts/start.sh
./scripts/stop.sh
./scripts/restart.sh

# Logs / health
./scripts/logs.sh
./scripts/health-check.sh

# Full reset (destroys data — type DELETE to confirm)
./scripts/reset.sh

# Validate compose file
docker compose config

# Rebuild images from scratch
docker compose build --no-cache

# Fresh install
./scripts/install-magento.sh

# Reconfigure after code changes
./scripts/configure-magento.sh

# Regenerate Varnish VCL from Magento
./scripts/generate-varnish.sh

# Containers
docker compose ps

# Magento version
docker compose exec php php bin/magento --version

# Cache
docker compose exec php php bin/magento cache:flush

# Reindex
docker compose exec php php bin/magento indexer:reindex

# OpenSearch health
curl http://localhost:9200/_cluster/health

# Valkey ping
docker compose exec redis valkey-cli ping

# MariaDB ping
docker compose exec db mariadb-admin ping -h 127.0.0.1 -u root -p"${MYSQL_ROOT_PASSWORD}" --silent

# URLs
# Store: http://localhost:8080
# Admin: http://localhost:8080/admin
# Nginx: http://localhost:8081
```

**End of README**
