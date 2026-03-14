#!/bin/bash
# Test Internet Forwardingu

echo "=== Internet Forwarding Test ==="
echo ""

# Test 1: IP Forwarding
echo "1. IP Forwarding status:"
fwd=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$fwd" = "1" ]; then
    echo "   ✓ Zapnutý"
else
    echo "   ✗ Vypnutý (spusť: sudo ./setup.sh)"
fi
echo ""

# Test 2: NAT pravidla
echo "2. NAT pravidla:"
nat_count=$(sudo iptables -t nat -L POSTROUTING -v | grep MASQUERADE | wc -l)
if [ "$nat_count" -gt 0 ]; then
    echo "   ✓ NAT nakonfigurován"
    sudo iptables -t nat -L POSTROUTING -v | grep -A1 "Chain POSTROUTING"
else
    echo "   ✗ NAT není nakonfigurován"
fi
echo ""

# Test 3: Rozhraní
echo "3. Síťová rozhraní:"
eth0_ip=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
wlan0_ip=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -z "$eth0_ip" ]; then
    echo "   ✗ eth0 nemá IP (konfig: sudo ip addr add 192.168.100.50/24 dev eth0)"
else
    echo "   ✓ eth0: $eth0_ip"
fi

if [ -z "$wlan0_ip" ]; then
    echo "   ✗ wlan0 nemá IP"
else
    echo "   ✓ wlan0: $wlan0_ip"
fi
echo ""

# Test 4: Konektivita
echo "4. Konektivita:"
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "   ✓ Internet dostupný"
else
    echo "   ✗ Internet není dostupný"
fi
echo ""

# Test 5: SSH na Tester
echo "5. SSH na Tester (192.168.100.12):"
if ssh -o ConnectTimeout=2 mint@192.168.100.12 "echo OK" > /dev/null 2>&1; then
    echo "   ✓ SSH připojen"
    # Test internetu na Testeri
    if ssh mint@192.168.100.12 "ping -c 1 -W 2 8.8.8.8" > /dev/null 2>&1; then
        echo "   ✓ Tester má internet"
    else
        echo "   ✗ Tester nemá internet"
    fi
else
    echo "   ✗ SSH není dostupný (Tester online?)"
fi
echo ""

echo "=== Diagnostika Hotova ==="
