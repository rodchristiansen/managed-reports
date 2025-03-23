#!/bin/bash

set -e

echo "==========================="
echo "=== BEGIN /etc/ssh/sshd_config ==="
cat /etc/ssh/sshd_config
echo "=== END /etc/ssh/sshd_config ==="
echo "==========================="

# Debug: output /etc/shadow to verify root password settings
echo "==========================="
echo "=== /etc/shadow (DEBUG) ==="
cat /etc/shadow
echo "=== END /etc/shadow (DEBUG) ==="
echo "==========================="

# Ensure the privilege separation directory exists
mkdir -p /run/sshd

# Optional: Install diagnostic tools if not available
if ! command -v netstat >/dev/null 2>&1; then
    echo "netstat not found. Installing net-tools..."
    apt-get update && apt-get install -y net-tools
fi

if ! command -v ss >/dev/null 2>&1; then
    echo "ss command not found. Installing iproute2..."
    apt-get update && apt-get install -y iproute2
fi

# Start the SSH daemon in the background
echo "Starting sshd..."
/usr/sbin/sshd -D &
# Give sshd a moment to start
sleep 2

# Display listening ports for diagnostic purposes
echo "==========================="
echo "=== Listening ports (netstat/ss) ==="
netstat -tlnp || ss -tlnp
echo "=== End Listening ports ==="
echo "==========================="

# Start Apache in the foreground so the container remains alive
echo "Starting Apache..."
apache2-foreground