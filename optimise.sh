#!/bin/bash
# 🚀 Optimize Kali boot time by disabling non-essential services

# Disable legacy networking (use NetworkManager instead)
sudo systemctl disable networking.service
sudo systemctl disable ifupdown-pre.service

# Disable firmware update daemons (you can run manually when needed)
sudo systemctl disable fwupd.service fwupd-refresh.service

# Disable apt auto-upgrade checks
sudo systemctl disable apt-daily-upgrade.service packagekit.service

# Disable smartmontools (skip if you monitor disk health regularly)
sudo systemctl disable smartmontools.service

# Disable Docker auto-start (start manually when needed)
sudo systemctl disable docker.service containerd.service docker.socket

echo "[✔] Optimization applied! Reboot to see faster boot times."
