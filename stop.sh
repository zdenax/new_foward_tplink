#!/bin/bash
# Zastavení Internet Forwardingu – Kali

set -e

WAN_IF="wlan0"
LAN_IF="eth0"
LAN_IP="192.168.100.50"

if [ "$EUID" -ne 0 ]; then
    echo "Spusť jako root: sudo ./stop.sh"
    exit 1
fi

echo "=== Zastavení Internet Forwardingu ==="

echo "1. Vypnutí IP Forwarding..."
sysctl -w net.ipv4.ip_forward=0

echo "2. Vyčištění NAT pravidel..."
iptables -t nat -D POSTROUTING -o "$WAN_IF" -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i "$LAN_IF" -o "$WAN_IF" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i "$WAN_IF" -o "$LAN_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
echo "   ✓ iptables vyčištěny"

echo "3. Zastavení dnsmasq..."
systemctl stop dnsmasq || true

echo "3b. Čištění DOCKER-USER pravidel..."
if iptables -L DOCKER-USER &>/dev/null 2>&1; then
    iptables -D DOCKER-USER -i "$LAN_IF" -o "$WAN_IF" -j ACCEPT 2>/dev/null || true
    iptables -D DOCKER-USER -i "$WAN_IF" -o "$LAN_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
fi

echo "4. Vrácení $LAN_IF na DHCP..."
ip addr del "$LAN_IP/24" dev "$LAN_IF" 2>/dev/null || true
ip link set "$LAN_IF" up
dhclient "$LAN_IF" 2>/dev/null || true

echo "✓ Internet Forwarding zastaveno"
