#!/bin/bash
set -eu

export PHP_INI_SCAN_DIR="${PHP_INI_DIR:-/usr/local/etc/php}/conf.d"

# Azure injects env-vars here – source them so the shell sees CONNECTION_*.
[ -f /opt/startup/container/appsvc/setenv.sh ] && \
    . /opt/startup/container/appsvc/setenv.sh

# nuke stale Laravel caches
rm -f /var/munkireport/bootstrap/cache/{config,routes}.php 2>/dev/null || true

# wait for MySQL (max 30 s)
echo "Waiting for MySQL @ ${CONNECTION_HOST}:${CONNECTION_PORT} …"
for i in {1..30}; do
  mysqladmin --ssl-ca="${CONNECTION_SSL_CA:-/etc/ssl/certs/ca-certificates.crt}" \
    ping -h "$CONNECTION_HOST" -P "$CONNECTION_PORT" \
    -u "$CONNECTION_USERNAME" -p"$CONNECTION_PASSWORD" --silent && break
  sleep 1
done
[[ $i == 30 ]] && { echo "DB still unreachable."; exit 1; }

# run migrations (idempotent)
echo "Running please migrate"
( cd /var/munkireport && /var/munkireport/please migrate ) || true

# tiny TLS probe so you can `kubectl exec cat /var/munkireport/debug_tls.json`
php -r '
  $db = mysqli_init();
  mysqli_ssl_set($db, null, null, getenv("MYSQLI_CLIENT_SSL_CA"), null, null);
  mysqli_real_connect(
      $db, getenv("CONNECTION_HOST"), getenv("CONNECTION_USERNAME"),
      getenv("CONNECTION_PASSWORD"), getenv("CONNECTION_DATABASE"), 3306,
      null, MYSQLI_CLIENT_SSL
  ) or die("DB connect failed");
  $row = mysqli_fetch_row(mysqli_query($db,"SHOW STATUS LIKE \"Ssl_cipher\""));
  file_put_contents("/var/munkireport/debug_tls.json",
    json_encode(["cipher"=>$row[1]??"none"], JSON_PRETTY_PRINT));
' 2>/dev/null || true

# start SSH (2222) + Apache
mkdir -p /run/sshd
/usr/sbin/sshd -p 2222 -D &
exec apache2-foreground