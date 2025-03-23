#!/bin/bash

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

# Start the SSH daemon in the background
/usr/sbin/sshd -D &
# Give sshd a moment to start
sleep 2

# Display listening ports for diagnostic purposes
echo "==========================="
echo "=== Listening ports (netstat) ==="
netstat -tlnp || ss -tlnp
echo "=== End Listening ports ==="
echo "==========================="

# Start Apache in the foreground so the container remains alive
apache2-foreground