#!/bin/bash
# Internet Forwarding Setup – Kali
# Internet z WAN_IF přes LAN_IF do AP sítě

set -e

# === Konfigurace rozhraní ===
WAN_IF="wlan0"           # internet (WiFi)
LAN_IF="eth0"            # kabel do AP
LAN_IP="192.168.100.50"  # statická IP Kali v AP síti

echo "=== Internet Forwarding Setup (Kali) ==="
echo "    WAN: $WAN_IF  →  LAN: $LAN_IF"

if [ "$EUID" -ne 0 ]; then
    echo "Spusť jako root: sudo ./setup.sh"
    exit 1
fi

# 1. Kontrola rozhraní + statická IP na LAN
echo ""
echo "1. Kontrola sítě..."
ip link show "$LAN_IF" > /dev/null 2>&1 || { echo "Chyba: $LAN_IF nenalezeno"; exit 1; }
ip link show "$WAN_IF" > /dev/null 2>&1 || { echo "Chyba: $WAN_IF nenalezeno"; exit 1; }

echo "   Nastavuji statickou IP $LAN_IP na $LAN_IF..."
ip addr flush dev "$LAN_IF" 2>/dev/null || true
ip addr add "$LAN_IP/24" dev "$LAN_IF"
ip link set "$LAN_IF" up

echo "   $LAN_IF: $(ip addr show "$LAN_IF" | grep "inet " | awk '{print $2}' || echo 'bez IP')"
echo "   $WAN_IF: $(ip addr show "$WAN_IF" | grep "inet " | awk '{print $2}' || echo 'bez IP')"

# 2. IP Forwarding
echo ""
echo "2. Povolení IP Forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0

# 3. NAT (iptables)
echo ""
echo "3. Nastavení NAT (iptables)..."
iptables -t nat -D POSTROUTING -o "$WAN_IF" -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE
iptables -D FORWARD -i "$LAN_IF" -o "$WAN_IF" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i "$WAN_IF" -o "$LAN_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i "$LAN_IF" -o "$WAN_IF" -j ACCEPT
iptables -A FORWARD -i "$WAN_IF" -o "$LAN_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT
echo "   ✓ iptables nastaveny"

# 4. DNS (dnsmasq)
echo ""
echo "4. Nastavení DNS (dnsmasq)..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/dnsmasq.conf" /etc/dnsmasq.conf

# Kali: systemd-resolved může konfliktovat na portu 53
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    echo "   Zastavuji systemd-resolved (konflikt port 53)..."
    systemctl stop systemd-resolved
fi

systemctl enable dnsmasq
systemctl restart dnsmasq && echo "   ✓ dnsmasq spuštěn" || echo "   ✗ dnsmasq selhal"

# 4b. Docker FORWARD override
echo ""
echo "4b. Docker FORWARD override..."
if iptables -L DOCKER-USER &>/dev/null 2>&1; then
    iptables -D DOCKER-USER -i "$LAN_IF" -o "$WAN_IF" -j ACCEPT 2>/dev/null || true
    iptables -D DOCKER-USER -i "$WAN_IF" -o "$LAN_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    iptables -I DOCKER-USER -i "$LAN_IF" -o "$WAN_IF" -j ACCEPT
    iptables -I DOCKER-USER -i "$WAN_IF" -o "$LAN_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT
    echo "   ✓ DOCKER-USER pravidla přidána"
else
    echo "   Docker není, přeskakuji"
fi

# 5. Uložení pravidel
echo ""
echo "5. Uložení iptables pravidel..."
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# 6. Verifikace
echo ""
echo "=== Verifikace ==="
echo "IP Forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo ""
echo "NAT pravidla:"
iptables -t nat -L POSTROUTING -v | grep -A1 "Chain POSTROUTING"
echo ""
echo "FORWARD pravidla:"
iptables -L FORWARD -v | head -5

echo ""
echo "✓ Forwarding nastaven!"
echo ""
echo "Příští kroky:"
echo "1. Ověř AP gateway: měl by být IP $LAN_IF ($LAN_IP)"
echo "2. Test na klientovi: ping 8.8.8.8"
echo "3. Zastavení: sudo ./stop.sh"
