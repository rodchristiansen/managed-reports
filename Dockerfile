# ─────────────────────────────────────────────────────────
#  Production image
# ─────────────────────────────────────────────────────────
FROM php:8.2-apache AS prod

ENV APP_DIR=/var/munkireport \
    SITENAME="ManagedReport" \
    MODULES="ard, bluetooth, disk_report, munkireport, managedinstalls, munkiinfo, network, security, warranty" \
    INDEX_PAGE="" \
    AUTH_METHODS="NOAUTH" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp

# ── OS packages + PHP extensions ─────────────────────────
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        libldap2-dev \
        libcurl4-openssl-dev \
        libzip-dev \
        unzip \
        zlib1g-dev \
        libxml2-dev \
        openssh-server \
        default-mysql-client && \
    rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure ldap && \
    docker-php-ext-install -j"$(nproc)" \
        curl pdo_mysql mysqli soap ldap zip

# ── PHP: force mysqlnd to use the system CA ──────────────────────────
RUN printf '%s\n' \
      '[mysqlnd]' \
      'mysqlnd.ssl_ca = /etc/ssl/certs/ca-certificates.crt' \
    > /usr/local/etc/php/conf.d/99-mysql-ssl.ini

# ── Upload limits + silence PHP-8 deprecations ───────────
RUN printf '%s\n' \
      "upload_max_filesize = 50M" \
      "post_max_size      = 50M" \
      "error_reporting    = E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED & ~E_WARNING" \
      "display_errors     = Off" \
      "log_errors         = On" \
    > /usr/local/etc/php/conf.d/00-runtime.ini

# ── Application code ─────────────────────────────────────
WORKDIR ${APP_DIR}
COPY . ${APP_DIR}

# REMOVE ANY STATIC .env SO RUNTIME ENV VARS TAKE EFFECT
RUN rm -f .env .env.local

# Composer (dependencies)
COPY --from=composer:2.2.6 /usr/bin/composer /usr/local/bin/composer
RUN composer install --no-dev && composer dumpautoload -o

# Writable DB directory (if you ever switch to sqlite)
RUN mkdir -p app/db && chmod -R 777 app/db

# ── make sure no stale cached config ships in the image ──────────
RUN rm -f bootstrap/cache/config.php bootstrap/cache/routes.php

# Apache doc-root
RUN rm -rf /var/www/html && ln -s /var/munkireport/public /var/www/html

# Harden Apache
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/'  /etc/apache2/conf-available/security.conf && \
    sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    a2enmod rewrite && \
    # log to stdout
    sed -i 's|^CustomLog .* combined|CustomLog /proc/self/fd/1 combined|' \
        /etc/apache2/sites-available/000-default.conf

# Pass the four CA-related env-vars through Apache to PHP
RUN printf '%s\n' \
    'PassEnv CONNECTION_SSL_CA' \
    'PassEnv MYSQL_ATTR_SSL_CA' \
    'PassEnv MYSQLI_CLIENT_SSL_CA' \
    'PassEnv PDO_MYSQL_ATTR_SSL_CA' \
    >> /etc/apache2/conf-available/99-passenv.conf \
 && a2enconf 99-passenv

# ── SSH setup ────────────────────────────────────────────
RUN ssh-keygen -A && \
    sed -i 's|^#Port .*|Port 2222|' /etc/ssh/sshd_config && \
    sed -i 's|^#PermitRootLogin .*|PermitRootLogin yes|' /etc/ssh/sshd_config && \
    sed -i 's|^#PubkeyAuthentication .*|PubkeyAuthentication yes|' /etc/ssh/sshd_config && \
    sed -i 's|^#PasswordAuthentication .*|PasswordAuthentication yes|' /etc/ssh/sshd_config && \
    sed -i 's|^#UsePAM .*|UsePAM yes|' /etc/ssh/sshd_config
ARG ROOT_PASS
RUN echo "root:${ROOT_PASS:-Docker!}" | chpasswd

# ── Entrypoint ───────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 2222
ENTRYPOINT ["/entrypoint.sh"]
CMD []

# ─────────────────────────────────────────────────────────
#  Dev image (optional build target "dev")
# ─────────────────────────────────────────────────────────
FROM prod AS dev

ENV APP_ENV=local DEBUG=TRUE XDEBUG_MODE=develop,coverage

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        vim less netcat-openbsd iputils-ping build-essential autoconf pkg-config && \
    pecl install xdebug && docker-php-ext-enable xdebug && \
    rm -rf /var/lib/apt/lists/*
