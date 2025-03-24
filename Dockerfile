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

# Embed SSO cert and DigiCert CA in container
COPY certs/AzureFederatedSSO.crt /var/munkireport/local/certs/idp.crt
COPY certs/DigiCertGlobalRootCA.crt.pem /usr/local/share/ca-certificates/DigiCertGlobalRootCA.crt.pem

RUN chmod 644 /usr/local/share/ca-certificates/DigiCertGlobalRootCA.crt.pem /var/munkireport/local/certs/idp.crt \
    && update-ca-certificates --fresh

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

# Install SSH server
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Declare the build argument
ARG ROOT_PASS

# Use it to set the root password
RUN echo "root:${ROOT_PASS}" | chpasswd

# Adjust sshd_config: set port to 2222, enable root login, pubkey and password authentication, and enable PAM
RUN ssh-keygen -A && \
    sed -i 's|^#Port .*|Port 2222|' /etc/ssh/sshd_config && \
    sed -i 's|^#PermitRootLogin .*|PermitRootLogin yes|' /etc/ssh/sshd_config && \
    sed -i 's|^#PubkeyAuthentication .*|PubkeyAuthentication yes|' /etc/ssh/sshd_config && \
    sed -i 's|^#PasswordAuthentication .*|PasswordAuthentication yes|' /etc/ssh/sshd_config && \
    sed -i 's|^#UsePAM .*|UsePAM yes|' /etc/ssh/sshd_config

# Copy in our entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose necessary ports: 80 for Apache and 2222 for SSH
EXPOSE 80 2222

# Launch the script that prints sshd_config then starts SSH and Apache
CMD ["/entrypoint.sh"]