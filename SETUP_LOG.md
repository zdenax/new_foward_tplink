# Internet Forwarding Lab - Setup Log

**Datum:** 2026-03-14
**Status:** ✅ **HOTOVO - FUNGUJE**

## Problém
Internet se neforwardoval - běžel jsem setup.sh, ale Tester neměl internet.

### Root Cause
NetworkManager vytvořil **virtuální eth1** interface s DHCP, který:
1. Vytvořil IP `192.168.100.11` na eth0
2. Nastavil default route na eth1 (metric 102)
3. Zablokoval wlan0 internet (metric 600)

```bash
# Problematické routing:
default via 192.168.100.50 dev eth1 proto dhcp src 192.168.100.11 metric 102  ❌
default via 10.0.1.138 dev wlan0 proto dhcp src 10.0.1.35 metric 600  ❌ (nižší priorita)
```

## Řešení

### Krok 1: Oprava eth0 konfiguraci
```bash
sudo nmcli connection modify "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.100.50/24 \
  ipv4.gateway "" \
  ipv4.dns ""

sudo nmcli connection up "Wired connection 1"
```

**Výsledek:**
```bash
# Správné routing:
default via 10.0.1.138 dev wlan0 proto dhcp src 10.0.1.35 metric 600  ✅
192.168.100.0/24 dev eth0 proto kernel scope link src 192.168.100.50  ✅
```

### Krok 2: Spuštění setup.sh
```bash
cd ~/new_foward_tplink
sudo ./setup.sh
```

## Verifikace ✅

**Routing OK:**
- Default route: wlan0 (internet)
- eth0: 192.168.100.50/24 (AP LAN)

**Forwarding OK:**
```
FORWARD pravidla:
  448 packetů eth0 → wlan0  ✅
  264 packetů wlan0 → eth0  ✅
```

**Internet test:**
```bash
ping 8.8.8.8
# ✅ 100% úspěšnost
```

## Finální Konfigurace

| Parametr | Hodnota | Status |
|----------|---------|--------|
| eth0 IP | 192.168.100.50/24 | ✅ Static |
| eth0 Gateway | (none) | ✅ Správně |
| wlan0 IP | 10.0.1.35/24 | ✅ DHCP |
| IP Forwarding | 1 | ✅ Enabled |
| rp_filter | 0 | ✅ Disabled |
| NAT (iptables) | MASQUERADE | ✅ Active |
| dnsmasq | Running | ✅ OK |

## Další Kroky

1. **TP-Link AP Nastavení:**
   - Network → DHCP Server → Gateway: `192.168.100.50`
   - Network → DHCP Server → DNS 1: `192.168.100.50`

2. **Test na Testeri (Mint PC):**
   ```bash
   ping 192.168.100.50      # Test na Kali gateway
   ping 8.8.8.8              # Test internetu
   nslookup google.com       # Test DNS
   ```

3. **Zastavení Forwardingu:**
   ```bash
   sudo ~/new_foward_tplink/stop.sh
   ```

## Troubleshooting

Pokud problém znovu nastane, zkontroluj:

```bash
# 1. Routing je OK?
ip route

# 2. wlan0 má internet?
ping 8.8.8.8

# 3. IP Forwarding je zapnutý?
cat /proc/sys/net/ipv4/ip_forward

# 4. iptables pravidla?
sudo iptables -L FORWARD -v
sudo iptables -t nat -L POSTROUTING -v
```

---
**Poznámka:** Problem byl v NetworkManageru, který automaticky vytvořil eth1. Při budoucích setupech zkontroluj `nmcli connection show` a ujisti se, že není duplikovaný ethernet connection.
