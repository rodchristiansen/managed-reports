#!/bin/bash
set -e

# Create the privilege separation directory required by sshd
mkdir -p /run/sshd

# Start the SSH daemon in the background
/usr/sbin/sshd -D &

# Allow a short pause for sshd to initialize
sleep 2

# Start Apache in the foreground so the container remains alive
exec apache2-foreground