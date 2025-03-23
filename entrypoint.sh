#!/bin/bash

echo "==========================="
echo "=== BEGIN /etc/ssh/sshd_config ==="
cat /etc/ssh/sshd_config
echo "=== END /etc/ssh/sshd_config ==="
echo "==========================="

service ssh start
apache2-foreground