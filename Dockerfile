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

# Configure & install PHP extensions (no more --with-libdir=...)
RUN docker-php-ext-configure ldap && \
    docker-php-ext-install -j"$(nproc)" curl pdo_mysql soap ldap zip

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

# (Removed "php please migrate" so it doesn't fail during build)
# If you need migrations, run them at startup or in a separate deployment step.

# Remove Apache’s default web directory and link to MunkiReport’s public folder
RUN rm -rf /var/www/html && \
    ln -s /var/munkireport/public /var/www/html

# Harden Apache configuration by reducing server information disclosure
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/apache2/conf-available/security.conf && \
    sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# Enable Apache’s rewrite module
RUN a2enmod rewrite

# Expose the web server port
EXPOSE 80

# Start Apache in the foreground
CMD ["apache2-foreground"]