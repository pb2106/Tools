# 🛠️ My Tools Collection

A curated collection of system optimization, performance tuning, and biofeedback tools for Kali Linux.

---

## 📦 Contents

1. [Heartbeat Daemon](#-heartbeat-daemon) - Biofeedback-driven flow state audio system
2. [Minecraft Performance Optimizer](#-minecraft-performance-optimizer) - System tuning for gaming
3. [Boot Optimization Script](#-boot-optimization-script) - Faster boot times
4. [Essential Tools Installer](#-essential-tools-installer) - Complete Kali toolset setup

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
# Copy script to system location
sudo cp heartbeat.sh /usr/local/bin/heartbeat
sudo chmod +x /usr/local/bin/heartbeat
```

#### 3. Create Systemd User Service

```bash
# Create user systemd directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Create service file
nano ~/.config/systemd/user/heartbeat.service
```

**Paste this content** (adjust username if needed):

```ini
[Unit]
Description=Terminal Laptop Heartbeat Daemon
After=default.target

[Service]
Type=simple
ExecStart=/usr/local/bin/heartbeat start
ExecStop=/usr/local/bin/heartbeat stop
Restart=on-failure

# Ensure audio works in background
Environment=DISPLAY=:0
Environment=PULSE_SERVER=unix:/run/user/1000/pulse/native

# Silent logs
StandardOutput=null
StandardError=null

[Install]
WantedBy=default.target
```

#### 4. Enable and Start Service

```bash
# Reload systemd user daemon
systemctl --user daemon-reload

# Enable service to start on boot
systemctl --user enable heartbeat.service

# Start service now
systemctl --user start heartbeat.service
```

### Usage

**Manual Control:**

```bash
heartbeat start   # Start daemon
heartbeat stop    # Stop daemon
heartbeat status  # Check if running
heartbeat test    # Play 3-second demo of each state
heartbeat help    # Show help menu
```

**Service Control:**

```bash
systemctl --user start heartbeat    # Start service
systemctl --user stop heartbeat     # Stop service
systemctl --user restart heartbeat  # Restart service
systemctl --user status heartbeat   # Check status
```

### Dependencies

```bash
sudo apt install alsa-utils bc -y
```

### Resource Usage

- **RAM:** ~1-2 MB
- **CPU:** <0.1% (sleep-based, not polling)
- **No visual overhead** - pure audio

### Design Philosophy

This tool treats your laptop as a **living system** using sound alone as biofeedback to:
- Regulate focus and urgency without visual distraction
- Trigger flow states through rhythm entrainment
- Create subconscious awareness of battery state
- Avoid thermal overhead from GUI applications

---

## 🎮 Minecraft Performance Optimizer

**System tuning scripts for optimal Minecraft Java Edition performance on Intel graphics.**

### Files

- `minecraft.sh` - Apply performance optimizations and launch game
- `mine-revert.sh` - Revert to normal laptop mode

### What It Does

1. Sets CPU governor to **performance mode**
2. Enables **thermald** for thermal management
3. Stops background services (apache2, postgresql, tor)
4. Applies **Intel Mesa OpenGL overrides** (4.6 compatibility)
5. Launches Legacy Minecraft Launcher

### Installation

```bash
# Make scripts executable
chmod +x minecraft.sh mine-revert.sh

# Optional: Move to system path
sudo cp minecraft.sh /usr/local/bin/minecraft
sudo cp mine-revert.sh /usr/local/bin/minecraft-revert
```

### Usage

**Start Minecraft with optimizations:**

```bash
sudo ./minecraft.sh
# or if installed:
sudo minecraft
```

**Revert to normal mode after playing:**

```bash
sudo ./mine-revert.sh
# or if installed:
sudo minecraft-revert
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
# Install thermald (optional but recommended)
sudo apt install thermald -y

# Ensure Legacy Launcher is installed
# Download from: https://llaun.ch/en
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

# Reboot to see faster boot times
sudo reboot
```

### Revert Changes

If you need any service back:

```bash
# Example: Re-enable Docker
sudo systemctl enable docker.service containerd.service docker.socket
sudo systemctl start docker
```

### Expected Improvement

- **Before:** 30-60 seconds boot time
- **After:** 15-30 seconds boot time (varies by hardware)

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
```

**This will:**
- Update system packages
- Install all tools (~2-4 GB download)
- Unzip rockyou wordlist
- Take 20-40 minutes depending on connection

### Post-Installation

Verify installation:

```bash
# Check key tools
nmap --version
metasploit-framework --version
burpsuite --version
hashcat --version

# Check wordlist
ls -lh /usr/share/wordlists/rockyou.txt
```

---

## 📋 FAQ

### Heartbeat Daemon

**Q: Why is anxious state not playing sound?**  
A: Ensure `heartbeatloud.wav` exists and has proper volume boost. Test with `heartbeat test`.

**Q: Can I use this with headphones?**  
A: Yes, it works with any audio output. The sound is subtle enough for background use.

**Q: Will this drain my battery faster?**  
A: No. Audio playback uses <0.1% CPU. The script itself is extremely lightweight.

**Q: How do I stop it from starting on boot?**  
A: `systemctl --user disable heartbeat.service`

**Q: Can I customize the battery thresholds?**  
A: Yes, edit `/usr/local/bin/heartbeat` and adjust the `LEVEL` comparisons in the `start_heartbeat()` function.

### Minecraft Optimizer

**Q: Do I need to run revert script every time?**  
A: Yes, recommended to restore power-saving mode and background services.

**Q: Can I use this with official Minecraft launcher?**  
A: Yes, just replace `legacylauncher` command with `minecraft-launcher` in the script.

**Q: Will this work on AMD/NVIDIA graphics?**  
A: Partially. CPU/service optimizations work, but Mesa overrides are Intel-specific.

### Boot Optimization

**Q: Will this break my system?**  
A: No, it only disables non-critical services. You can re-enable them anytime.

**Q: I use Docker daily, should I still run this?**  
A: Skip the script or comment out the Docker lines before running.

### Tools Installer

**Q: Can I select specific tools only?**  
A: Yes, edit `tools.sh` and comment out unwanted `apt install` lines.

**Q: How much disk space is needed?**  
A: Approximately 3-5 GB for all tools.

---

## 🐛 Troubleshooting

### Heartbeat daemon not working

```bash
# Check if service is running
systemctl --user status heartbeat

# Check PID file
cat /tmp/heartbeat.pid
ps aux | grep heartbeat

# Check audio files exist
ls -lh ~/tools/heartbeat/

# Test manually
/usr/local/bin/heartbeat test

# Check audio system
aplay -l
speaker-test -t wav -c 2
```

### Minecraft won't launch

```bash
# Check if legacylauncher is in PATH
which legacylauncher

# Verify Mesa drivers
glxinfo | grep "OpenGL version"

# Check stopped services
cat /tmp/minecraft_stopped_services.txt
```

### Audio not working in headless/SSH

The heartbeat daemon requires local audio. If running over SSH:

```bash
# Forward PulseAudio (not recommended for this use case)
# Better: Run the service on the local machine only
```

---

## ⚠️ Disclaimer

These scripts modify system settings and services. Always:
- Understand what each script does before running
- Have backups of important data
- Test in a non-production environment first
- Use at your own risk

---

**By Naegleria**
