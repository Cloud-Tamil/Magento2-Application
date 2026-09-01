FROM php:8.4-fpm-bookworm

ARG COMPOSER_VERSION=2.10

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

WORKDIR /var/www/html


# ==========================================================
# SYSTEM PACKAGES
# ==========================================================

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    zip \
    curl \
    wget \
    ca-certificates \
    libicu-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libzip-dev \
    libxml2-dev \
    libxslt1-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    default-mysql-client \
    procps \
    netcat-openbsd \
    gosu \
    && rm -rf /var/lib/apt/lists/*


# ==========================================================
# PHP EXTENSIONS
# ==========================================================

RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        calendar \
        exif \
        ftp \
        gd \
        intl \
        mysqli \
        opcache \
        pcntl \
        pdo_mysql \
        soap \
        sockets \
        xsl \
        zip


# ==========================================================
# REDIS/VALKEY PHP EXTENSION
# ==========================================================

RUN pecl install redis \
    && docker-php-ext-enable redis


# ==========================================================
# COMPOSER
# ==========================================================

COPY --from=composer:2.10 /usr/bin/composer /usr/bin/composer


# ==========================================================
# PHP CONFIG
# ==========================================================

COPY docker/php/php.ini \
    /usr/local/etc/php/conf.d/magento.ini


# ==========================================================
# ENTRYPOINT
# ==========================================================

COPY docker/php/entrypoint.sh \
    /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh


# ==========================================================
# DIRECTORY
# ==========================================================

RUN mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html


ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm", "-F"]
