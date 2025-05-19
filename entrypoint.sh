#!/bin/bash
set -e

######################################################################
# 0) Load Azure-App-Service env-vars **before** we touch Laravel
######################################################################
if [ -f /opt/startup/container/appsvc/setenv.sh ]; then
  # Azure injects all App Settings here – source them so `please` sees
  # CONNECTION_DRIVER, CONNECTION_HOST, etc. during this shell session.
  . /opt/startup/container/appsvc/setenv.sh
fi

######################################################################
# 1) Force a very light-weight cleanup of anything that might cause
#    MunkiReport to boot with SQLite or with stale config.
######################################################################
# - compiled (cached) configs & routes
rm -f /var/munkireport/bootstrap/cache/{config,routes}.php || true

# - leftover SQLite file (only if you’re on MySQL now)
rm -f /var/munkireport/storage/db/*.db || true

# drop any cached configs before Apache starts 
rm -f /var/munkireport/bootstrap/cache/{config,routes}.php

######################################################################
# 2) Run migrations (idempotent)
######################################################################
/var/munkireport/please migrate || true   # never block container start

######################################################################
# 3) Start services (what you already had)
######################################################################
mkdir -p /run/sshd
/usr/sbin/sshd -D &
exec apache2-foreground

######################################################################
# 4) MySQL SSL bundle (unchanged) – leave this after apache starts;
#    it only sets env-vars for PHP’s PDO.
######################################################################
if [ -n "$MYSQL_SSL_CA_BUNDLE" ] && [ ! -f /tmp/mysql-ca.pem ]; then
  printf '%s\n' "$MYSQL_SSL_CA_BUNDLE" > /tmp/mysql-ca.pem
  export PDO_MYSQL_ATTR_SSL_CA=/tmp/mysql-ca.pem
fi