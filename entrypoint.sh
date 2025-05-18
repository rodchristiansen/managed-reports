#!/bin/bash
set -euo pipefail

##############################################################################
# CONSTANTS
##############################################################################
APP_DIR="/var/munkireport"
CA_SRC="${APP_DIR}/local/certs/DigiCertGlobalRootCA.crt.pem"
CA_DST="/usr/local/share/ca-certificates/DigiCertGlobalRootCA.crt.pem"
PLEASE_CLI="${APP_DIR}/please"

##############################################################################
# 1. Trust the DigiCert root (idempotent)
##############################################################################
if [ -f "${CA_SRC}" ] && [ ! -f "${CA_DST}" ]; then
  echo "Installing DigiCert root CA"
  cp "${CA_SRC}" "${CA_DST}"
  update-ca-certificates || true
fi

##############################################################################
# 2. Block until MySQL accepts a socket
##############################################################################
echo "⏳  Waiting for MySQL to become available…"
until php -r '
  $dsn = sprintf(
    "mysql:host=%s;port=%s;charset=utf8mb4",
    getenv("CONNECTION_HOST") ?: "localhost",
    getenv("CONNECTION_PORT") ?: "3306"
  );
  try {
    new PDO($dsn, getenv("CONNECTION_USERNAME"), getenv("CONNECTION_PASSWORD"));
    exit(0);
  } catch (Exception $e) {
    exit(1);
  }
'; do
  sleep 3
done
echo "MySQL is reachable"

##############################################################################
# 3. Run migrations each boot (safe to rerun)
##############################################################################
echo "Running MunkiReport migrations"
chmod +x "${PLEASE_CLI}"          # ensure it’s executable
"${PLEASE_CLI}" migrate --force || true

##############################################################################
# 4. Start sshd in background
##############################################################################
echo "Starting sshd on port 2222"
mkdir -p /run/sshd
/usr/sbin/sshd -D &

##############################################################################
# 5. Launch Apache in foreground (PID 1)
##############################################################################
echo "Launching Apache"
exec apache2-foreground
