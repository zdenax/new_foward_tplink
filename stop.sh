#!/bin/bash
# Zastavení Internet Forwardingu

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Spusť jako root: sudo ./stop.sh"
    exit 1
fi

echo "=== Zastavení Internet Forwardingu ==="

# Vypnutí IP Forwarding
echo "1. Vypnutí IP Forwarding..."
sysctl -w net.ipv4.ip_forward=0

# Vyčištění NAT pravidel
echo "2. Vyčištění iptables pravidel..."
iptables -t nat -F POSTROUTING
iptables -F FORWARD

echo "✓ Internet Forwarding zastaveno"
