#!/bin/bash
# Internet Forwarding Setup
# Poskytuje internet z wlan0 přes eth0 do AP sítě

set -e

echo "=== Internet Forwarding Setup ==="

# Ověř, že běžíš jako root
if [ "$EUID" -ne 0 ]; then
    echo "Spusť jako root: sudo ./setup.sh"
    exit 1
fi

# 1. Kontrola rozhraní
echo "1. Kontrola sítě..."
ip addr show eth0 > /dev/null 2>&1 || { echo "Chyba: eth0 nenalezeno"; exit 1; }
ip addr show wlan0 > /dev/null 2>&1 || { echo "Chyba: wlan0 nenalezeno"; exit 1; }

echo "   eth0: $(ip addr show eth0 | grep "inet " | awk '{print $2}')"
echo "   wlan0: $(ip addr show wlan0 | grep "inet " | awk '{print $2}')"

# 2. IP Forwarding
echo ""
echo "2. Povolení IP Forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0

# 3. NAT pravidla
echo ""
echo "3. Nastavení NAT (iptables)..."

# Vyčisti stará pravidla pro MASQUERADE
iptables -t nat -D POSTROUTING -o wlan0 -j MASQUERADE 2>/dev/null || true

# Nastav nová pravidla
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# 4. DNS (dnsmasq)
echo ""
echo "4. Nastavení DNS (dnsmasq)..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/dnsmasq.conf" /etc/dnsmasq.conf
systemctl restart dnsmasq && echo "   ✓ dnsmasq spuštěn" || echo "   ✗ dnsmasq selhal"

# 5. Uložení pravidel
echo ""
echo "5. Uložení iptables pravidel..."
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# 5. Verifikace
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
echo "1. Ověř AP gateway: měl by být 192.168.100.50 (nebo AP IP)"
echo "2. Test na Testeri: ping 8.8.8.8"
echo "3. Zastavení: sudo ./stop.sh"
