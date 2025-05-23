# ────────────────────────────────
#  Production image
# ────────────────────────────────
FROM php:8.2-apache AS prod

ENV APP_DIR=/var/munkireport \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp \
    PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d

# ---------- OS packages + PHP extensions ----------
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        libldap2-dev libcurl4-openssl-dev libzip-dev zlib1g-dev libxml2-dev \
        unzip default-mysql-client openssh-server && \
    rm -rf /var/lib/apt/lists/*

# ---------- trust system CA for mysqlnd & mysqli ---
RUN printf '%s\n' \
      '[mysqlnd]' \
      'mysqlnd.ssl_ca = /etc/ssl/certs/ca-certificates.crt' \
      '' \
      '[mysqli]' \
      'mysqli.ssl_ca  = /etc/ssl/certs/ca-certificates.crt' \
    > /usr/local/etc/php/conf.d/10-mysql-ca.ini

# ---------- build PHP extensions -------------------
RUN docker-php-ext-configure ldap && \
    docker-php-ext-install -j"$(nproc)" curl pdo_mysql mysqli soap ldap zip

# ---------- php.ini & sane error levels ------------
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    printf '%s\n' \
      '[runtime]' \
      "upload_max_filesize    = 50M" \
      "post_max_size          = 50M" \
      'display_errors         = Off' \
      'display_startup_errors = Off' \
      'html_errors            = Off' \
      'log_errors             = On' \
      'error_reporting        = E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED & ~E_WARNING' \
    > /usr/local/etc/php/conf.d/99-sane-errors.ini

# ---------- application code -----------------------
WORKDIR ${APP_DIR}
COPY . ${APP_DIR}
RUN rm -f .env .env.local                # runtime ENV wins

# Composer (prod)
COPY --from=composer:2.2.6 /usr/bin/composer /usr/local/bin/composer
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction
RUN rm -f vendor/composer/autoload_files.php && composer dumpautoload -o

# writable dirs & purge stale caches
RUN mkdir -p app/db && chmod -R 777 app/db && \
    rm -f bootstrap/cache/config.php bootstrap/cache/routes.php

# Apache doc-root & hardening
RUN rm -rf /var/www/html && ln -s /var/munkireport/public /var/www/html && \
    sed -i 's/ServerTokens OS/ServerTokens Prod/'  /etc/apache2/conf-available/security.conf && \
    sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf && \
    echo 'ServerName localhost' >> /etc/apache2/apache2.conf && \
    a2enmod rewrite && \
    sed -i 's|^\s*CustomLog .* combined|CustomLog /proc/self/fd/1 combined|' \
        /etc/apache2/sites-available/000-default.conf

# pass CA-env vars from Apache → PHP
RUN printf '%s\n' \
    'PassEnv CONNECTION_SSL_CA' \
    'PassEnv MYSQL_ATTR_SSL_CA' \
    'PassEnv MYSQLI_CLIENT_SSL_CA' \
    'PassEnv PDO_MYSQL_ATTR_SSL_CA' \
    > /etc/apache2/conf-available/99-passenv.conf && \
    a2enconf 99-passenv

# SSH on port 2222
RUN ssh-keygen -A && \
    sed -i 's/^#Port .*/Port 2222/' /etc/ssh/sshd_config && \
    sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config

ARG ROOT_PASS
RUN echo "root:${ROOT_PASS:-Docker!}" | chpasswd

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 2222
ENTRYPOINT ["/entrypoint.sh"]
CMD []

# ────────────────────────────────
#  Development image  (build with: docker build --target dev …)
# ────────────────────────────────
FROM prod AS dev

ENV APP_ENV=local DEBUG=TRUE XDEBUG_MODE=develop,coverage

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        vim less netcat-openbsd iputils-ping build-essential autoconf pkg-config && \
    pecl install xdebug && docker-php-ext-enable xdebug && \
    rm -rf /var/lib/apt/lists/*