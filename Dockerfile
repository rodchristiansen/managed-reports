FROM php:8.2-apache

# Define the application directory
ENV APP_DIR=/var/munkireport

# Install OS packages and PHP extensions required by MunkiReport
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      libldap2-dev \
      libcurl4-openssl-dev \
      libzip-dev \
      unzip \
      zlib1g-dev \
      libxml2-dev && \
    rm -rf /var/lib/apt/lists/*

# Configure & install PHP extensions
RUN docker-php-ext-configure ldap && \
    docker-php-ext-install -j"$(nproc)" curl pdo_mysql soap ldap zip

# Create a custom .ini file to increase PHP upload limits
RUN echo "upload_max_filesize = 50M\npost_max_size = 50M" > /usr/local/etc/php/conf.d/uploads.ini

# Set Composer environment variables
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_HOME=/tmp

# MunkiReport-specific environment variables
ENV SITENAME="ManagedReport"
ENV MODULES="ard, bluetooth, disk_report, munkireport, managedinstalls, munkiinfo, network, security, warranty"
ENV INDEX_PAGE=""
ENV AUTH_METHODS="NOAUTH"

# Copy application code into the container
WORKDIR $APP_DIR
COPY . $APP_DIR

# Install Composer and dependencies
COPY --from=composer:2.2.6 /usr/bin/composer /usr/local/bin/composer
RUN composer install --no-dev && \
    composer dumpautoload -o

# Create the app/db directory and adjust permissions
RUN mkdir -p app/db && \
    chmod -R 777 app/db

# Remove Apache’s default web directory and link to MunkiReport’s public folder
RUN rm -rf /var/www/html && \
    ln -s /var/munkireport/public /var/www/html

# Harden Apache configuration by reducing server information disclosure
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/apache2/conf-available/security.conf && \
    sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# Enable Apache’s rewrite module
RUN a2enmod rewrite

# ------------------ SSH ADDITIONS BEGIN ------------------

# Install OpenSSH
RUN apt-get update && \
    apt-get install -y openssh-server && \
    mkdir /var/run/sshd

# Set a root password
ARG ROOT_PASS
RUN echo 'root:${ROOT_PASS}' | chpasswd

# Enable password-based SSH, switch to port 2222
RUN sed -i 's/^#\?Port 22/Port 2222/' /etc/ssh/sshd_config && \
    sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 80 2222

RUN echo '#!/bin/bash' > /usr/local/bin/start.sh \
 && echo 'service ssh start' >> /usr/local/bin/start.sh \
 && echo 'apache2-foreground' >> /usr/local/bin/start.sh \
 && chmod +x /usr/local/bin/start.sh

CMD ["start.sh"]