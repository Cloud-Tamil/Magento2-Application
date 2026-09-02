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
}'
