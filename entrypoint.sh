#!/bin/bash
set -e

######################################################################
# Load Azure-App-Service env-vars **before** we touch Laravel
######################################################################
if [ -f /opt/startup/container/appsvc/setenv.sh ]; then
  # Azure injects all App Settings here – source them so `please` sees
  # CONNECTION_DRIVER, CONNECTION_HOST, etc. during this shell session.
  . /opt/startup/container/appsvc/setenv.sh
fi

######################################################################
# Force a very light-weight cleanup of anything that might cause
#    MunkiReport to boot with SQLite or with stale config.
######################################################################
# - compiled (cached) configs & routes
rm -f /var/munkireport/bootstrap/cache/{config,routes}.php || true

# - leftover SQLite file (only if you’re on MySQL now)
rm -f /var/munkireport/storage/db/*.db || true

# drop any cached configs before Apache starts 
rm -f /var/munkireport/bootstrap/cache/{config,routes}.php

######################################################################
# Prepare MySQL SSL
######################################################################
if [ -n "$MYSQL_SSL_CA_B64" ] && [ ! -f /usr/local/share/ca-certificates/DigiCertGlobalRootCA.crt.pem ]; then
  echo "$MYSQL_SSL_CA_B64" | base64 -d > /usr/local/share/ca-certificates/DigiCertGlobalRootCA.crt.pem
  chmod 644 /usr/local/share/ca-certificates/DigiCertGlobalRootCA.crt.pem
fi

export CONNECTION_SSL_CA=/usr/local/share/ca-certificates/DigiCertGlobalRootCA.crt.pem
export MYSQL_ATTR_SSL_CA=$CONNECTION_SSL_CA
export PDO_MYSQL_ATTR_SSL_CA=$CONNECTION_SSL_CA

echo "DB host: $CONNECTION_HOST"
echo "CA file: $CONNECTION_SSL_CA"

######################################################################
# Run migrations (idempotent)
######################################################################
/var/munkireport/please migrate || true   # never block container start
# composer update --no-dev

######################################################################
# Start services (what you already had)
######################################################################
mkdir -p /run/sshd
/usr/sbin/sshd -D &
exec apache2-foreground
