#!/bin/bash
set -euo pipefail

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

######################################################################
# Wait for MySQL to become healthy (30 s max)
######################################################################
echo "Waiting for MySQL..."
for i in {1..30}; do
  if [[ -n "${CONNECTION_SSL_CA:-}" ]]; then
    mysqladmin --ssl-ca="$CONNECTION_SSL_CA" ping -h "$CONNECTION_HOST" -P "$CONNECTION_PORT" \
      -u "$CONNECTION_USERNAME" -p"$CONNECTION_PASSWORD" --silent && break
  else
    mysqladmin ping -h "$CONNECTION_HOST" -P "$CONNECTION_PORT" \
      -u "$CONNECTION_USERNAME" -p"$CONNECTION_PASSWORD" --silent && break
  fi
  sleep 1
done
if (( i == 30 )); then
  echo "MySQL still unreachable after 30 s" >&2
  exit 1
fi

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

# Debug TLS connection
php -d detect_unicode=0 -r '
  $out = [
    "MYSQLI_CLIENT_SSL_CA" => getenv("MYSQLI_CLIENT_SSL_CA"),
    "bytes_sent_ssl"       => function_exists("mysqli_get_client_stats")
                              ? (mysqli_get_client_stats()["bytes_sent_ssl"] ?? 0)
                              : 0
  ];
  file_put_contents(
    "/var/munkireport/debug_tls.json",
    json_encode($out, JSON_PRETTY_PRINT)
  );
' || true  

exec apache2-foreground
