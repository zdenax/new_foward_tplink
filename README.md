# Internet Forwarding Lab

Nastavení internet forwardingu z Kali Linux přes TP-Link AP do testovacího PC (Mint Linux).

## Fyzická Topologie

```
┌─────────────────────────────────────────────────────┐
│ Kali Linux (Notebook)                               │
│  ├─ wlan0: internet (WAN)                          │
│  └─ eth0: 192.168.100.50/24 (připojeno na AP LAN) │
└─────────────────────────────────────────────────────┘
              │
              │ (CAT5 kabel)
              │
┌─────────────────────────────────────────────────────┐
│ TP-Link AP                                          │
│  ├─ LAN: 192.168.100.1/24                          │
│  ├─ DHCP: 192.168.100.10-100                       │
│  └─ Gateway/DNS: 192.168.100.50 (Kali)             │
└─────────────────────────────────────────────────────┘
              │
              │ (WiFi)
              │
┌─────────────────────────────────────────────────────┐
│ Tester PC (Mint Linux)                              │
│  └─ WiFi: 192.168.100.X (z DHCP AP)                │
└─────────────────────────────────────────────────────┘
```

## Datový Tok

```
Tester → WiFi → AP (192.168.100.1) → Kali eth0 → IP Forward → Kali wlan0 → Internet
```

## Instalace

### 1. Příprava Kali

```bash
# Nastavení eth0 (pokud není statický)
sudo ip addr add 192.168.100.50/24 dev eth0
# nebo v /etc/network/interfaces:
# auto eth0
# iface eth0 inet static
#     address 192.168.100.50
#     netmask 255.255.255.0
```

### 2. Spuštění Forwardingu

```bash
cd ~/net_forwarding
sudo ./setup.sh
```

### 3. Ověření na Kali

```bash
# IP forwarding zapnutý?
cat /proc/sys/net/ipv4/ip_forward
# Mělo by být: 1

# NAT pravidla?
sudo iptables -t nat -L POSTROUTING -v
sudo iptables -L FORWARD -v
```

### 4. Konfigurace AP (Web Admin)

Vstup do AP webového rozhraní (http://192.168.100.1):

- **Network → LAN:**
  - IP: 192.168.100.1
  - Netmask: 255.255.255.0

- **Network → DHCP Server:**
  - Enable: ON
  - Start IP: 192.168.100.10
  - End IP: 192.168.100.100
  - Gateway: **192.168.100.50** (Kali)
  - DNS 1: **192.168.100.50** (Kali)
  - DNS 2: 8.8.8.8 (záloha)

- **WLAN → Basic:**
  - SSID: (tvůj network)
  - Security: WPA2 (nebo tvůj výběr)

### 5. Test na Testeri

```bash
# SSH na Tester (Mint)
ssh mint@192.168.100.12

# Kontrola na Testeri:
ip route           # Mělo by mít gateway 192.168.100.1 (AP)
ping 8.8.8.8      # Test internetu
curl -I google.com # Test HTTP
```

## Příkazy Diagnostiky

```bash
# Na Kali:
netstat -tlnp              # Otevřené porty
sudo tcpdump -i eth0 -n    # Sledovat eth0 provoz
sudo tcpdump -i wlan0 -n   # Sledovat wlan0 provoz

# Na Testeri:
traceroute 8.8.8.8         # Cesta k internetu
nslookup google.com        # DNS test
iperf3 -c <kali-ip>        # Bandwidth test (pokud máš iperf3)
```

## Zastavení Forwardingu

```bash
sudo ~/net_forwarding/stop.sh
```

## Troubleshooting

### Tester nemá internet
1. Kontrola AP gateway: měl by být 192.168.100.50
2. Ping na AP gateway z Testera: `ping 192.168.100.1`
3. Ping na Kali z Testera: `ping 192.168.100.50`
4. Kontrola IP forwarding na Kali: `cat /proc/sys/net/ipv4/ip_forward`

### AP nemá internet
1. Zkontroluj, že Kali wlan0 má internet: `ping 8.8.8.8`
2. Sleduj iptables pravidla: `sudo iptables -L FORWARD -v`
3. Zkontroluj rp_filter: `cat /proc/sys/net/ipv4/conf/all/rp_filter` (mělo by být 0)

### SSH nefunguje
```bash
# Vygeneruj SSH klíče
ssh-keygen -t ed25519 -f ~/.ssh/id_rsa -N "" -C "kali@lab"

# Zkopíruj na Tester
ssh-copy-id -i ~/.ssh/id_rsa.pub mint@192.168.100.12
```

## Persistence (Systemd Service - volitelně)

Pokud chceš forwarding po restartu:

```bash
sudo cp net-forwarding.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable net-forwarding
sudo systemctl start net-forwarding
```

## Soubory

- `setup.sh` - Hlavní skript pro nastavení
- `stop.sh` - Zastavení forwardingu
- `net-forwarding.service` - Systemd service (volitelně)
- `README.md` - Tato dokumentace

---
vault: [[Vault/School/ZPS]]
