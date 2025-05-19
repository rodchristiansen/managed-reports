#!/bin/bash
set -e

# ── 1. run migrations (safe to rerun) ─────────────────────
/var/munkireport/please migrate || true

# ── 2. start sshd + apache ────────────────────────────────
mkdir -p /run/sshd
/usr/sbin/sshd -D &
exec apache2-foreground

# ── 3. Configure MySQL SSL ─────────────────────────────────
if [ -n "$MYSQL_SSL_CA_BUNDLE" ] && [ ! -f /tmp/mysql-ca.pem ]; then
  printf '%s\n' "$MYSQL_SSL_CA_BUNDLE" > /tmp/mysql-ca.pem
  export PDO_MYSQL_ATTR_SSL_CA=/tmp/mysql-ca.pem
fi