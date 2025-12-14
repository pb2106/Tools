#!/bin/bash
# Kali Bare Metal Ultimate Tool Installer (Final Slim Version)
# Run as: sudo ./kali-setup.sh

echo "[*] Updating system..."
apt update && apt full-upgrade -y

echo "[*] Installing core utilities..."
apt install -y neofetch fastfetch htop btop git python3-pip tmux curl wget net-tools iproute2

echo "[*] Installing networking & scanning tools..."
apt install -y nmap masscan netcat-openbsd tcpdump wireshark rustscan

echo "[*] Installing exploitation & frameworks..."
apt install -y metasploit-framework exploitdb sqlmap hydra medusa ncrack

echo "[*] Installing web & application testing tools..."
apt install -y burpsuite wfuzz gobuster ffuf nikto amass

echo "[*] Installing wireless & Bluetooth tools..."
apt install -y aircrack-ng bettercap hcxdumptool hashcat wifite bluez

echo "[*] Installing password & hash cracking tools..."
apt install -y john hashcat seclists wordlists

echo "[*] Installing reverse engineering tools..."
apt install -y ghidra radare2

echo "[*] Installing steganography & media analysis tools..."
apt install -y steghide stegseek binwalk sonic-visualiser

echo "[*] Installing single post-exploitation tool..."
apt install -y python3-impacket

echo "[*] Installing single forensics tool..."
apt install -y volatility3

echo "[*] Installing Kali meta packages..."
apt install -y kali-tools-top10 kali-tools-web kali-tools-wireless kali-tools-passwords

echo "[*] Unzipping rockyou wordlist..."
gunzip -f /usr/share/wordlists/rockyou.txt.gz || true

echo "[*] ✅ All tools installed! System ready."
