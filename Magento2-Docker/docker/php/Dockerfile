FROM php:8.4-fpm-bookworm

# ==========================================================
# Composer
# ==========================================================

COPY --from=composer:2.10 /usr/bin/composer /usr/bin/composer

ENV DEBIAN_FRONTEND=noninteractive

# ==========================================================
# SYSTEM PACKAGES
# ==========================================================

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        unzip \
        zip \
        wget \
        procps \
        default-mysql-client \
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
        libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# ==========================================================
# GD
# ==========================================================

RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp

# ==========================================================
# PHP EXTENSIONS
# ==========================================================

RUN docker-php-ext-install -j"$(nproc)" \
        bcmath \
        ctype \
        curl \
        dom \
        fileinfo \
        gd \
        intl \
        mbstring \
        mysqli \
        opcache \
        pcntl \
        pdo_mysql \
        soap \
        sockets \
        sodium \
        xsl \
        zip

# ==========================================================
# Redis / Valkey PHP Extension
# ==========================================================

RUN pecl install redis \
    && docker-php-ext-enable redis

# ==========================================================
# PHP CONFIGURATION
# ==========================================================

COPY php.ini \
    /usr/local/etc/php/conf.d/zz-magento.ini

COPY opcache.ini \
    /usr/local/etc/php/conf.d/zz-opcache.ini

COPY www.conf \
    /usr/local/etc/php-fpm.d/www.conf

# ==========================================================
# APPLICATION DIRECTORY
# ==========================================================

WORKDIR /var/www/html

RUN mkdir -p \
        /var/www/html/generated \
        /var/www/html/var \
        /var/www/html/pub/static \
        /var/www/html/pub/media \
        /var/www/html/app/etc \
    && chown -R www-data:www-data /var/www/html

# ==========================================================
# PHP-FPM
# ==========================================================

EXPOSE 9000

CMD ["php-fpm", "-F"]
