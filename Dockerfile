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

# ------------------ SSH SETUP ------------------

# 1) Install OpenSSH
RUN apt-get update && \
    apt-get install -y openssh-server && \
    rm -rf /var/lib/apt/lists/*

# 2) Configure SSH on port 2222 & allow root password logins
RUN apt-get update && apt-get install -y openssh-server && \
    ssh-keygen -A && \
    sed -i 's/^#Port .*/Port 2222/' /etc/ssh/sshd_config && \
    sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

# 3) Expose Apache (80) & SSH (2222)
EXPOSE 80 2222

# 4) Start script: run SSH, then Apache
RUN echo '#!/bin/bash' > /usr/local/bin/start.sh && \
    echo 'service ssh start' >> /usr/local/bin/start.sh && \
    echo 'apache2-foreground' >> /usr/local/bin/start.sh && \
    chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]