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
# Wait for MySQL to become healthy (30 s max)
######################################################################
echo "Waiting for MySQL..."
for i in {1..30}; do
  mysqladmin ping -h "$CONNECTION_HOST" -P "$CONNECTION_PORT" \
    -u "$CONNECTION_USERNAME" -p"$CONNECTION_PASSWORD" --silent \
    && break
  sleep 1
done

######################################################################
# Run migrations (idempotent)
######################################################################
/var/munkireport/please migrate || true   # never block container start
# composer update --no-dev

######################################################################
# Start services (what you already had)
######################################################################
mkdir -p /run/sshd
/usr/sbin/sshd -p 2222 -D &
exec apache2-foreground

# Debugging TLS
php -r '
  $out = [
    "MYSQLI_CLIENT_SSL_CA" => getenv("MYSQLI_CLIENT_SSL_CA"),
    "bytes_sent_ssl"       => mysqli_get_client_stats()["bytes_sent_ssl"] ?? 0
  ];
  file_put_contents("/var/munkireport/debug_tls.json", json_encode($out, JSON_PRETTY_PRINT));
';