# 🛠️ My Tools Collection

A curated collection of system optimization, performance tuning, biofeedback, and anonymity tools for Kali Linux.

---

## 📦 Contents

1. [Ghost Profile](#-ghost-profile) - Advanced anonymity & identity masking suite
2. [Heartbeat Daemon](#-heartbeat-daemon) - Biofeedback-driven flow state audio system
3. [Minecraft Performance Optimizer](#-minecraft-performance-optimizer) - System tuning for gaming
4. [Boot Optimization Script](#-boot-optimization-script) - Faster boot times
5. [Essential Tools Installer](#-essential-tools-installer) - Complete Kali toolset setup

---

## 👻 Ghost Profile

**Advanced hardened anonymity suite for Kali Linux. Masks your identity at every layer — MAC, IP, DNS, TLS, browser, traffic pattern, and behavioral fingerprint.**

> ⚠️ **For authorized security research and penetration testing only. Use exclusively on systems you own or have explicit written permission to test. Unauthorized use is illegal.**

### What It Does

Ghost Profile is a menu-driven bash script that systematically hardens your anonymity across every identifiable layer of your system and network stack. It goes far beyond simple IP masking — it addresses MAC correlation, DNS leaks, TLS fingerprints, browser fingerprints, traffic timing patterns, protocol signatures, and behavioral attribution.

### Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Ghost Profile v4                  │
│                                                     │
│  MAC Layer    → randomize + vendor emulate          │
│  Network      → Tor + obfs4 + Shadowsocks           │
│  DNS          → dnscrypt-proxy + padding + relay    │
│  Firewall     → iptables full lockdown + kill-switch│
│  TLS          → uTLS / REALITY / JA3 spoof          │
│  Traffic      → padding + protocol mimicry          │
│  Browser      → canvas/WebGL/font normalization     │
│  Behavioral   → timing jitter + infra rotation      │
│  Honeypot     → pre-engagement detection            │
└─────────────────────────────────────────────────────┘
```

### Installation

```bash
# Copy to tools directory
cp ghost_profile_v4.sh ~/tools/ghost.sh
chmod +x ~/tools/ghost.sh

# Run as root (required)
sudo bash ~/tools/ghost.sh
```

### Dependencies

The script checks for and optionally installs all dependencies on first run. Core packages:

```bash
sudo apt install -y \
  macchanger tor proxychains4 obfs4proxy \
  shadowsocks-libev dnscrypt-proxy unbound \
  nmap torsocks rfkill iw ethtool bleachbit \
  curl iptables net-tools coreutils

# Python uTLS tools (optional, for TLS fingerprint spoofing)
pip3 install tls-client curl-cffi scapy
```

### Quick Start — One-Click Ghost Mode

The fastest way to go dark. Press `G` from the main menu to activate all 10 hardening steps automatically:

```
Step 1  → IPv6 fully disabled (sysctl + ip6tables)
Step 2  → MAC randomized + DHCP lease flushed
Step 3  → Hostname set to realistic Windows/Mac device name
Step 4  → Timezone forced to UTC
Step 5  → Tor started (stream isolation + TransPort + DNSPort)
Step 6  → proxychains4 configured to strict Tor chain
Step 7  → DNS locked to 127.0.0.1 + resolv.conf immutable
Step 8  → iptables full lockdown + kill-switch active
Step 9  → TCP stack hardened (timestamps off, TTL randomized)
Step 10 → ghost_ns network namespace created
```

Press `R` to restore your original profile when done.

### Main Menu

```
[G]  ONE-CLICK GHOST MODE ON
[R]  RESTORE NORMAL PROFILE

[1]  MAC Address Changer         DHCP-aware, scope explanation
[A]  MAC Advanced                Scheduled rotation + vendor emulation
[2]  Hostname Spoofer            Realistic Windows/Mac device names
[3]  Tor + ProxyChains + Bridges Stream isolation + multi-hop chains
[P]  Pluggable Transports        obfs4 / meek-azure / snowflake / webtunnel
[O]  Traffic Obfuscation         obfs4proxy standalone + Shadowsocks
[4]  DNS Leak Prevention         dnscrypt + Unbound + per-app isolation
[D]  DNS Permanent Encryption    Permanent dnscrypt + padding + relays
[5]  IPTables Lockdown           No escape paths, kill-switch
[6]  Secure Log Wipe             3-pass shred + external log guide
[7]  Fingerprint + Cover Traffic JA3 + Scapy + IDS awareness
[T]  TLS Fingerprint Spoofing    uTLS + REALITY + live JA3 checker
[W]  Traffic Padding             Constant / burst / adaptive + ICMP
[M]  Protocol Mimicry            DoH / DoT / HTTPS tunnel / WebSocket
[B]  Browser Fingerprint         Canvas + WebGL + Font + user.js
[8]  Behavioral + OPSEC Tools    Timing jitter + infra rotation + self-audit
[9]  Network Infra + Isolation   Namespaces + RAM session guide
[0]  Timezone + NTP Spoofing     Activity window randomization
[H]  Honeypot Detection          Safe interaction depth
[S]  Status Dashboard
[Q]  Quit
```

### Feature Reference

#### MAC Address (`[1]` and `[A]`)

| Feature | Description |
|---|---|
| Full random MAC | Randomizes vendor + device bytes + flushes DHCP lease |
| Vendor-blend | Picks OUI from Apple / Samsung / Dell / Lenovo etc. |
| Device-type mimic | Phone / laptop / router / smart TV OUI pools |
| Scheduled rotation | Cron job rotates MAC every 30min / 1hr / 6hr / custom |
| Scope awareness | Explains what MAC spoofing does and doesn't protect |

#### Traffic Obfuscation (`[O]`)

| Mode | Description |
|---|---|
| obfs4proxy server | Standalone obfs4 relay — generates bridge line + cert |
| obfs4proxy client | Connect through an obfs4 server |
| Shadowsocks server | `chacha20-ietf-poly1305`, random port + auto password |
| Shadowsocks client | Local SOCKS5 on `127.0.0.1:1080` |
| SS → Tor chain | Shadowsocks obfuscation + Tor routing combined |

#### Pluggable Transports (`[P]`)

| Transport | Traffic Appears As | Best For |
|---|---|---|
| obfs4 | Random bytes | DPI, keyword filtering |
| meek-azure | HTTPS to Microsoft Azure CDN | IP-level Tor blocks |
| snowflake | WebRTC video call | Deep censorship |
| webtunnel | Normal HTTPS website | DPI environments |

#### DNS (`[4]` and `[D]`)

- `dnscrypt-proxy` permanent systemd service — survives reboots, auto-restarts
- DNS padding (`padding_disabled = false`) — all queries same block size, no domain length leakage
- Anonymized DNS relays — DNS server never sees your real IP
- Unbound local recursive resolver with QNAME minimization + DNSSEC
- `systemd-resolved` disabled (major DNS leak source)
- `resolv.conf` locked immutable with `chattr +i`

#### TLS Fingerprint Spoofing (`[T]`)

- **Xray-core REALITY** — generates client config that impersonates Chrome TLS exactly
- **tls-client / curl-cffi** — Python libraries for per-request TLS profile selection
- **JA3 live check** — tests your current fingerprint against tls.peet.ws
- Profiles supported: `chrome_120`, `firefox_120`, `safari_16_0`, `ios_16_0`

#### Traffic Padding (`[W]`)

| Mode | Behaviour |
|---|---|
| Constant-rate | Fixed requests/minute regardless of real traffic |
| Burst | 3–8 clustered requests then long gap (human-like) |
| Adaptive | Noise scales proportionally with real traffic volume |
| ICMP | Network-level random-size ping flood for timing noise |

#### Browser Fingerprint (`[B]`)

Generates a hardened Firefox `user.js` and a `ghost_chromium.sh` launch script covering:

- Canvas API noise (`privacy.resistFingerprinting`)
- WebGL disabled + renderer string spoofed
- WebRTC fully disabled (no LAN IP leak)
- Font enumeration blocked
- Timezone forced to UTC
- Locale normalized to `en-US`
- Hardware APIs disabled (battery, vibration, sensors, gamepad)
- SOCKS5 proxy pre-configured to Tor
- Letterboxing (prevents screen resolution fingerprinting)

### Using with Other Tools

All tools should be wrapped with `proxychains4` or `torsocks` to route through Tor:

```bash
# Nmap through Tor
proxychains4 nmap -T2 --randomize-hosts target.com

# curl through Tor
torsocks curl https://example.com

# Any tool through the isolated namespace
ip netns exec ghost_ns proxychains4 <tool>

# Python script with browser-grade TLS
python3 -c "
import tls_client
s = tls_client.Session(client_identifier='chrome_120')
r = s.get('https://example.com')
print(r.status_code)
"
```

### Status Dashboard

Press `[S]` to see a live overview of your anonymity state:

```
╔══════════════════ GHOST STATUS ══════════════════════════╗
║  Real IP        : 203.0.113.5
║  Tor Exit IP    : 185.220.101.x
║  Tor            : ● Running
║  DNS            : 127.0.0.1
║  Timezone       : UTC
║  Hostname       : DESKTOP-3F2A1B
║  MAC [wlan0]    : dc:a6:32:xx:xx:xx
║  IPv6           : DISABLED ✓
║  Kill-switch    : ACTIVE ✓
║  ghost_ns       : EXISTS ✓
║  dnscrypt-proxy : ● Running
╚══════════════════════════════════════════════════════════╝
```

### Honeypot Detection (`[H]`)

Before engaging any unknown target, run the pre-engagement check:

```bash
# From the Ghost menu → [H] → [1]
# Checks: open port count anomaly, TTL, banner signatures
# Cross-references: Shodan, AbuseIPDB, Censys
# Tests: response consistency across 3 probes
```

High-risk signals trigger an automatic abort recommendation.

### OPSEC Checklist

The behavioral self-audit (`[8]` → `[8]`) scores your operational patterns:

- Do you always use the same tool chain? *(predictable workflow)*
- Same time of day every session? *(timezone fingerprint)*
- Default tool configs? *(tool signature)*
- Same VPS/infrastructure? *(infra fingerprint)*
- Same scripting language? *(code style fingerprint)*

### Session Log

Ghost Profile logs session actions to RAM only — wiped on reboot:

```bash
cat /tmp/.ghost_session.log
```

No persistent disk log is written during operation.

### Resource Usage

- **RAM:** ~5–10 MB (script + Tor)
- **CPU:** <0.5% idle
- **Network:** Padding modes use configurable bandwidth

### Troubleshooting

**Script exits immediately after root check:**
```bash
# Always run with bash explicitly
sudo bash ghost.sh
# NOT: sudo ./ghost.sh (requires shebang + execute bit + PATH)
```

**Tor fails to start:**
```bash
journalctl -u tor --no-pager | tail -20
# Common fix: remove Ghost Profile lines from torrc
sudo sed -i '/## Ghost Profile/,/AutomapHostsOnResolve/d' /etc/tor/torrc
sudo systemctl restart tor
```

**DNS not resolving after Ghost Mode:**
```bash
# Tor DNSPort must be running before locking DNS
# Unlock resolv.conf
sudo chattr -i /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

**proxychains hangs:**
```bash
# Test Tor is actually up first
curl --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip
```

**Restore if anything breaks:**
```bash
# Press [R] from the main menu, OR manually:
sudo chattr -i /etc/resolv.conf
sudo iptables -F && sudo iptables -P INPUT ACCEPT && sudo iptables -P OUTPUT ACCEPT
sudo ip6tables -F && sudo ip6tables -P INPUT ACCEPT && sudo ip6tables -P OUTPUT ACCEPT
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
sudo systemctl stop tor
sudo macchanger -p wlan0   # replace wlan0 with your interface
```

---

## 💓 Heartbeat Daemon

**Terminal-only biofeedback system that mirrors your laptop's "physiological state" through audio rhythm entrainment.**

### What It Does

Uses battery level and charging status to play ECG-style heartbeat sounds at varying tempos and volumes, designed to trigger flow states and regulate focus through subconscious rhythm entrainment.

### State Mapping

| Battery Level | BPM Range | Volume | Audio File | Psychological State |
|---------------|-----------|--------|------------|---------------------|
| **71-100%** | 50-60 | Quiet | `heartbeat.wav` | Calm/Rest |
| **Charging** | 55 (fixed) | Quiet | `heartbeat.wav` | Recovery |
| **21-70%** | 70-90 | Medium | `heartbeatmid.wav` | Productive Work |
| **6-20%** | 100-130 | Loud | `heartbeatloud.wav` | Urgent Alert |
| **<6%** | 100-130 | **LOUDEST** | `noheartbeat.wav` | Critical Panic |

### Installation

#### 1. Create Audio Files

Place your audio files in `/home/naegleria/tools/heartbeat/`:

```bash
mkdir -p ~/tools/heartbeat
cd ~/tools/heartbeat

# You need to create these 4 files:
# - heartbeat.wav (base/quiet version)
# - heartbeatmid.wav (medium loud - boost +3 to +6 dB)
# - heartbeatloud.wav (loud - boost +6 to +12 dB)
# - noheartbeat.wav (loudest - boost +12 to +15 dB)
```

**Using ffmpeg to create variants:**

```bash
# Create medium version
ffmpeg -i heartbeat.wav -filter:a "volume=1.5" heartbeatmid.wav

# Create loud version
ffmpeg -i heartbeat.wav -filter:a "volume=2.0" heartbeatloud.wav

# Create loudest version
ffmpeg -i heartbeat.wav -filter:a "volume=2.5" noheartbeat.wav
```

#### 2. Install the Script

```bash
sudo cp heartbeat.sh /usr/local/bin/heartbeat
sudo chmod +x /usr/local/bin/heartbeat
```

#### 3. Create Systemd User Service

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/heartbeat.service
```

**Paste this content:**

```ini
[Unit]
Description=Terminal Laptop Heartbeat Daemon
After=default.target

[Service]
Type=simple
ExecStart=/usr/local/bin/heartbeat start
ExecStop=/usr/local/bin/heartbeat stop
Restart=on-failure
Environment=DISPLAY=:0
Environment=PULSE_SERVER=unix:/run/user/1000/pulse/native
StandardOutput=null
StandardError=null

[Install]
WantedBy=default.target
```

#### 4. Enable and Start Service

```bash
systemctl --user daemon-reload
systemctl --user enable heartbeat.service
systemctl --user start heartbeat.service
```

### Usage

```bash
heartbeat start   # Start daemon
heartbeat stop    # Stop daemon
heartbeat status  # Check if running
heartbeat test    # Play 3-second demo of each state
heartbeat help    # Show help menu
```

### Dependencies

```bash
sudo apt install alsa-utils bc -y
```

### Resource Usage

- **RAM:** ~1-2 MB
- **CPU:** <0.1% (sleep-based, not polling)
- **No visual overhead** — pure audio

---

## 🎮 Minecraft Performance Optimizer

**System tuning scripts for optimal Minecraft Java Edition performance on Intel graphics.**

### Files

- `minecraft.sh` — Apply performance optimizations and launch game
- `mine-revert.sh` — Revert to normal laptop mode

### What It Does

1. Sets CPU governor to **performance mode**
2. Enables **thermald** for thermal management
3. Stops background services (apache2, postgresql, tor)
4. Applies **Intel Mesa OpenGL overrides** (4.6 compatibility)
5. Launches Legacy Minecraft Launcher

### Usage

```bash
sudo ./minecraft.sh       # Start with optimizations
sudo ./mine-revert.sh     # Revert after playing
```

### What Gets Changed

| Setting | Gaming Mode | Normal Mode |
|---------|-------------|-------------|
| CPU Governor | `performance` | `powersave` |
| thermald | Enabled | Running |
| Background Services | Stopped | Restored |
| Mesa Overrides | GL 4.6 | Default |

### Requirements

```bash
sudo apt install thermald -y
# Download Legacy Launcher from: https://llaun.ch/en
```

---

## ⚡ Boot Optimization Script

**Disables non-essential services to significantly reduce boot time.**

### What It Does

Disables:
- Legacy networking services (uses NetworkManager)
- Firmware update daemons (run manually when needed)
- Automatic apt upgrades
- SMART monitoring (unless you use it)
- Docker auto-start (start manually when needed)

### Usage

```bash
chmod +x optimise.sh
sudo ./optimise.sh
sudo reboot
```

### Expected Improvement

- **Before:** 30–60 seconds
- **After:** 15–30 seconds (varies by hardware)

---

## 🔧 Essential Tools Installer

**One-command installation of all essential Kali Linux penetration testing tools.**

### Categories Installed

1. **Core Utilities:** neofetch, htop, btop, git, python3-pip, tmux
2. **Network Scanning:** nmap, masscan, rustscan, netcat, tcpdump
3. **Exploitation:** metasploit-framework, sqlmap, hydra, exploitdb
4. **Web Testing:** burpsuite, ffuf, gobuster, nikto, wfuzz
5. **Wireless:** aircrack-ng, bettercap, hcxdumptool, wifite
6. **Password Cracking:** john, hashcat, seclists, wordlists
7. **Reverse Engineering:** ghidra, radare2
8. **Steganography:** steghide, binwalk, sonic-visualiser
9. **Forensics:** volatility3
10. **Kali Meta Packages:** top10, web, wireless, passwords

### Usage

```bash
chmod +x tools.sh
sudo ./tools.sh
# Takes 20–40 minutes, ~3–5 GB download
```

---

## 📋 FAQ

### Ghost Profile

**Q: Why does the script exit immediately with no output?**  
A: Always run with `sudo bash ghost.sh` — not `sudo ./ghost.sh`. The script requires bash explicitly.

**Q: Tor won't start after configuring bridges.**  
A: Check `journalctl -u tor --no-pager | tail -30`. The bridge cert string must be exact. Get fresh bridges from [bridges.torproject.org](https://bridges.torproject.org).

**Q: Internet is completely dead after Ghost Mode.**  
A: This is expected — the kill-switch blocks all non-Tor traffic. Press `[R]` to restore, or manually flush iptables: `sudo iptables -F && sudo iptables -P OUTPUT ACCEPT`.

**Q: What's the difference between obfs4 and Shadowsocks?**  
A: obfs4 makes traffic look like random bytes (no protocol signature). Shadowsocks makes traffic look like encrypted TCP. For maximum stealth, use Shadowsocks → Tor (menu `[O]` → `[5]`).

**Q: Does Ghost Mode protect against nation-state surveillance?**  
A: Partial protection. Tor + traffic padding + obfs4 significantly raises the cost of de-anonymization but traffic correlation attacks by global adversaries remain theoretically possible. No tool provides absolute anonymity.

**Q: Can I run ghost.sh alongside other tools?**  
A: Yes. Once Ghost Mode is active, prefix any tool with `proxychains4` or `torsocks`. Use `ip netns exec ghost_ns` for full namespace isolation.

**Q: How do I check if DNS is leaking?**  
A: From the main menu `[4]` → `[8]`, or manually visit `https://dnsleaktest.com` in a proxychains-wrapped browser.

### Heartbeat Daemon

**Q: Why is there no sound?**  
A: Check audio files exist: `ls ~/tools/heartbeat/`. Test: `heartbeat test`. Check audio system: `aplay -l`.

**Q: Will this drain battery?**  
A: No. Audio uses <0.1% CPU. The script sleeps between beats.

**Q: How do I stop autostart on boot?**  
A: `systemctl --user disable heartbeat.service`

### Minecraft Optimizer

**Q: Do I need to run revert every time?**  
A: Yes — restores power-saving mode and background services including Tor.

**Q: Works on AMD/NVIDIA?**  
A: CPU/service optimizations work. Mesa overrides are Intel-specific.

### Boot Optimization

**Q: Will this break anything?**  
A: No. Only non-critical services are disabled. Re-enable any with `sudo systemctl enable <service>`.

### Tools Installer

**Q: Can I install selectively?**  
A: Yes — edit `tools.sh` and comment out unwanted `apt install` lines.

---

## 🐛 Troubleshooting

### Ghost Profile

```bash
# Script exits silently
sudo bash ghost.sh          # correct invocation

# Tor failed
journalctl -u tor --no-pager | tail -20
sudo sed -i '/## Ghost Profile/,/AutomapHostsOnResolve/d' /etc/tor/torrc

# No internet after Ghost Mode
sudo iptables -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo chattr -i /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

# Check anonymity status
# From menu: [S] → Status Dashboard
```

### Heartbeat Daemon

```bash
systemctl --user status heartbeat
ls -lh ~/tools/heartbeat/
/usr/local/bin/heartbeat test
aplay -l
```

### Minecraft

```bash
which legacylauncher
glxinfo | grep "OpenGL version"
cat /tmp/minecraft_stopped_services.txt
```

---

## ⚠️ Disclaimer

These scripts modify system settings, network configuration, and services. Always:
- Understand what each script does before running
- Use Ghost Profile **only on systems you own or have explicit written permission to test**
- Have backups of important data
- Test in a non-production environment first
- Use at your own risk

---

**By Naegleria**
