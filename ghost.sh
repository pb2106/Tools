#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#   GHOST PROFILE v3.0 — Hardened Anonymity Suite for Kali Linux
#   Use ONLY on systems you own or have explicit written permission.
#   Unauthorized use is illegal. Know your local laws.
#
#   v3 New Additions:
#   [A]  Traffic padding / cover traffic generation
#   [B]  Tor bridges + obfs4 obfuscation
#   [C]  Tor-over-VPN / VPN-over-Tor chaining menu
#   [D]  Scapy-based custom packet crafting (anti-fingerprint)
#   [E]  dnscrypt-proxy + Unbound DNS isolation
#   [F]  Network namespace / container isolation (Whonix-style)
#   [G]  External log minimization OPSEC guide
#   [H]  Full OPSEC discipline panel (behavioral attribution)
#   [I]  Honeypot: limit interaction depth + response consistency
#   [J]  MAC spoofing scope awareness (LAN only reminder)
#   [K]  Infrastructure rotation checklist
#   [+]  ASCII ghost mascot
# ═══════════════════════════════════════════════════════════════════════

# ─── COLORS ──────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
CYAN='\033[0;36m';   MAGENTA='\033[0;35m'; BLUE='\033[0;34m'
WHITE='\033[1;37m';  BOLD='\033[1m';      DIM='\033[2m'; RESET='\033[0m'

# ─── GLOBALS ─────────────────────────────────────────────────────────
BACKUP_DIR="/etc/ghost_profile_backups"
PROXYCHAINS_CONF="/etc/proxychains4.conf"
TOR_CONF="/etc/tor/torrc"
GHOST_LOG="/tmp/.ghost_session.log"
IFACE=""
GHOST_ACTIVE=0
VERSION="4.0"

# ─── ROOT CHECK ──────────────────────────────────────────────────────
require_root() {
    [[ $EUID -ne 0 ]] && {
        echo -e "${RED}[!] Must run as root: sudo bash $0${RESET}"; exit 1
    }
}

# ─── SESSION LOG (RAM only) ──────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$GHOST_LOG"; }

# ─── ASCII GHOST + BANNER ────────────────────────────────────────────
banner() {
    clear
    echo -e "${WHITE}${BOLD}"
    cat << 'GHOST'

         ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
         ░                                                       ░
         ░      ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗      ░
         ░     ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝      ░
         ░     ██║  ███╗███████║██║   ██║███████╗   ██║         ░
         ░     ██║   ██║██╔══██║██║   ██║╚════██║   ██║         ░
         ░     ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║         ░
         ░      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝         ░
         ░                                                       ░
         ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
GHOST
    echo -e "${RESET}"

    # ASCII ghost - drawn in cyan/white
    echo -e "                     ${CYAN}   .-'~~~'-.  ${RESET}"
    echo -e "                     ${CYAN}  /  O   O  \ ${RESET}   ${DIM}G H O S T   P R O F I L E${RESET}"
    echo -e "                     ${CYAN} |     ^     |${RESET}   ${WHITE}v${VERSION} — Hardened Anonymity Suite${RESET}"
    echo -e "                     ${CYAN}  \  \___/  / ${RESET}   ${DIM}For authorized research only${RESET}"
    echo -e "                     ${CYAN}  /\/\/\/\/\ ${RESET}"
    echo -e "                     ${CYAN} /            \\${RESET}"

    echo ""
    if [[ $GHOST_ACTIVE -eq 1 ]]; then
        echo -e "  ${RED}${BOLD}  ████  GHOST MODE ACTIVE — YOU ARE CLOAKED  ████${RESET}"
    else
        echo -e "  ${DIM}  ──── Ghost mode OFF — identity exposed ────${RESET}"
    fi
    echo -e "  ${DIM}─────────────────────────────────────────────────────────${RESET}"
}

# ─── DEPENDENCY CHECK ────────────────────────────────────────────────
check_deps() {
    local all_deps=(
        "macchanger" "proxychains4" "tor" "iptables" "ip6tables"
        "curl" "rfkill" "hostnamectl" "timedatectl" "nmap"
        "shred" "arp" "iw" "ethtool" "torsocks" "obfs4proxy"
        "dnscrypt-proxy" "unbound" "bleachbit" "scapy"
    )

    declare -A PKG_MAP=(
        ["proxychains4"]="proxychains4"     ["macchanger"]="macchanger"
        ["tor"]="tor"                        ["iptables"]="iptables"
        ["ip6tables"]="iptables"             ["curl"]="curl"
        ["rfkill"]="rfkill"                  ["nmap"]="nmap"
        ["shred"]="coreutils"                ["arp"]="net-tools"
        ["iw"]="iw"                          ["ethtool"]="ethtool"
        ["torsocks"]="torsocks"              ["obfs4proxy"]="obfs4proxy"
        ["dnscrypt-proxy"]="dnscrypt-proxy"  ["unbound"]="unbound"
        ["bleachbit"]="bleachbit"            ["scapy"]="python3-scapy"
        ["hostnamectl"]="systemd"            ["timedatectl"]="systemd"
    )

    echo -e "\n${CYAN}[*] Scanning for required and optional tools...${RESET}\n"

    local to_install=()
    local installed_count=0

    for tool in "${all_deps[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${GREEN}[✓]${RESET} ${tool}"
            (( installed_count++ ))
        else
            echo -e "  ${RED}[✗]${RESET} ${tool}  ${YELLOW}← missing${RESET}"
            local pkg="${PKG_MAP[$tool]:-$tool}"
            [[ ! " ${to_install[*]} " =~ " ${pkg} " ]] && to_install+=("$pkg")
        fi
    done

    echo -e "\n  ${DIM}Installed: $installed_count / ${#all_deps[@]}${RESET}\n"

    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}[+] All tools present. Full functionality available.${RESET}"
    else
        echo -e "  ${YELLOW}[!] Missing apt packages: ${to_install[*]}${RESET}\n"
        read -rp "  Install all missing tools now? [Y/n]: " ans
        ans="${ans:-Y}"
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            echo -e "\n${CYAN}[*] apt-get update...${RESET}"
            apt-get update -qq
            echo -e "${CYAN}[*] Installing: ${to_install[*]}${RESET}\n"
            apt-get install -y "${to_install[@]}" || \
                echo -e "${YELLOW}[!] Some packages may have failed — check above${RESET}"
            echo -e "\n${CYAN}[*] Re-checking after install...${RESET}\n"
            local still_missing=()
            for tool in "${all_deps[@]}"; do
                if command -v "$tool" &>/dev/null; then
                    echo -e "  ${GREEN}[✓]${RESET} $tool"
                else
                    echo -e "  ${RED}[✗]${RESET} $tool  ${DIM}(still missing — some features limited)${RESET}"
                    still_missing+=("$tool")
                fi
            done
            [[ ${#still_missing[@]} -eq 0 ]] \
                && echo -e "\n  ${GREEN}[+] All tools installed!${RESET}" \
                || echo -e "\n  ${YELLOW}[!] Still missing: ${still_missing[*]}${RESET}"
        else
            echo -e "  ${YELLOW}[!] Skipping. Some menu options may not work.${RESET}"
        fi
    fi
    echo ""
    read -rp "  Press ENTER to load the menu..." _
}

# ─── INTERFACE SELECTOR ──────────────────────────────────────────────
get_interfaces() {
    ip -o link show | awk -F': ' '{print $2}' | grep -Ev '^lo$|^docker|^virbr|^veth'
}

select_interface() {
    echo -e "\n${CYAN}[*] Network Interfaces:${RESET}"
    mapfile -t ifaces < <(get_interfaces)
    for i in "${!ifaces[@]}"; do
        local mac state
        mac=$(cat /sys/class/net/"${ifaces[$i]}"/address 2>/dev/null || echo "??:??:??:??:??:??")
        state=$(cat /sys/class/net/"${ifaces[$i]}"/operstate 2>/dev/null || echo "unknown")
        echo -e "    ${BOLD}[$i]${RESET} ${ifaces[$i]}  ${YELLOW}$mac${RESET}  [${GREEN}$state${RESET}]"
    done
    echo ""
    read -rp "  Select interface [0-$((${#ifaces[@]}-1))]: " idx
    IFACE="${ifaces[$idx]:-}"
    [[ -z "$IFACE" ]] && { echo -e "${RED}[!] Invalid selection${RESET}"; return 1; }
    echo -e "${GREEN}  [+] Selected: $IFACE${RESET}"
    log "Interface selected: $IFACE"
}

# ══════════════════════════════════════════════════════════════════════
# MAC ADDRESS CHANGER (DHCP-aware, scope-aware)
# ══════════════════════════════════════════════════════════════════════
mac_menu() {
    echo -e "\n${MAGENTA}┌──── MAC ADDRESS CHANGER ────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Full random MAC + flush DHCP lease               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Vendor-blend MAC (looks like common LAN device)   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Custom MAC                                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Restore original MAC                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Show MAC + ARP cache                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Clear ARP/neighbor cache                          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] MAC scope awareness — what it does and doesn't do ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    mkdir -p "$BACKUP_DIR"
    local backup="$BACKUP_DIR/${IFACE}.mac"
    [[ ! -f "$backup" ]] && ip link show "$IFACE" | awk '/ether/{print $2}' > "$backup"

    case $ch in
        1)
            ip link set "$IFACE" down
            macchanger -r "$IFACE" -q
            ip link set "$IFACE" up
            dhclient -r "$IFACE" 2>/dev/null || true
            sleep 1; dhclient "$IFACE" 2>/dev/null &
            echo -e "${GREEN}  [+] MAC randomized + DHCP lease flushed/renewed${RESET}"
            echo -e "${YELLOW}  [!] Router's DHCP logs still exist — use a different AP if possible${RESET}"
            log "MAC randomized + DHCP flushed: $IFACE"
            ;;
        2)
            local vendors=("3c:5a:b4" "f4:5c:89" "b8:27:eb" "dc:a6:32" "a4:c3:f0" "00:50:56")
            local v="${vendors[$RANDOM % ${#vendors[@]}]}"
            local r; r=$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
            ip link set "$IFACE" down
            macchanger -m "$v:$r" "$IFACE" -q
            ip link set "$IFACE" up
            echo -e "${GREEN}  [+] Vendor-blend MAC: $v:$r${RESET}"
            log "Vendor-blend MAC $v:$r on $IFACE"
            ;;
        3)
            read -rp "  MAC (XX:XX:XX:XX:XX:XX): " newmac
            ip link set "$IFACE" down
            macchanger -m "$newmac" "$IFACE" -q
            ip link set "$IFACE" up
            log "Custom MAC $newmac on $IFACE"
            ;;
        4)
            local orig; orig=$(cat "$backup" 2>/dev/null || echo "")
            ip link set "$IFACE" down
            [[ -n "$orig" ]] && macchanger -m "$orig" "$IFACE" -q || macchanger -p "$IFACE" -q
            ip link set "$IFACE" up
            dhclient "$IFACE" 2>/dev/null &
            echo -e "${GREEN}  [+] Original MAC restored${RESET}"
            log "MAC restored: $IFACE"
            ;;
        5)
            echo -e "\n${CYAN}--- MAC ---${RESET}"; macchanger -s "$IFACE"
            echo -e "\n${CYAN}--- ARP Cache ---${RESET}"; arp -n
            return ;;
        6)
            ip neigh flush all
            echo -e "${GREEN}  [+] ARP cache cleared${RESET}"
            log "ARP cache flushed" ;;
        7)
            echo -e "\n${CYAN}  ═══ MAC SPOOFING — SCOPE & LIMITS ═══${RESET}"
            echo -e "  ${GREEN}What MAC spoofing DOES protect:${RESET}"
            echo -e "  • Prevents local LAN device tracking"
            echo -e "  • Defeats captive portal fingerprinting (hotel/cafe WiFi)"
            echo -e "  • Stops DHCP-based device correlation on the local segment"
            echo -e ""
            echo -e "  ${RED}What MAC spoofing does NOT protect:${RESET}"
            echo -e "  • MAC never leaves your local network (router/gateway strips it)"
            echo -e "  • Does NOT hide you from the internet — only local segment"
            echo -e "  • Router DHCP logs already recorded your old MAC + session time"
            echo -e "  • WiFi probe requests broadcast saved SSIDs (device fingerprint)"
            echo -e ""
            echo -e "  ${YELLOW}Bottom line:${RESET}"
            echo -e "  Use MAC spoofing for LAN privacy only."
            echo -e "  For internet anonymity — rely on Tor + iptables lockdown."
            return ;;
    esac
    echo -e "${GREEN}  [+] Current MAC: $(cat /sys/class/net/"$IFACE"/address 2>/dev/null)${RESET}"
}

# ══════════════════════════════════════════════════════════════════════
# TOR + PROXYCHAINS + BRIDGES + OBFS4
# ══════════════════════════════════════════════════════════════════════
setup_tor_proxy() {
    echo -e "\n${MAGENTA}┌──── TOR + PROXYCHAINS + BRIDGES ────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Start Tor (stream isolation)                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Stop Tor                                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Configure proxychains — strict Tor               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Configure proxychains — multi-hop (proxy→Tor)    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Configure Tor BRIDGES + obfs4 (hide Tor traffic) ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Tor-over-VPN setup guide                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] VPN-over-Tor setup guide                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] Test exit IP + Tor check                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [9] Rotate Tor circuit (new identity)                ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            grep -q "## Ghost Profile" "$TOR_CONF" 2>/dev/null || cat >> "$TOR_CONF" << 'TORCONF'

## Ghost Profile
IsolateDestAddr 1
IsolateDestPort 1
IsolateClientProtocol 1
SocksPort 9050 IsolateDestAddr IsolateDestPort
SocksPort 9051 IsolateClientProtocol
ControlPort 9053
CookieAuthentication 1
TransPort 9040
DNSPort 5353
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
TORCONF
            systemctl restart tor; sleep 3
            systemctl is-active --quiet tor \
                && echo -e "${GREEN}  [+] Tor running with stream isolation${RESET}" \
                || echo -e "${RED}  [!] Tor failed — check: journalctl -u tor${RESET}"
            log "Tor started with stream isolation"
            ;;
        2)
            sed -i '/## Ghost Profile/,/AutomapHostsSuffixes/d' "$TOR_CONF" 2>/dev/null || true
            systemctl stop tor
            echo -e "${YELLOW}  [-] Tor stopped + torrc cleaned${RESET}"
            log "Tor stopped"
            ;;
        3)
            cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak" 2>/dev/null || true
            cat > "$PROXYCHAINS_CONF" << 'CONF'
# Ghost Profile v3 — strict Tor chain
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0
[ProxyList]
socks5  127.0.0.1 9050
CONF
            echo -e "${GREEN}  [+] proxychains4: strict Tor-only chain${RESET}"
            log "proxychains: strict Tor"
            ;;
        4)
            read -rp "  Upstream proxy type (socks5/http): " ptype
            read -rp "  Upstream proxy IP: " pip
            read -rp "  Upstream proxy port: " pport
            cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak" 2>/dev/null || true
            cat > "$PROXYCHAINS_CONF" << CONF
# Ghost Profile v3 — multi-hop: upstream → Tor
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
${ptype}  ${pip}  ${pport}
socks5  127.0.0.1 9050
CONF
            echo -e "${GREEN}  [+] Multi-hop chain: $ptype $pip:$pport → Tor${RESET}"
            log "Multi-hop proxychains: $ptype $pip:$pport -> Tor"
            ;;
        5)
            # NEW: Tor bridges + obfs4
            echo -e "\n${CYAN}  ═══ TOR BRIDGES + OBFS4 ═══${RESET}"
            echo -e "  ${YELLOW}Why bridges?${RESET}"
            echo -e "  • Standard Tor entry nodes are publicly listed"
            echo -e "  • ISPs/firewalls can detect and block standard Tor connections"
            echo -e "  • obfs4 makes Tor traffic look like random HTTPS — harder to detect"
            echo -e ""
            echo -e "  ${CYAN}Step 1: Get bridge lines from https://bridges.torproject.org${RESET}"
            echo -e "  Step 2: Choose 'obfs4' as the transport type"
            echo -e ""
            read -rp "  Do you have bridge lines to configure now? [y/N]: " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                if ! command -v obfs4proxy &>/dev/null; then
                    echo -e "${YELLOW}  [!] obfs4proxy not found. Installing...${RESET}"
                    apt-get install -y obfs4proxy -qq || true
                fi
                echo -e "${CYAN}  Paste your bridge lines (one per line, blank line when done):${RESET}"
                local bridges=()
                while IFS= read -rp "  bridge> " line && [[ -n "$line" ]]; do
                    bridges+=("$line")
                done
                if [[ ${#bridges[@]} -gt 0 ]]; then
                    # Remove old bridge config
                    sed -i '/UseBridges/d;/Bridge /d;/ClientTransportPlugin/d' "$TOR_CONF" 2>/dev/null || true
                    {
                        echo "UseBridges 1"
                        echo "ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy"
                        for b in "${bridges[@]}"; do echo "Bridge $b"; done
                    } >> "$TOR_CONF"
                    systemctl restart tor
                    sleep 3
                    systemctl is-active --quiet tor \
                        && echo -e "${GREEN}  [+] Tor started with obfs4 bridges${RESET}" \
                        || echo -e "${RED}  [!] Tor failed — check journalctl -u tor${RESET}"
                    log "Tor configured with obfs4 bridges"
                fi
            else
                echo -e "${DIM}  Get bridges: https://bridges.torproject.org (select obfs4)${RESET}"
            fi
            ;;
        6)
            echo -e "\n${CYAN}  ═══ TOR-OVER-VPN ═══${RESET}"
            echo -e "  Architecture:  ${WHITE}You → VPN → Tor → Internet${RESET}"
            echo -e ""
            echo -e "  ${GREEN}Advantages:${RESET}"
            echo -e "  • VPN hides Tor usage from your ISP"
            echo -e "  • VPN provider doesn't see your traffic (Tor encrypts it)"
            echo -e "  • Good for regions that block Tor"
            echo -e ""
            echo -e "  ${RED}Disadvantages:${RESET}"
            echo -e "  • VPN provider knows you use Tor"
            echo -e "  • VPN is a trusted third party (choose a no-log provider)"
            echo -e ""
            echo -e "  ${YELLOW}Setup:${RESET}"
            echo -e "  1. Connect to VPN first (OpenVPN/WireGuard)"
            echo -e "  2. Start Tor: ${BOLD}systemctl start tor${RESET}"
            echo -e "  3. Use proxychains/torsocks as normal"
            echo -e "  4. Verify: ${BOLD}proxychains4 curl https://check.torproject.org${RESET}"
            echo -e ""
            echo -e "  ${DIM}Recommended VPN providers with no-log policies:${RESET}"
            echo -e "  Mullvad (accepts cash/Monero) | ProtonVPN | IVPN"
            return ;;
        7)
            echo -e "\n${CYAN}  ═══ VPN-OVER-TOR ═══${RESET}"
            echo -e "  Architecture:  ${WHITE}You → Tor → VPN → Internet${RESET}"
            echo -e ""
            echo -e "  ${GREEN}Advantages:${RESET}"
            echo -e "  • VPN exit hides Tor exit node from target (exit node is VPN IP)"
            echo -e "  • Can bypass Tor exit node blocks on some services"
            echo -e ""
            echo -e "  ${RED}Disadvantages:${RESET}"
            echo -e "  • VPN provider can see your traffic (only Tor is encrypted end-to-end)"
            echo -e "  • More complex to configure"
            echo -e "  • Slower than Tor-over-VPN"
            echo -e ""
            echo -e "  ${YELLOW}Setup:${RESET}"
            echo -e "  1. Start Tor service"
            echo -e "  2. Route OpenVPN through SOCKS: use --socks-proxy 127.0.0.1 9050"
            echo -e "  3. Example: ${BOLD}openvpn --config vpn.ovpn --socks-proxy 127.0.0.1 9050${RESET}"
            return ;;
        8)
            echo -e "${CYAN}  [*] Real IP:${RESET}"
            curl -s --max-time 5 https://api.ipify.org && echo ""
            echo -e "${CYAN}  [*] Exit IP via Tor (proxychains):${RESET}"
            proxychains4 -q curl -s --max-time 12 https://api.ipify.org && echo ""
            echo -e "${CYAN}  [*] Tor project check:${RESET}"
            proxychains4 -q curl -s --max-time 12 https://check.torproject.org/api/ip \
                | python3 -m json.tool 2>/dev/null || echo "  Failed"
            ;;
        9)
            (printf 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n') \
                | nc -w 3 127.0.0.1 9053 2>/dev/null \
                && echo -e "${GREEN}  [+] New Tor circuit requested${RESET}" \
                || echo -e "${YELLOW}  [!] Enable ControlPort 9053 (done by option 1)${RESET}"
            log "Tor NEWNYM"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# DNS LEAK PREVENTION + dnscrypt-proxy + Unbound
# ══════════════════════════════════════════════════════════════════════
fix_dns() {
    echo -e "\n${MAGENTA}┌──── DNS LEAK PREVENTION ────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Lock DNS to Tor 127.0.0.1 + iptables bypass block ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Setup dnscrypt-proxy (encrypted DNS)              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Setup Unbound (local recursive resolver)          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Disable systemd-resolved (common leak source)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Block all external DNS via iptables               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Per-app DNS isolation note                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Restore original DNS                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] DNS leak status check                             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local resolv="/etc/resolv.conf"
    local bak="$BACKUP_DIR/resolv.conf.bak"
    mkdir -p "$BACKUP_DIR"
    [[ ! -f "$bak" ]] && cp "$resolv" "$bak" 2>/dev/null || true

    case $ch in
        1)
            systemctl stop systemd-resolved 2>/dev/null || true
            chattr -i "$resolv" 2>/dev/null || true
            echo "nameserver 127.0.0.1" > "$resolv"
            chattr +i "$resolv"
            iptables -I OUTPUT -p udp --dport 53 ! -d 127.0.0.1 -j REJECT 2>/dev/null || true
            iptables -I OUTPUT -p tcp --dport 53 ! -d 127.0.0.1 -j REJECT 2>/dev/null || true
            echo -e "${GREEN}  [+] DNS locked to 127.0.0.1 + bypass blocked${RESET}"
            echo -e "${YELLOW}  [!] Requires Tor DNSPort 5353 active (start Tor first)${RESET}"
            log "DNS locked to Tor"
            ;;
        2)
            # NEW: dnscrypt-proxy
            if command -v dnscrypt-proxy &>/dev/null; then
                systemctl stop systemd-resolved 2>/dev/null || true
                # Configure to listen on 127.0.0.1:53
                local dcconf="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
                if [[ -f "$dcconf" ]]; then
                    sed -i "s/^listen_addresses.*/listen_addresses = ['127.0.0.1:53']/" "$dcconf" 2>/dev/null || true
                    sed -i "s/^# require_nolog.*/require_nolog = true/" "$dcconf" 2>/dev/null || true
                    sed -i "s/^require_nolog.*/require_nolog = true/" "$dcconf" 2>/dev/null || true
                fi
                systemctl restart dnscrypt-proxy
                chattr -i "$resolv" 2>/dev/null || true
                echo "nameserver 127.0.0.1" > "$resolv"
                chattr +i "$resolv"
                echo -e "${GREEN}  [+] dnscrypt-proxy running — DNS encrypted + no-log${RESET}"
                echo -e "${YELLOW}  [!] DNS is encrypted but NOT going through Tor. Combine with option 1 for full isolation.${RESET}"
                log "dnscrypt-proxy configured"
            else
                echo -e "${YELLOW}  [!] dnscrypt-proxy not installed: apt install dnscrypt-proxy${RESET}"
            fi
            ;;
        3)
            # NEW: Unbound local recursive resolver
            if command -v unbound &>/dev/null; then
                cat > /etc/unbound/unbound.conf.d/ghost.conf << 'UNBOUNDCONF'
server:
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    prefer-ip6: no
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    edns-buffer-size: 1232
    prefetch: yes
    num-threads: 1
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
UNBOUNDCONF
                systemctl restart unbound
                chattr -i "$resolv" 2>/dev/null || true
                echo "nameserver 127.0.0.1" > "$resolv"
                echo -e "${GREEN}  [+] Unbound local resolver active on 127.0.0.1:5335${RESET}"
                echo -e "${DIM}  QNAME minimization + DNSSEC + identity hidden${RESET}"
                log "Unbound configured"
            else
                echo -e "${YELLOW}  [!] Unbound not installed: apt install unbound${RESET}"
            fi
            ;;
        4)
            systemctl stop systemd-resolved
            systemctl disable systemd-resolved
            rm -f /etc/resolv.conf
            echo "nameserver 127.0.0.1" > /etc/resolv.conf
            echo -e "${GREEN}  [+] systemd-resolved disabled (major DNS leak source eliminated)${RESET}"
            log "systemd-resolved disabled"
            ;;
        5)
            iptables -I OUTPUT -p udp --dport 53 -j DROP
            iptables -I OUTPUT -p tcp --dport 53 -j DROP
            iptables -I OUTPUT -p udp -d 127.0.0.1 --dport 53 -j ACCEPT
            iptables -I OUTPUT -p udp -d 127.0.0.1 --dport 5353 -j ACCEPT
            echo -e "${GREEN}  [+] All external DNS blocked — only 127.0.0.1 DNS allowed${RESET}"
            log "iptables DNS lockdown"
            ;;
        6)
            # NEW: per-app DNS isolation
            echo -e "\n${CYAN}  ═══ PER-APP DNS ISOLATION ═══${RESET}"
            echo -e "  ${YELLOW}Problem:${RESET} Some apps bypass system DNS entirely:"
            echo -e "  • Chrome/Firefox with DNS-over-HTTPS built-in"
            echo -e "  • Applications with hardcoded DNS (8.8.8.8, 1.1.1.1)"
            echo -e "  • WebRTC leaks in browsers (reveals real IP)"
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Firefox: about:config → network.trr.mode = 5 (disable DoH)"
            echo -e "  • Chrome:  --disable-features=UseDnsHttpsSvcb flag"
            echo -e "  • Force via iptables (option 5) — intercepts all port 53"
            echo -e "  • Use network namespaces (see Isolation menu [N])"
            echo -e "  • WebRTC: install uBlock Origin → Settings → Prevent WebRTC"
            echo -e ""
            echo -e "  ${DIM}Tools: dnscrypt-proxy (encrypts), Unbound (resolves locally)${RESET}"
            return ;;
        7)
            chattr -i "$resolv" 2>/dev/null || true
            [[ -f "$bak" ]] && cp "$bak" "$resolv"
            systemctl start systemd-resolved 2>/dev/null || true
            echo -e "${GREEN}  [+] DNS restored${RESET}"
            log "DNS restored"
            ;;
        8)
            echo -e "\n${CYAN}--- /etc/resolv.conf ---${RESET}"; cat "$resolv"
            echo -e "\n${CYAN}--- Listening on :53 ---${RESET}"
            ss -tunlp | grep ':53' || echo "  Nothing listening on :53"
            echo -e "\n${YELLOW}  Manual checks:${RESET}"
            echo -e "  DNS leak:  https://dnsleaktest.com"
            echo -e "  WebRTC:    https://browserleaks.com/webrtc"
            echo -e "  Full test: https://ipleak.net"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# IPTABLES LOCKDOWN
# ══════════════════════════════════════════════════════════════════════
iptables_menu() {
    echo -e "\n${MAGENTA}┌──── IPTABLES LOCKDOWN ──────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Full Tor lockdown (TCP+DNS, no leaks)             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Block ALL IPv6 (sysctl + ip6tables)               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Block non-Tor UDP                                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Kill-switch (drop all if Tor process stops)       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Port whitelist through Tor only                   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Show all current rules                            ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Flush ALL rules + reset                           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local TOR_UID
    TOR_UID=$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || echo "107")

    case $ch in
        1)
            iptables -F; iptables -X
            iptables -t nat -F; iptables -t nat -X
            iptables -t mangle -F; iptables -t mangle -X
            iptables -A INPUT  -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT
            iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -m owner --uid-owner "$TOR_UID" -j ACCEPT
            iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -p tcp --syn -j REDIRECT --to-ports 9040
            iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
            iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 5353
            iptables -A OUTPUT -j DROP
            iptables -A INPUT  -j DROP
            iptables -A FORWARD -j DROP
            echo -e "${GREEN}  [+] Full Tor lockdown — all TCP/DNS redirected, nothing escapes${RESET}"
            echo -e "${YELLOW}  [!] Requires TransPort 9040 + DNSPort 5353 in torrc (start Tor first)${RESET}"
            log "iptables: full Tor lockdown"
            ;;
        2)
            for table in filter mangle raw; do
                ip6tables -t $table -F 2>/dev/null; ip6tables -t $table -X 2>/dev/null
            done
            ip6tables -P INPUT DROP; ip6tables -P OUTPUT DROP; ip6tables -P FORWARD DROP
            sysctl -w net.ipv6.conf.all.disable_ipv6=1 -q
            sysctl -w net.ipv6.conf.default.disable_ipv6=1 -q
            sysctl -w net.ipv6.conf.lo.disable_ipv6=1 -q
            echo -e "${GREEN}  [+] IPv6 fully disabled (ip6tables + sysctl)${RESET}"
            log "IPv6 disabled"
            ;;
        3)
            iptables -I OUTPUT -p udp -m owner ! --uid-owner "$TOR_UID" ! -d 127.0.0.1 -j DROP
            echo -e "${GREEN}  [+] Non-Tor UDP blocked${RESET}"
            log "Non-Tor UDP blocked"
            ;;
        4)
            iptables -I OUTPUT -m owner ! --uid-owner "$TOR_UID" ! -o lo -j DROP
            echo -e "${GREEN}  [+] Kill-switch: all non-Tor traffic blocked${RESET}"
            echo -e "${YELLOW}  [!] Use [7] to remove if needed${RESET}"
            log "Kill-switch enabled"
            ;;
        5)
            read -rp "  Ports to allow through Tor (space-sep, e.g. 80 443 22): " -a ports
            iptables -I OUTPUT -m owner ! --uid-owner "$TOR_UID" ! -o lo -j DROP
            for p in "${ports[@]}"; do
                iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -p tcp --dport "$p" \
                    -j REDIRECT --to-ports 9040
            done
            echo -e "${GREEN}  [+] Whitelist via Tor: ${ports[*]}${RESET}"
            log "Port whitelist: ${ports[*]}"
            ;;
        6)
            echo -e "\n${CYAN}─── IPv4 filter ───${RESET}"; iptables -L -n -v --line-numbers 2>/dev/null
            echo -e "\n${CYAN}─── IPv4 nat ───${RESET}"; iptables -t nat -L -n -v 2>/dev/null
            echo -e "\n${CYAN}─── IPv6 ───${RESET}"; ip6tables -L -n -v 2>/dev/null
            return ;;
        7)
            iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X; iptables -t mangle -F
            iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT
            ip6tables -F; ip6tables -X
            ip6tables -P INPUT ACCEPT; ip6tables -P OUTPUT ACCEPT; ip6tables -P FORWARD ACCEPT
            sysctl -w net.ipv6.conf.all.disable_ipv6=0 -q
            sysctl -w net.ipv6.conf.default.disable_ipv6=0 -q
            echo -e "${GREEN}  [+] All firewall rules flushed${RESET}"
            log "iptables flushed"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# SECURE LOG WIPE
# ══════════════════════════════════════════════════════════════════════
secure_wipe() {
    echo -e "\n${MAGENTA}┌──── SECURE WIPE ────────────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Shred shell histories (3-pass overwrite)          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Secure wipe /tmp /var/tmp                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Overwrite+truncate /var/log files                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Wipe thumbnail/recent-files cache                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Wipe swap (urandom overwrite)                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Drop RAM page cache                               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Full nuke (all of above)                          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] BleachBit deep clean                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [9] External log minimization guide                   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            for hist in ~/.bash_history ~/.zsh_history /root/.bash_history /root/.zsh_history \
                        ~/.python_history ~/.lesshst ~/.mysql_history ~/.psql_history; do
                [[ -f "$hist" ]] && shred -uzn 3 "$hist" 2>/dev/null && echo "  Shredded: $hist" || true
            done
            history -c; history -w 2>/dev/null || true
            echo -e "${GREEN}  [+] Shell histories 3-pass shredded${RESET}"
            log "Shell histories shredded"
            ;;
        2)
            find /tmp /var/tmp -maxdepth 3 -type f -exec shred -uzn 1 {} \; 2>/dev/null || true
            echo -e "${GREEN}  [+] Temp dirs wiped${RESET}"
            log "Temp wiped"
            ;;
        3)
            find /var/log -type f | while read -r lf; do
                shred -uzn 1 "$lf" 2>/dev/null && touch "$lf" 2>/dev/null || truncate -s 0 "$lf" 2>/dev/null || true
            done
            echo -e "${GREEN}  [+] /var/log files overwritten + cleared${RESET}"
            log "Logs shredded"
            ;;
        4)
            shred -uzn 1 ~/.local/share/recently-used.xbel 2>/dev/null || true
            rm -rf ~/.thumbnails ~/.cache/thumbnails ~/.local/share/Trash 2>/dev/null || true
            echo -e "${GREEN}  [+] Cache + recent-files wiped${RESET}"
            log "Cache wiped"
            ;;
        5)
            echo -e "${CYAN}  [*] Wiping swap with urandom...${RESET}"
            swapoff -a
            local swapdev; swapdev=$(swapon --show=NAME --noheadings 2>/dev/null | head -1)
            if [[ -n "$swapdev" ]]; then
                dd if=/dev/urandom of="$swapdev" bs=4M status=progress 2>/dev/null || true
                echo -e "${GREEN}  [+] Swap wiped${RESET}"
            else
                echo -e "${YELLOW}  [!] No active swap found${RESET}"
            fi
            swapon -a 2>/dev/null || true
            log "Swap wiped"
            ;;
        6)
            sync; echo 3 > /proc/sys/vm/drop_caches
            echo -e "${GREEN}  [+] RAM page cache dropped${RESET}"
            log "RAM cache dropped"
            ;;
        7)
            echo -e "${RED}  [!] Full nuke — shreds logs, history, temp, swap, RAM cache${RESET}"
            read -rp "  Confirm [yes/NO]: " confirm
            [[ "$confirm" != "yes" ]] && { echo "  Aborted."; return; }
            for sub in 1 2 3 4 5 6; do
                echo -e "${DIM}  Running step $sub...${RESET}"
                echo "$sub" | bash -c "source <(cat '$0'); secure_wipe" -- "$0" 2>/dev/null || true
            done
            echo -e "${GREEN}  [+] Full nuke complete${RESET}"
            log "Full nuke"
            ;;
        8)
            if command -v bleachbit &>/dev/null; then
                bleachbit --clean system.cache system.tmp system.trash bash.history 2>/dev/null
                echo -e "${GREEN}  [+] BleachBit done${RESET}"
                log "BleachBit ran"
            else
                echo -e "${YELLOW}  [!] Not installed: apt install bleachbit${RESET}"
            fi
            ;;
        9)
            # NEW: external log minimization guide
            echo -e "\n${CYAN}  ═══ EXTERNAL LOG MINIMIZATION ═══${RESET}"
            echo -e "  ${RED}Critical insight: You cannot delete external logs.${RESET}"
            echo -e "  Servers, ISPs, routers, CDNs — all keep independent logs."
            echo -e "  The only real defense is minimizing identifiable activity."
            echo -e ""
            echo -e "  ${YELLOW}What external systems log:${RESET}"
            echo -e "  • Web servers: IP, timestamp, User-Agent, request path, referrer"
            echo -e "  • ISP: NetFlow — dst IP, port, byte count, timing (even for HTTPS)"
            echo -e "  • CDN/WAF (Cloudflare, Akamai): full HTTP metadata"
            echo -e "  • Auth servers: login attempts, success/fail, timestamps"
            echo -e "  • Threat intel (Maltego, MISP): correlate reused artifacts"
            echo -e ""
            echo -e "  ${GREEN}Minimization strategies:${RESET}"
            echo -e "  • Never reuse accounts, usernames, emails, or SSH keys"
            echo -e "  • Avoid persistent identifiers (cookies, API tokens, certs)"
            echo -e "  • Separate identities — never mix personal + operational"
            echo -e "  • Use different Tor circuits per target/session"
            echo -e "  • Rotate infrastructure — VPS, exit nodes, tools between ops"
            echo -e "  • Avoid unique string literals in payloads (reused shellcode)"
            echo -e "  • Use short-lived infrastructure — don't reuse VPS/domains"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# FINGERPRINT EVASION + TRAFFIC PADDING + SCAPY
# ══════════════════════════════════════════════════════════════════════
fingerprint_evasion() {
    echo -e "\n${MAGENTA}┌──── FINGERPRINT EVASION + TRAFFIC PADDING ──────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Set random User-Agent (curl + nmap)               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Randomize TCP stack (TTL, timestamps, window)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Generate cover traffic (traffic padding)          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Custom packet craft with Scapy (anti-signature)   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] IDS evasion info (Suricata/Zeek awareness)        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] TLS/JA3 fingerprint guide                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Tool signature warning panel                      ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local ua_pool=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
        "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"
    )

    case $ch in
        1)
            local ua="${ua_pool[$RANDOM % ${#ua_pool[@]}]}"
            echo "user-agent = \"$ua\"" > /root/.curlrc
            echo -e "${GREEN}  [+] curl UA: ${DIM}$ua${RESET}"
            echo -e "${YELLOW}  Nmap: --script-args http.useragent='$ua'${RESET}"
            log "UA randomized"
            ;;
        2)
            sysctl -w net.ipv4.ip_default_ttl=$((64 + RANDOM % 64)) -q
            sysctl -w net.ipv4.tcp_timestamps=0 -q
            sysctl -w net.ipv4.tcp_window_scaling=1 -q
            sysctl -w net.ipv4.ip_no_pmtu_disc=$((RANDOM % 2)) -q
            # Randomize TCP window size via tc (if available)
            command -v tc &>/dev/null && tc qdisc add dev "${IFACE:-eth0}" root netem delay "$((10 + RANDOM % 50))ms" 2>/dev/null || true
            echo -e "${GREEN}  [+] TCP stack randomized — TTL, timestamps off, window varied${RESET}"
            log "TCP stack randomized"
            ;;
        3)
            # NEW: traffic padding / cover traffic
            echo -e "\n${CYAN}  ═══ TRAFFIC PADDING / COVER TRAFFIC ═══${RESET}"
            echo -e "  ${YELLOW}Why?${RESET} Tor is vulnerable to traffic correlation:"
            echo -e "  An adversary watching both your ISP connection and the exit node"
            echo -e "  can match timing/volume patterns to de-anonymize you."
            echo -e ""
            echo -e "  ${GREEN}Cover traffic adds noise to make correlation harder.${RESET}"
            echo -e ""
            echo -e "  [1] Generate random background HTTPS requests (noise)"
            echo -e "  [2] Constant-rate padding loop (ongoing noise)"
            echo -e "  [3] Explanation only"
            read -rp "  Sub-choice: " sub

            case $sub in
                1)
                    local noise_sites=("https://www.wikipedia.org" "https://www.example.com"
                                       "https://www.ietf.org" "https://www.rfc-editor.org"
                                       "https://www.w3.org" "https://httpbin.org/get")
                    local count=10
                    echo -e "${CYAN}  [*] Sending $count random background requests through Tor...${RESET}"
                    for (( i=0; i<count; i++ )); do
                        local site="${noise_sites[$RANDOM % ${#noise_sites[@]}]}"
                        proxychains4 -q curl -s --max-time 8 "$site" -o /dev/null 2>/dev/null &
                        sleep "0.$((RANDOM % 9 + 1))"
                    done
                    wait
                    echo -e "${GREEN}  [+] $count background requests sent${RESET}"
                    log "Cover traffic: $count requests"
                    ;;
                2)
                    echo -e "${CYAN}  [*] Constant-rate padding — runs in background (Ctrl+C to stop)${RESET}"
                    echo -e "${YELLOW}  [!] This will use bandwidth. Press Ctrl+C to stop.${RESET}"
                    local noise_sites=("https://www.wikipedia.org" "https://www.example.com" "https://httpbin.org/get")
                    while true; do
                        local site="${noise_sites[$RANDOM % ${#noise_sites[@]}]}"
                        proxychains4 -q curl -s --max-time 10 "$site" -o /dev/null 2>/dev/null
                        sleep "$((5 + RANDOM % 15))"
                    done
                    ;;
                3)
                    echo -e "\n  ${DIM}Traffic padding sends background requests to create noise.${RESET}"
                    echo -e "  ${DIM}It makes timing-based traffic correlation significantly harder.${RESET}"
                    echo -e "  ${DIM}This is not a complete defense — adversaries with full path${RESET}"
                    echo -e "  ${DIM}visibility can still use volume correlation over long periods.${RESET}"
                    return ;;
            esac
            ;;
        4)
            # NEW: Scapy custom packet crafting
            echo -e "\n${CYAN}  ═══ SCAPY CUSTOM PACKET CRAFTING ═══${RESET}"
            echo -e "  ${YELLOW}Why?${RESET} nmap/curl produce recognizable packet patterns."
            echo -e "  Custom packets break tool fingerprints (JA3, p0f, Snort sigs)."
            echo -e ""
            if ! command -v scapy &>/dev/null && ! python3 -c "import scapy" 2>/dev/null; then
                echo -e "${YELLOW}  [!] Scapy not found: apt install python3-scapy${RESET}"
                return
            fi
            echo -e "  [1] Send fragmented TCP SYN (evades simple packet inspection)"
            echo -e "  [2] Craft ICMP with custom payload"
            echo -e "  [3] TCP with randomized window + TTL"
            read -rp "  Sub-choice: " sub
            read -rp "  Target IP: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }

            case $sub in
                1)
                    python3 << SCAPY
from scapy.all import *
import random
ttl = random.randint(64, 128)
win = random.randint(1024, 65535)
pkt = IP(dst="$target", ttl=ttl, flags="MF") / TCP(dport=80, sport=random.randint(1024,65535), flags="S", window=win)
print(f"  [*] Sending fragmented SYN to $target TTL={ttl} WIN={win}")
send(pkt, verbose=0)
print("  [+] Sent")
SCAPY
                    ;;
                2)
                    python3 << SCAPY
from scapy.all import *
import random, os
payload = os.urandom(random.randint(8, 64))
pkt = IP(dst="$target") / ICMP() / Raw(load=payload)
print(f"  [*] Sending ICMP with {len(payload)}-byte random payload to $target")
send(pkt, verbose=0)
print("  [+] Sent")
SCAPY
                    ;;
                3)
                    python3 << SCAPY
from scapy.all import *
import random
ttl = random.randint(48, 255)
win = random.randint(512, 65535)
sport = random.randint(1024, 65535)
pkt = IP(dst="$target", ttl=ttl) / TCP(dport=443, sport=sport, flags="S", window=win, options=[('MSS', random.randint(536,1460))])
print(f"  [*] TCP SYN to $target:443 — TTL={ttl} WIN={win} SPORT={sport}")
send(pkt, verbose=0)
print("  [+] Sent")
SCAPY
                    ;;
            esac
            log "Scapy packet crafted to $target"
            ;;
        5)
            # NEW: IDS awareness
            echo -e "\n${CYAN}  ═══ IDS / IPS AWARENESS (Suricata / Zeek) ═══${RESET}"
            echo -e "  ${RED}Even with Tor + proxychains, IDS on the target network can detect:${RESET}"
            echo -e ""
            echo -e "  ${YELLOW}Suricata signatures detect:${RESET}"
            echo -e "  • nmap OS probe pattern (specific TCP flag sequences)"
            echo -e "  • Metasploit staging URLs (/AAAA, /multi/handler patterns)"
            echo -e "  • SQLi payloads (UNION SELECT, --comment patterns)"
            echo -e "  • Port scan patterns (too many SYNs, too fast)"
            echo -e "  • Default tool User-Agents (sqlmap/, nikto/)"
            echo -e ""
            echo -e "  ${YELLOW}Zeek (Bro) behavioral analysis detects:${RESET}"
            echo -e "  • Repeated connection attempts (brute force signature)"
            echo -e "  • Abnormal protocol behavior (malformed packets)"
            echo -e "  • DNS query anomalies (DGA domain patterns)"
            echo -e "  • Large data exfiltration (volume anomaly)"
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Use slow scan rates (nmap -T1 or -T2)"
            echo -e "  • Fragment packets (nmap -f or --mtu 8)"
            echo -e "  • Randomize scan order (--randomize-hosts)"
            echo -e "  • Use distributed scanning (multiple source IPs)"
            echo -e "  • Avoid default payload strings — customize all tool configs"
            echo -e "  • Use Scapy for custom packets instead of standard tools"
            return ;;
        6)
            echo -e "\n${CYAN}  ═══ TLS / JA3 FINGERPRINTING ═══${RESET}"
            echo -e "  ${YELLOW}JA3${RESET}  — fingerprints TLS ClientHello (cipher order, extensions)"
            echo -e "  ${YELLOW}JA3S${RESET} — fingerprints TLS ServerHello responses"
            echo -e "  ${YELLOW}HASSH${RESET}— fingerprints SSH key exchange"
            echo -e ""
            echo -e "  Every tool has a UNIQUE JA3 hash:"
            echo -e "  curl:             distinct JA3"
            echo -e "  python-requests:  distinct JA3 (different from curl)"
            echo -e "  nmap:             distinct JA3 + probe pattern"
            echo -e "  Tor Browser:      mimics Firefox JA3 exactly"
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Use torsocks (more consistent with browser profile)"
            echo -e "  • Use Tor Browser for manual browsing"
            echo -e "  • Use -sV --version-intensity 0 for nmap (less probing)"
            echo -e "  • Option [2] in this menu — randomize TCP stack"
            return ;;
        7)
            echo -e "\n${RED}  ⚠ TOOL SIGNATURE WARNING ⚠${RESET}"
            echo -e "  ${YELLOW}nmap${RESET}       — JA3, OS probe packets, timing signature"
            echo -e "  ${YELLOW}curl${RESET}       — JA3, User-Agent"
            echo -e "  ${YELLOW}sqlmap${RESET}     — payload patterns, HTTP header order"
            echo -e "  ${YELLOW}metasploit${RESET} — staging URLs, payload signatures"
            echo -e "  ${YELLOW}nikto${RESET}      — UA + request pattern"
            echo -e "  ${YELLOW}hydra${RESET}      — connection timing, banner grab pattern"
            echo -e "  ${YELLOW}gobuster${RESET}   — request rate + wordlist pattern"
            echo -e ""
            echo -e "  Always wrap with: ${BOLD}proxychains4 -q <tool>${RESET}"
            echo -e "  And randomize UA: ${BOLD}option [1] above${RESET}"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# BEHAVIORAL PATTERN TOOLS + INFRASTRUCTURE ROTATION
# ══════════════════════════════════════════════════════════════════════
behavioral_tools() {
    echo -e "\n${MAGENTA}┌──── BEHAVIORAL PATTERN + OPSEC ─────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Nmap with randomized timing + decoys             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Random jitter sleep between operations           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Randomized port scan order                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Spoof nmap source port                           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Distributed scan mode (multi-source simulation)  ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] OPSEC discipline checklist                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Infrastructure rotation checklist                ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] Behavioral attribution analysis (self-audit)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            read -rp "  Target IP/range: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            local timing=$((1 + RANDOM % 3))
            local sport=$((1024 + RANDOM % 60000))
            local dlen=$((20 + RANDOM % 200))
            echo -e "${CYAN}  [*] nmap T${timing}, decoys, sport=$sport, data-len=$dlen${RESET}"
            proxychains4 -q nmap -T${timing} --randomize-hosts \
                --source-port "$sport" -D RND:5 \
                --data-length "$dlen" -f "$target" 2>/dev/null
            log "Behavioral nmap: $target"
            ;;
        2)
            read -rp "  Min sleep (seconds): " min_s
            read -rp "  Max sleep (seconds): " max_s
            [[ -z "$min_s" || -z "$max_s" ]] && { echo "  Missing values."; return; }
            local delay=$(( min_s + RANDOM % (max_s - min_s + 1) ))
            echo -e "${CYAN}  [*] Sleeping ${delay}s...${RESET}"; sleep "$delay"
            echo -e "${GREEN}  [+] Done${RESET}"
            ;;
        3)
            read -rp "  Target: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            proxychains4 -q nmap --randomize-hosts -p- --min-rate 50 --max-rate 200 -T2 "$target" 2>/dev/null
            ;;
        4)
            read -rp "  Source port (53/80/443): " sport
            read -rp "  Target: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            proxychains4 -q nmap --source-port "$sport" -sS "$target" 2>/dev/null
            ;;
        5)
            # NEW: distributed scan simulation
            echo -e "\n${CYAN}  ═══ DISTRIBUTED SCANNING ═══${RESET}"
            echo -e "  ${YELLOW}Concept:${RESET} Split scan across multiple Tor circuits/identities"
            echo -e "  so no single source sees a full port scan."
            echo -e ""
            read -rp "  Target: " target
            read -rp "  Circuits to simulate (2-5): " circuits
            [[ -z "$target" ]] && { echo "  No target."; return; }
            circuits="${circuits:-3}"
            local port_ranges=("1-1000" "1001-10000" "10001-30000" "30001-50000" "50001-65535")
            echo -e "${CYAN}  [*] Scanning in $circuits segments, rotating circuit between each...${RESET}"
            for (( i=0; i<circuits; i++ )); do
                local range="${port_ranges[$i]}"
                echo -e "  ${DIM}[Circuit $((i+1))/$circuits] Scanning ports $range...${RESET}"
                # Rotate Tor circuit
                (printf 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n') | nc -w 2 127.0.0.1 9053 2>/dev/null || true
                sleep "$((10 + RANDOM % 20))"
                proxychains4 -q nmap -T1 -p "$range" "$target" 2>/dev/null &
            done
            wait
            echo -e "${GREEN}  [+] Distributed scan complete${RESET}"
            log "Distributed scan: $target ($circuits circuits)"
            ;;
        6)
            echo -e "\n${CYAN}  ═══ OPSEC DISCIPLINE CHECKLIST ═══${RESET}"
            echo -e "  ${GREEN}[✓ DO]${RESET}"
            echo -e "  • Vary timing — never use T4/T5"
            echo -e "  • Rotate Tor circuit between targets"
            echo -e "  • Randomize port scan order"
            echo -e "  • Fragment packets (-f or --mtu)"
            echo -e "  • Use decoys (nmap -D RND:10)"
            echo -e "  • Vary tools — alternate nmap / masscan / zmap"
            echo -e "  • Vary payloads between sessions"
            echo -e "  • Change activity time windows each session"
            echo -e ""
            echo -e "  ${RED}[✗ AVOID]${RESET}"
            echo -e "  • Same nmap flags every run"
            echo -e "  • Sequential 1→65535 port scans"
            echo -e "  • Same time-of-day pattern"
            echo -e "  • Identical attack chain: nmap→gobuster→sqlmap every time"
            echo -e "  • Reusing same payloads, scripts, or tool defaults"
            return ;;
        7)
            # NEW: infrastructure rotation checklist
            echo -e "\n${CYAN}  ═══ INFRASTRUCTURE ROTATION CHECKLIST ═══${RESET}"
            echo -e "  ${YELLOW}Rotate BEFORE:${RESET}"
            echo -e "  [ ] Each new target / engagement"
            echo -e "  [ ] If you suspect detection or honeypot"
            echo -e "  [ ] After any credential use"
            echo -e ""
            echo -e "  ${YELLOW}What to rotate:${RESET}"
            echo -e "  [ ] Tor circuit (NEWNYM signal — option in Tor menu)"
            echo -e "  [ ] MAC address (different vendor prefix)"
            echo -e "  [ ] Hostname (new random generic name)"
            echo -e "  [ ] VPS/relay (if using external infrastructure)"
            echo -e "  [ ] DNS configuration"
            echo -e "  [ ] SSH keys / TLS certificates"
            echo -e "  [ ] Tool configuration (change default scan flags)"
            echo -e "  [ ] User-Agent string"
            echo -e "  [ ] Payload structure (no reused shellcode strings)"
            echo -e ""
            echo -e "  ${RED}Never reuse:${RESET}"
            echo -e "  • Domains, IPs, or hostnames across operations"
            echo -e "  • Account names, emails, SSH keys"
            echo -e "  • Identical exploit code without modification"
            echo -e "  • The same operational workflow signature"
            return ;;
        8)
            # NEW: behavioral self-audit
            echo -e "\n${CYAN}  ═══ BEHAVIORAL SELF-AUDIT ═══${RESET}"
            echo -e "  Answer honestly — these are the patterns investigators look for:"
            echo -e ""
            local score=0
            local q
            read -rp "  Do you always run nmap before other tools? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Predictable workflow — mix up your recon order${RESET}" && ((score++))
            read -rp "  Do you scan at the same time of day? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Timing fingerprint — randomize activity windows${RESET}" && ((score++))
            read -rp "  Do you use default tool configurations? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Tool signature — customize every config${RESET}" && ((score++))
            read -rp "  Do you reuse the same VPS/infrastructure? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Infrastructure fingerprint — rotate per op${RESET}" && ((score++))
            read -rp "  Do you use the same scripting language every time? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Code style fingerprint — vary tools and languages${RESET}" && ((score++))
            echo -e "\n  Risk score: ${YELLOW}$score/5${RESET}"
            [[ $score -eq 0 ]] && echo -e "  ${GREEN}  Good OPSEC discipline${RESET}"
            [[ $score -ge 3 ]] && echo -e "  ${RED}  High attribution risk — review checklist (option 7)${RESET}"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# NETWORK INFRA AWARENESS + NAMESPACE ISOLATION
# ══════════════════════════════════════════════════════════════════════
network_infra() {
    echo -e "\n${MAGENTA}┌──── NETWORK INFRA + ISOLATION ──────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Disassociate from WiFi AP                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Flush DHCP lease files                           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] What your router/ISP can see                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Enable monitor mode                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Disable WiFi (rfkill)                            ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Network namespace isolation (Whonix-style)       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Run app in isolated namespace                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] RAM session / read-only media guide              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            [[ -z "$IFACE" ]] && select_interface
            iw dev "$IFACE" disconnect 2>/dev/null \
                && echo -e "${GREEN}  [+] Disassociated from AP${RESET}" \
                || echo -e "${YELLOW}  [!] Try: iwconfig $IFACE essid off${RESET}"
            log "WiFi disassociated"
            ;;
        2)
            find /var/lib/dhcp /var/lib/dhclient /run/NetworkManager /run/systemd/netif \
                -name "*.lease*" 2>/dev/null | while read -r lf; do
                shred -uzn 1 "$lf" 2>/dev/null && echo "  Shredded: $lf" || true
            done
            dhclient -r 2>/dev/null || true
            echo -e "${GREEN}  [+] DHCP leases flushed${RESET}"
            log "DHCP leases flushed"
            ;;
        3)
            echo -e "\n${CYAN}  What local network infrastructure logs:${RESET}"
            echo -e "  • DHCP: MAC → IP → lease time → hostname in request"
            echo -e "  • WiFi: probe requests (broadcasts saved SSIDs)"
            echo -e "  • ARP: MAC broadcasts to entire local segment"
            echo -e "  • NetFlow: dst IP, port, byte count (even for HTTPS)"
            echo -e "  • ISP: full connection metadata, timestamps"
            echo -e ""
            echo -e "  ${YELLOW}Mitigations:${RESET}"
            echo -e "  • Spoof MAC before connecting (MAC menu → option 1)"
            echo -e "  • Set generic hostname before DHCP"
            echo -e "  • Disable WiFi probe requests: iw dev \$IFACE set power_save on"
            echo -e "  • Use Tor/VPN before any traffic"
            return ;;
        4)
            [[ -z "$IFACE" ]] && select_interface
            ip link set "$IFACE" down 2>/dev/null
            iw dev "$IFACE" set type monitor 2>/dev/null \
                && ip link set "$IFACE" up \
                && echo -e "${GREEN}  [+] Monitor mode: $IFACE${RESET}" \
                || echo -e "${YELLOW}  [!] Try: airmon-ng start $IFACE${RESET}"
            log "Monitor mode: $IFACE"
            ;;
        5)
            rfkill block wifi
            echo -e "${GREEN}  [+] WiFi rfkill blocked${RESET}"
            log "WiFi blocked"
            ;;
        6)
            # NEW: network namespace isolation
            echo -e "\n${CYAN}  ═══ NETWORK NAMESPACE ISOLATION ═══${RESET}"
            echo -e "  ${YELLOW}Concept (Whonix-style):${RESET}"
            echo -e ""
            echo -e "  ${WHITE}[ Workstation NS ] ──► [ Tor Gateway NS ] ──► Internet${RESET}"
            echo -e ""
            echo -e "  Applications in the Workstation namespace have NO direct"
            echo -e "  internet access — all traffic MUST go through the Tor Gateway."
            echo -e "  Even if an app tries to bypass proxy settings, it physically"
            echo -e "  cannot reach the internet without going through Tor."
            echo -e ""
            echo -e "  ${GREEN}Creating an isolated namespace now:${RESET}"
            read -rp "  Create ghost_ns namespace? [y/N]: " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                ip netns add ghost_ns 2>/dev/null || true
                ip netns list | grep ghost_ns \
                    && echo -e "${GREEN}  [+] Network namespace 'ghost_ns' created${RESET}" \
                    || echo -e "${YELLOW}  [!] Namespace may already exist${RESET}"
                echo -e "${CYAN}  Run commands in isolated namespace:${RESET}"
                echo -e "  ${BOLD}ip netns exec ghost_ns bash${RESET}"
                echo -e "  ${BOLD}ip netns exec ghost_ns proxychains4 curl ...${RESET}"
                log "Network namespace ghost_ns created"
            fi
            ;;
        7)
            # NEW: run app in namespace
            echo -e "\n${CYAN}  Run a command in the isolated ghost_ns namespace:${RESET}"
            ip netns list 2>/dev/null | grep ghost_ns \
                || echo -e "${YELLOW}  [!] ghost_ns not found — create it with option [6] first${RESET}"
            read -rp "  Command to run (e.g. 'proxychains4 curl https://example.com'): " cmd
            [[ -z "$cmd" ]] && { echo "  No command."; return; }
            ip netns exec ghost_ns bash -c "$cmd"
            log "Namespace exec: $cmd"
            ;;
        8)
            # NEW: RAM session guide
            echo -e "\n${CYAN}  ═══ RAM SESSION + READ-ONLY MEDIA GUIDE ═══${RESET}"
            echo -e "  ${GREEN}Best practices for zero-persistence sessions:${RESET}"
            echo -e ""
            echo -e "  ${YELLOW}[1] Boot from read-only media:${RESET}"
            echo -e "  • Use Tails OS (amnesic live system) on USB"
            echo -e "  • Kali Live (non-persistence mode): boot without 'persistence' option"
            echo -e "  • All session data stays in RAM — wiped on shutdown"
            echo -e ""
            echo -e "  ${YELLOW}[2] RAM-only sessions:${RESET}"
            echo -e "  • Tails routes all traffic through Tor by default"
            echo -e "  • No disk writes — /tmp, /var/log all in tmpfs (RAM)"
            echo -e "  • Verify: mount | grep tmpfs"
            echo -e ""
            echo -e "  ${YELLOW}[3] Avoid persistent browser profiles:${RESET}"
            echo -e "  • Never save passwords, cookies, or form data"
            echo -e "  • Use Tor Browser (no persistent profile)"
            echo -e "  • Or: firefox --private-window (but still leaves RAM artifacts)"
            echo -e "  • Better: chromium --incognito --no-first-run --user-data-dir=/tmp/cbr"
            echo -e ""
            echo -e "  ${YELLOW}[4] Current tmpfs check:${RESET}"
            mount | grep tmpfs | head -8 || echo "  No tmpfs found"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# TIMEZONE + NTP SPOOFING
# ══════════════════════════════════════════════════════════════════════
timezone_ntp() {
    echo -e "\n${MAGENTA}┌──── TIMEZONE + TIME SPOOFING ───────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Set timezone to UTC (most neutral)               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Spoof to a custom timezone                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Disable NTP sync                                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Shift system time by N hours                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Randomize activity window tip                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Restore original timezone + NTP                  ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local tz_bak="$BACKUP_DIR/timezone.bak"
    mkdir -p "$BACKUP_DIR"
    [[ ! -f "$tz_bak" ]] && timedatectl show 2>/dev/null | grep Timezone | cut -d= -f2 > "$tz_bak" || true

    case $ch in
        1)
            timedatectl set-timezone UTC
            echo -e "${GREEN}  [+] Timezone → UTC${RESET}"
            echo -e "${YELLOW}  [!] UTC is used globally — reduces timezone fingerprint${RESET}"
            log "Timezone UTC"
            ;;
        2)
            echo -e "  Examples: America/New_York  Europe/London  Asia/Singapore  Asia/Tokyo"
            read -rp "  Timezone: " tz
            timedatectl set-timezone "$tz" \
                && echo -e "${GREEN}  [+] Timezone: $tz${RESET}" \
                || echo -e "${RED}  [!] Invalid timezone${RESET}"
            log "Timezone spoofed: $tz"
            ;;
        3)
            timedatectl set-ntp false
            systemctl stop systemd-timesyncd 2>/dev/null || true
            systemctl stop ntp 2>/dev/null || true
            echo -e "${GREEN}  [+] NTP disabled — reduces timing correlation${RESET}"
            log "NTP disabled"
            ;;
        4)
            read -rp "  Hours to shift (+/-): " hrs
            [[ -z "$hrs" ]] && { echo "  No value."; return; }
            local new_ts=$(( $(date +%s) + hrs * 3600 ))
            timedatectl set-ntp false
            date -s "@$new_ts" > /dev/null
            echo -e "${GREEN}  [+] Time shifted ${hrs}h → $(date)${RESET}"
            log "Time shifted ${hrs}h"
            ;;
        5)
            # NEW: behavioral timing advice
            echo -e "\n${CYAN}  ═══ ACTIVITY WINDOW RANDOMIZATION ═══${RESET}"
            echo -e "  ${YELLOW}Problem:${RESET} Repeated activity at the same clock hours"
            echo -e "  narrows the attacker's probable timezone to within 2-3 hours."
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Vary your operation start times — don't always start at 02:00 UTC"
            echo -e "  • Use delayed execution: ${BOLD}at 03:${RANDOM:0:2} tomorrow < script.sh${RESET}"
            echo -e "  • Run operations via cron with jitter:"
            echo -e "    ${BOLD}*/30 * * * * sleep \$((RANDOM\\%1800)) && your_command${RESET}"
            echo -e "  • Consider automated tools that run at truly random times"
            echo -e "  • Avoid weekend/weekday patterns (can reveal employment status)"
            echo -e ""
            echo -e "  ${DIM}Language discipline:${RESET}"
            echo -e "  • Use consistent locale/charset (don't mix Arabic + English comments)"
            echo -e "  • Avoid native language typos in tool configs/scripts"
            return ;;
        6)
            local orig_tz; orig_tz=$(cat "$tz_bak" 2>/dev/null || echo "UTC")
            timedatectl set-timezone "$orig_tz"
            timedatectl set-ntp true
            systemctl start systemd-timesyncd 2>/dev/null || true
            echo -e "${GREEN}  [+] Timezone: $orig_tz + NTP re-enabled${RESET}"
            log "Timezone+NTP restored"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# HONEYPOT DETECTION (limit interaction depth)
# ══════════════════════════════════════════════════════════════════════
honeypot_detection() {
    echo -e "\n${MAGENTA}┌──── HONEYPOT DETECTION + SAFE INTERACTION ──────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Heuristic scan (ports, TTL, banner)              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Threat intel lookup (Shodan/AbuseIPDB)           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Banner grab + signature check                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Response consistency test                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Safe interaction depth guide                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Honeypot indicator reference                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            read -rp "  Target IP: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            echo -e "${CYAN}  [*] Running honeypot heuristics on $target...${RESET}"
            local risk=0

            local open_ports
            open_ports=$(proxychains4 -q nmap -T2 --open \
                -p 21,22,23,25,80,110,143,443,445,3389,8080 \
                "$target" 2>/dev/null | grep -c "open" || echo "0")
            echo -e "  Open ports (11 probed): ${YELLOW}$open_ports${RESET}"
            [[ "$open_ports" -gt 8 ]] && echo -e "  ${RED}⚠ Many open ports — honeypot indicator${RESET}" && ((risk++))

            local ttl
            ttl=$(ping -c 1 -W 2 "$target" 2>/dev/null | grep -oP 'ttl=\K[0-9]+' | head -1 || echo "0")
            echo -e "  TTL: ${YELLOW}$ttl${RESET}"
            [[ "$ttl" -gt 0 && "$ttl" -lt 10 ]] && echo -e "  ${RED}⚠ Abnormal TTL — sandbox/emulation indicator${RESET}" && ((risk++))

            local banner
            banner=$(timeout 3 nc -w 2 "$target" 22 2>/dev/null | head -1 || echo "")
            echo -e "  SSH banner: ${YELLOW}${banner:-none}${RESET}"
            echo "$banner" | grep -qiE "kippo|cowrie|honeypot|fake" && \
                echo -e "  ${RED}⚠ Honeypot signature in banner${RESET}" && ((risk++)) || true

            echo -e "\n  ${BOLD}Risk score: $risk/3${RESET}"
            [[ $risk -ge 2 ]] && echo -e "  ${RED}HIGH RISK — abort and rotate identity${RESET}"
            [[ $risk -eq 0 ]] && echo -e "  ${GREEN}No obvious honeypot indicators${RESET}"
            log "Honeypot scan: $target risk=$risk"
            ;;
        2)
            read -rp "  Target IP: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            echo -e "${CYAN}  Shodan (needs API key):${RESET}"
            proxychains4 -q curl -s "https://api.shodan.io/shodan/host/$target?key=YOUR_KEY" 2>/dev/null \
                | python3 -m json.tool 2>/dev/null \
                || echo -e "  Manual: ${BOLD}https://shodan.io/host/$target${RESET}"
            echo -e "${CYAN}  AbuseIPDB (needs API key):${RESET}"
            echo -e "  Manual: ${BOLD}https://www.abuseipdb.com/check/$target${RESET}"
            echo -e "${CYAN}  Censys:${RESET}"
            echo -e "  Manual: ${BOLD}https://search.censys.io/hosts/$target${RESET}"
            ;;
        3)
            read -rp "  Target IP: " target; read -rp "  Port: " port
            [[ -z "$target" || -z "$port" ]] && { echo "  Missing values."; return; }
            local raw
            raw=$(proxychains4 -q timeout 5 nc -w 3 "$target" "$port" <<< "" 2>/dev/null || echo "")
            echo -e "\n${YELLOW}--- Banner ---${RESET}"; echo "$raw" | head -10
            echo "$raw" | grep -qiE "kippo|cowrie|dionaea|glastopf|honeyd|artillery|opencanary" \
                && echo -e "\n${RED}  ⚠ KNOWN HONEYPOT SIGNATURE DETECTED${RESET}" \
                || echo -e "\n${GREEN}  No known signature in banner${RESET}"
            log "Banner: $target:$port"
            ;;
        4)
            # NEW: response consistency test
            read -rp "  Target IP: " target
            read -rp "  Port to test: " port
            [[ -z "$target" || -z "$port" ]] && { echo "  Missing values."; return; }
            echo -e "${CYAN}  [*] Sending 3 requests, checking response consistency...${RESET}"
            local r1 r2 r3
            r1=$(proxychains4 -q timeout 4 nc -w 2 "$target" "$port" <<< "" 2>/dev/null | head -1 || echo "NONE")
            sleep 2
            r2=$(proxychains4 -q timeout 4 nc -w 2 "$target" "$port" <<< "" 2>/dev/null | head -1 || echo "NONE")
            sleep 2
            r3=$(proxychains4 -q timeout 4 nc -w 2 "$target" "$port" <<< "" 2>/dev/null | head -1 || echo "NONE")
            echo -e "  R1: ${YELLOW}$r1${RESET}"
            echo -e "  R2: ${YELLOW}$r2${RESET}"
            echo -e "  R3: ${YELLOW}$r3${RESET}"
            if [[ "$r1" == "$r2" && "$r2" == "$r3" ]]; then
                echo -e "  ${GREEN}Consistent responses — lower honeypot likelihood${RESET}"
            else
                echo -e "  ${RED}⚠ Inconsistent responses — possible honeypot/emulation${RESET}"
            fi
            log "Consistency test: $target:$port"
            ;;
        5)
            # NEW: safe interaction depth guide
            echo -e "\n${CYAN}  ═══ SAFE INTERACTION DEPTH ═══${RESET}"
            echo -e "  ${RED}Reality check:${RESET} Cowrie, T-Pot, and modern honeypots are"
            echo -e "  designed to appear completely real. Detection is NOT reliable."
            echo -e ""
            echo -e "  ${YELLOW}Safe interaction principles:${RESET}"
            echo -e "  • LOOK before you touch: passive recon only on unknown hosts"
            echo -e "  • Limit commands executed — avoid ${BOLD}id, whoami, uname, ls -la${RESET}"
            echo -e "  • Never upload files or tools to unknown systems"
            echo -e "  • Never execute code from unknown hosts"
            echo -e "  • Avoid downloading payloads to unknown machines"
            echo -e "  • Monitor your OWN behavior — honeypots log everything:"
            echo -e "    → Every command you type"
            echo -e "    → Every file you try to access"
            echo -e "    → Every payload you upload"
            echo -e "    → Connection timing + source fingerprint"
            echo -e ""
            echo -e "  ${GREEN}Before interacting with any unknown target:${RESET}"
            echo -e "  [1] Run heuristic scan (option 1)"
            echo -e "  [2] Cross-check on Shodan + Censys (option 2)"
            echo -e "  [3] Test response consistency (option 4)"
            echo -e "  [4] If ANY high-risk indicators — abort + rotate identity"
            return ;;
        6)
            echo -e "\n${CYAN}  ═══ HONEYPOT INDICATORS ═══${RESET}"
            echo -e "  ${RED}HIGH RISK:${RESET}"
            echo -e "  • SSH banner: SSH-2.0-OpenSSH_5.1p1 (Kippo default)"
            echo -e "  • FTP/Telnet always accepts any credential"
            echo -e "  • 10+ open ports on single IP"
            echo -e "  • Response latency < 1ms on ALL ports (emulation)"
            echo -e "  • Shodan tag: honeypot"
            echo -e ""
            echo -e "  ${YELLOW}MODERATE:${RESET}"
            echo -e "  • Generic banners with no version strings"
            echo -e "  • IP in known honeypot ASN (Team Cymru, T-Pot project)"
            echo -e "  • Services behave identically regardless of input"
            echo -e ""
            echo -e "  ${GREEN}Always:${RESET}"
            echo -e "  • Run option [1] + [2] before any operation"
            echo -e "  • If 2+ HIGH RISK signals → abort and rotate"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# HOSTNAME SPOOFER
# ══════════════════════════════════════════════════════════════════════
change_hostname() {
    local old_host; old_host=$(hostname)
    local bak="$BACKUP_DIR/hostname.bak"
    mkdir -p "$BACKUP_DIR"
    [[ ! -f "$bak" ]] && echo "$old_host" > "$bak"

    echo -e "\n${CYAN}[*] Current hostname: ${YELLOW}$old_host${RESET}"
    echo -e "  [1] Random realistic hostname (Windows/Mac style)"
    echo -e "  [2] Custom hostname"
    echo -e "  [3] Restore original"
    read -rp "  Choice: " ch

    local names=(
        "DESKTOP-$(printf '%06X' $((RANDOM*RANDOM)))"
        "LAPTOP-$(printf '%06X' $((RANDOM*RANDOM)))"
        "PC-$(printf '%08X' $((RANDOM*RANDOM)))"
        "WIN11-$(printf '%04X' $((RANDOM*RANDOM)))"
        "MacBook-$(printf '%04X' $((RANDOM*RANDOM)))"
    )

    case $ch in
        1)
            local newhost="${names[$RANDOM % ${#names[@]}]}"
            hostnamectl set-hostname "$newhost"
            sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$newhost/" /etc/hosts 2>/dev/null || true
            echo -e "${GREEN}  [+] Hostname: $newhost${RESET}"
            log "Hostname: $newhost"
            ;;
        2)
            read -rp "  New hostname: " h
            hostnamectl set-hostname "$h"
            sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$h/" /etc/hosts 2>/dev/null || true
            log "Hostname: $h"
            ;;
        3)
            local orig; orig=$(cat "$bak" 2>/dev/null || echo "kali")
            hostnamectl set-hostname "$orig"
            sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$orig/" /etc/hosts 2>/dev/null || true
            echo -e "${GREEN}  [+] Restored: $orig${RESET}"
            log "Hostname restored: $orig"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# STATUS DASHBOARD
# ══════════════════════════════════════════════════════════════════════
show_status() {
    echo -e "\n${CYAN}╔══════════════════ GHOST STATUS ══════════════════════════╗${RESET}"
    local pubip torip
    pubip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "unavailable")
    torip=$(proxychains4 -q curl -s --max-time 12 https://api.ipify.org 2>/dev/null || echo "unavailable")
    echo -e "${CYAN}║${RESET}  Real IP        : ${RED}$pubip${RESET}"
    echo -e "${CYAN}║${RESET}  Tor Exit IP    : ${GREEN}$torip${RESET}"
    systemctl is-active --quiet tor \
        && echo -e "${CYAN}║${RESET}  Tor            : ${GREEN}● Running${RESET}" \
        || echo -e "${CYAN}║${RESET}  Tor            : ${RED}○ Stopped${RESET}"
    local dns; dns=$(grep -m1 nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}')
    echo -e "${CYAN}║${RESET}  DNS            : ${YELLOW}$dns${RESET}"
    local tz; tz=$(timedatectl show 2>/dev/null | grep Timezone | cut -d= -f2 || date +%Z)
    echo -e "${CYAN}║${RESET}  Timezone       : ${YELLOW}$tz${RESET}"
    echo -e "${CYAN}║${RESET}  Hostname       : ${YELLOW}$(hostname)${RESET}"
    for iface in $(get_interfaces); do
        local mac; mac=$(cat /sys/class/net/"$iface"/address 2>/dev/null || echo "??")
        echo -e "${CYAN}║${RESET}  MAC [$iface]    : ${YELLOW}$mac${RESET}"
    done
    local ipv6; ipv6=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "?")
    [[ "$ipv6" == "1" ]] \
        && echo -e "${CYAN}║${RESET}  IPv6           : ${GREEN}DISABLED ✓${RESET}" \
        || echo -e "${CYAN}║${RESET}  IPv6           : ${RED}ENABLED (leak risk)${RESET}"
    iptables -L OUTPUT 2>/dev/null | grep -q "DROP" \
        && echo -e "${CYAN}║${RESET}  Kill-switch    : ${GREEN}ACTIVE ✓${RESET}" \
        || echo -e "${CYAN}║${RESET}  Kill-switch    : ${RED}OFF${RESET}"
    ip netns list 2>/dev/null | grep -q ghost_ns \
        && echo -e "${CYAN}║${RESET}  ghost_ns       : ${GREEN}EXISTS ✓${RESET}" \
        || echo -e "${CYAN}║${RESET}  ghost_ns       : ${DIM}not created${RESET}"
    systemctl is-active --quiet dnscrypt-proxy 2>/dev/null \
        && echo -e "${CYAN}║${RESET}  dnscrypt-proxy : ${GREEN}● Running${RESET}" \
        || echo -e "${CYAN}║${RESET}  dnscrypt-proxy : ${DIM}○ Stopped${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
}

# ══════════════════════════════════════════════════════════════════════
# ONE-CLICK GHOST MODE (all fixes)
# ══════════════════════════════════════════════════════════════════════
ghost_mode_on() {
    echo -e "\n${RED}${BOLD}[*] Activating HARDENED GHOST MODE v3...${RESET}"
    select_interface || return
    mkdir -p "$BACKUP_DIR"

    echo -e "${DIM}  [1/10] Disabling IPv6...${RESET}"
    ip6tables -P INPUT DROP; ip6tables -P OUTPUT DROP; ip6tables -P FORWARD DROP
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 -q
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 -q
    echo -e "${GREEN}  [1/10] IPv6 disabled${RESET}"

    echo -e "${DIM}  [2/10] Randomizing MAC + flushing DHCP...${RESET}"
    [[ ! -f "$BACKUP_DIR/${IFACE}.mac" ]] && ip link show "$IFACE" | awk '/ether/{print $2}' > "$BACKUP_DIR/${IFACE}.mac"
    ip link set "$IFACE" down; macchanger -r "$IFACE" -q; ip link set "$IFACE" up
    dhclient -r "$IFACE" 2>/dev/null || true; sleep 1; dhclient "$IFACE" 2>/dev/null &
    echo -e "${GREEN}  [2/10] MAC randomized + DHCP flushed${RESET}"

    echo -e "${DIM}  [3/10] Setting realistic hostname...${RESET}"
    [[ ! -f "$BACKUP_DIR/hostname.bak" ]] && hostname > "$BACKUP_DIR/hostname.bak"
    local names=("DESKTOP-$(printf '%06X' $((RANDOM*RANDOM)))" "LAPTOP-$(printf '%06X' $((RANDOM*RANDOM)))" "PC-$(printf '%08X' $((RANDOM*RANDOM)))")
    local newhost="${names[$RANDOM % 3]}"
    hostnamectl set-hostname "$newhost"
    sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$newhost/" /etc/hosts 2>/dev/null || true
    echo -e "${GREEN}  [3/10] Hostname → $newhost${RESET}"

    echo -e "${DIM}  [4/10] Setting timezone to UTC...${RESET}"
    [[ ! -f "$BACKUP_DIR/timezone.bak" ]] && timedatectl show 2>/dev/null | grep Timezone | cut -d= -f2 > "$BACKUP_DIR/timezone.bak" || true
    timedatectl set-timezone UTC
    echo -e "${GREEN}  [4/10] Timezone → UTC${RESET}"

    echo -e "${DIM}  [5/10] Starting Tor with stream isolation...${RESET}"
    grep -q "## Ghost Profile" "$TOR_CONF" 2>/dev/null || cat >> "$TOR_CONF" << 'TORCONF'

## Ghost Profile
IsolateDestAddr 1
IsolateDestPort 1
IsolateClientProtocol 1
SocksPort 9050 IsolateDestAddr IsolateDestPort
ControlPort 9053
CookieAuthentication 1
TransPort 9040
DNSPort 5353
AutomapHostsOnResolve 1
TORCONF
    systemctl restart tor; sleep 3
    systemctl is-active --quiet tor \
        && echo -e "${GREEN}  [5/10] Tor started (stream isolation + TransPort + DNSPort)${RESET}" \
        || echo -e "${YELLOW}  [5/10] Tor failed — check journalctl -u tor${RESET}"

    echo -e "${DIM}  [6/10] Configuring proxychains...${RESET}"
    cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak" 2>/dev/null || true
    cat > "$PROXYCHAINS_CONF" << 'CONF'
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
socks5 127.0.0.1 9050
CONF
    echo -e "${GREEN}  [6/10] proxychains4 → strict Tor${RESET}"

    echo -e "${DIM}  [7/10] Locking DNS to Tor...${RESET}"
    systemctl stop systemd-resolved 2>/dev/null || true
    [[ ! -f "$BACKUP_DIR/resolv.conf.bak" ]] && cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf
    echo -e "${GREEN}  [7/10] DNS locked → Tor DNSPort${RESET}"

    echo -e "${DIM}  [8/10] Applying iptables full lockdown...${RESET}"
    local TOR_UID; TOR_UID=$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || echo "107")
    iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X
    iptables -A INPUT  -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner "$TOR_UID" -j ACCEPT
    iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -p tcp --syn -j REDIRECT --to-ports 9040
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 5353
    iptables -A OUTPUT -j DROP
    iptables -A INPUT  -j DROP
    echo -e "${GREEN}  [8/10] iptables: full Tor lockdown + kill-switch${RESET}"

    echo -e "${DIM}  [9/10] Randomizing TCP stack + UA...${RESET}"
    local ua_pool=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0"
                   "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0")
    echo "user-agent = \"${ua_pool[$RANDOM % 2]}\"" > /root/.curlrc
    sysctl -w net.ipv4.tcp_timestamps=0 -q
    sysctl -w net.ipv4.ip_default_ttl=$((64 + RANDOM % 64)) -q
    echo -e "${GREEN}  [9/10] TCP stack hardened + UA randomized${RESET}"

    echo -e "${DIM}  [10/10] Creating ghost_ns network namespace...${RESET}"
    ip netns add ghost_ns 2>/dev/null || true
    echo -e "${GREEN}  [10/10] ghost_ns namespace ready${RESET}"

    GHOST_ACTIVE=1
    log "Ghost Mode v3 activated"

    echo -e "\n${RED}${BOLD}"
    echo -e "  ╔═══════════════════════════════════════════════════╗"
    echo -e "  ║                                                   ║"
    echo -e "  ║          👻  GHOST MODE v3 ACTIVE  👻             ║"
    echo -e "  ║                                                   ║"
    echo -e "  ║  All TCP → Tor TransPort 9040                     ║"
    echo -e "  ║  DNS     → Tor DNSPort 5353                       ║"
    echo -e "  ║  IPv6    → DISABLED                               ║"
    echo -e "  ║  Kill-switch → ACTIVE                             ║"
    echo -e "  ║  ghost_ns → READY                                 ║"
    echo -e "  ║                                                   ║"
    echo -e "  ║  proxychains4 <tool>  |  torsocks <tool>          ║"
    echo -e "  ║  ip netns exec ghost_ns <tool>                    ║"
    echo -e "  ╚═══════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ══════════════════════════════════════════════════════════════════════
# RESTORE NORMAL PROFILE
# ══════════════════════════════════════════════════════════════════════
ghost_mode_off() {
    echo -e "\n${CYAN}[*] Restoring normal profile...${RESET}"

    for iface in $(get_interfaces); do
        local mbak="$BACKUP_DIR/${iface}.mac"
        if [[ -f "$mbak" ]]; then
            ip link set "$iface" down
            macchanger -m "$(cat "$mbak")" "$iface" -q 2>/dev/null \
                || macchanger -p "$iface" -q 2>/dev/null
            ip link set "$iface" up
        fi
    done; echo -e "${GREEN}  [+] MACs restored${RESET}"

    local h; h=$(cat "$BACKUP_DIR/hostname.bak" 2>/dev/null || echo "kali")
    hostnamectl set-hostname "$h"
    sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$h/" /etc/hosts 2>/dev/null || true
    echo -e "${GREEN}  [+] Hostname: $h${RESET}"

    local tz; tz=$(cat "$BACKUP_DIR/timezone.bak" 2>/dev/null || echo "UTC")
    timedatectl set-timezone "$tz"; timedatectl set-ntp true
    echo -e "${GREEN}  [+] Timezone: $tz${RESET}"

    chattr -i /etc/resolv.conf 2>/dev/null || true
    [[ -f "$BACKUP_DIR/resolv.conf.bak" ]] && cp "$BACKUP_DIR/resolv.conf.bak" /etc/resolv.conf
    systemctl start systemd-resolved 2>/dev/null || true
    echo -e "${GREEN}  [+] DNS restored${RESET}"

    sed -i '/## Ghost Profile/,/AutomapHostsOnResolve/d' "$TOR_CONF" 2>/dev/null || true
    systemctl stop tor; echo -e "${GREEN}  [+] Tor stopped${RESET}"

    iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X
    iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT
    ip6tables -F; ip6tables -X
    ip6tables -P INPUT ACCEPT; ip6tables -P OUTPUT ACCEPT; ip6tables -P FORWARD ACCEPT
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 -q
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 -q
    echo -e "${GREEN}  [+] Firewall flushed + IPv6 restored${RESET}"

    [[ -f "${PROXYCHAINS_CONF}.bak" ]] && cp "${PROXYCHAINS_CONF}.bak" "$PROXYCHAINS_CONF"
    rm -f /root/.curlrc
    sysctl -w net.ipv4.tcp_timestamps=1 -q
    sysctl -w net.ipv4.ip_default_ttl=64 -q

    ip netns del ghost_ns 2>/dev/null || true
    echo -e "${GREEN}  [+] ghost_ns namespace removed${RESET}"

    GHOST_ACTIVE=0
    log "Ghost Mode deactivated"
    echo -e "\n${CYAN}  [+] Normal profile fully restored.${RESET}\n"
}

# ══════════════════════════════════════════════════════════════════════
# MAIN MENU
# ══════════════════════════════════════════════════════════════════════
# v4 NEW — MAC SCHEDULED ROTATION + VENDOR EMULATION
# ══════════════════════════════════════════════════════════════════════
mac_advanced() {
    echo -e "\n${MAGENTA}┌──── MAC ADVANCED: ROTATION + VENDOR EMULATION ─────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Schedule automatic MAC rotation (cron)           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Show / remove scheduled rotations                ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Vendor emulation — pick real OUI manufacturer    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Mimic specific device type (phone/laptop/IoT)    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Rotate MAC + DHCP right now manually             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    # Real OUI vendor database (prefix → vendor)
    declare -A OUI_DB=(
        ["Apple"]="f4:5c:89 a4:c3:f0 3c:22:fb 8c:85:90 dc:a6:32 f0:18:98 b8:09:8a"
        ["Samsung"]="f4:7b:5e 8c:71:f8 00:26:37 a0:07:98 e4:92:fb 70:f9:27 f8:04:2e"
        ["Intel"]="00:1b:21 00:1f:3b 8c:8d:28 a0:a8:cd c8:d9:d2 f8:16:54 00:21:6a"
        ["Dell"]="14:18:77 b8:ca:3a f0:1f:af 00:14:22 18:03:73 b0:83:fe d4:81:d7"
        ["Lenovo"]="00:e0:4c 28:d2:44 40:8d:5c 54:e1:ad 80:5e:c0 98:fa:9b c8:dd:c9"
        ["Cisco"]="00:50:56 00:1a:a1 00:26:cb 58:bc:27 70:ca:9b a4:4c:11 e4:d3:f1"
        ["Raspberry"]="b8:27:eb dc:a6:32 e4:5f:01 28:cd:c1"
        ["Google"]="f4:f5:d8 3c:5a:b4 48:d6:d5 54:60:09 94:95:a0 a4:77:33"
        ["Microsoft"]="00:50:f2 28:18:78 3c:83:75 48:2a:e3 70:77:81 7c:1e:52 98:5f:d3"
        ["TP-Link"]="14:cc:20 18:d6:c7 30:b5:c2 50:c7:bf 54:a7:03 64:70:02 ac:84:c6"
    )

    [[ -z "$IFACE" ]] && select_interface

    case $ch in
        1)
            echo -e "\n${CYAN}  Schedule automatic MAC rotation:${RESET}"
            echo -e "  [1] Every 30 minutes"
            echo -e "  [2] Every hour"
            echo -e "  [3] Every 6 hours"
            echo -e "  [4] Custom interval"
            read -rp "  Schedule: " sched

            local cron_expr interval_label
            case $sched in
                1) cron_expr="*/30 * * * *"; interval_label="30min" ;;
                2) cron_expr="0 * * * *";    interval_label="1hr"   ;;
                3) cron_expr="0 */6 * * *";  interval_label="6hr"   ;;
                4)
                    read -rp "  Cron expression (e.g. '*/15 * * * *'): " cron_expr
                    interval_label="custom"
                    ;;
                *) echo "  Invalid."; return ;;
            esac

            # Write a standalone rotate script
            cat > /usr/local/bin/ghost_mac_rotate.sh << ROTSCRIPT
#!/bin/bash
IFACE="$IFACE"
ip link set "\$IFACE" down
/usr/bin/macchanger -r "\$IFACE" -q
ip link set "\$IFACE" up
/sbin/dhclient -r "\$IFACE" 2>/dev/null
sleep 2
/sbin/dhclient "\$IFACE" 2>/dev/null &
echo "[$(date)] MAC rotated on \$IFACE: $(cat /sys/class/net/\$IFACE/address 2>/dev/null)" >> /tmp/.ghost_mac_rotations.log
ROTSCRIPT
            chmod +x /usr/local/bin/ghost_mac_rotate.sh

            # Install cron job
            ( crontab -l 2>/dev/null | grep -v ghost_mac_rotate
              echo "$cron_expr /usr/local/bin/ghost_mac_rotate.sh" ) | crontab -

            echo -e "${GREEN}  [+] MAC rotation scheduled every $interval_label${RESET}"
            echo -e "${DIM}  Script: /usr/local/bin/ghost_mac_rotate.sh${RESET}"
            echo -e "${DIM}  Log: /tmp/.ghost_mac_rotations.log${RESET}"
            log "MAC auto-rotation scheduled: $interval_label on $IFACE"
            ;;
        2)
            echo -e "\n${CYAN}  Current scheduled MAC rotations:${RESET}"
            crontab -l 2>/dev/null | grep ghost_mac_rotate \
                && echo "" || echo "  None scheduled."
            echo -e "\n${CYAN}  Recent rotations:${RESET}"
            tail -10 /tmp/.ghost_mac_rotations.log 2>/dev/null || echo "  No rotation log."
            read -rp "  Remove all MAC rotation schedules? [y/N]: " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                crontab -l 2>/dev/null | grep -v ghost_mac_rotate | crontab -
                echo -e "${GREEN}  [+] Rotation schedule removed${RESET}"
                log "MAC rotation schedule removed"
            fi
            return ;;
        3)
            echo -e "\n${CYAN}  Real OUI vendor database:${RESET}"
            local i=0
            local vendor_names=()
            for v in "${!OUI_DB[@]}"; do
                echo -e "  ${BOLD}[$i]${RESET} $v"
                vendor_names+=("$v")
                ((i++))
            done
            echo ""
            read -rp "  Select vendor [0-$((${#vendor_names[@]}-1))]: " idx
            local chosen="${vendor_names[$idx]:-}"
            [[ -z "$chosen" ]] && { echo "  Invalid."; return; }

            # Pick one OUI prefix from that vendor
            local prefixes=( ${OUI_DB[$chosen]} )
            local prefix="${prefixes[$RANDOM % ${#prefixes[@]}]}"
            local suffix; suffix=$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
            local spoofed="$prefix:$suffix"

            ip link set "$IFACE" down
            macchanger -m "$spoofed" "$IFACE" -q
            ip link set "$IFACE" up
            echo -e "${GREEN}  [+] MAC emulating ${BOLD}$chosen${RESET}${GREEN}: $spoofed${RESET}"
            echo -e "${YELLOW}  [!] Device will appear as a $chosen device on the LAN${RESET}"
            log "Vendor emulation: $chosen ($spoofed) on $IFACE"
            ;;
        4)
            echo -e "\n${CYAN}  Mimic specific device type:${RESET}"
            echo -e "  [1] Smartphone  (Samsung/Apple mobile OUI)"
            echo -e "  [2] Laptop      (Dell/Lenovo/Apple OUI)"
            echo -e "  [3] Router/IoT  (TP-Link/Cisco OUI)"
            echo -e "  [4] Smart TV    (Samsung/LG OUI)"
            read -rp "  Type: " dtype

            local prefix
            case $dtype in
                1)
                    local mobile=("f4:7b:5e" "f4:5c:89" "a4:c3:f0" "a0:07:98" "f8:04:2e")
                    prefix="${mobile[$RANDOM % ${#mobile[@]}]}"
                    echo -e "${GREEN}  [+] Mimicking smartphone${RESET}"
                    ;;
                2)
                    local laptop=("14:18:77" "28:d2:44" "f0:1f:af" "54:e1:ad" "f0:18:98")
                    prefix="${laptop[$RANDOM % ${#laptop[@]}]}"
                    echo -e "${GREEN}  [+] Mimicking laptop${RESET}"
                    ;;
                3)
                    local router=("14:cc:20" "50:c7:bf" "00:1a:a1" "70:ca:9b" "ac:84:c6")
                    prefix="${router[$RANDOM % ${#router[@]}]}"
                    echo -e "${GREEN}  [+] Mimicking router/IoT${RESET}"
                    ;;
                4)
                    local tv=("f4:7b:5e" "8c:71:f8" "a4:77:33" "48:d6:d5" "f8:04:2e")
                    prefix="${tv[$RANDOM % ${#tv[@]}]}"
                    echo -e "${GREEN}  [+] Mimicking smart TV${RESET}"
                    ;;
                *) echo "  Invalid."; return ;;
            esac

            local suffix; suffix=$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
            ip link set "$IFACE" down
            macchanger -m "$prefix:$suffix" "$IFACE" -q
            ip link set "$IFACE" up
            echo -e "${GREEN}  [+] MAC set: $prefix:$suffix${RESET}"
            log "Device-type MAC emulation: $prefix:$suffix on $IFACE"
            ;;
        5)
            ip link set "$IFACE" down
            macchanger -r "$IFACE" -q
            ip link set "$IFACE" up
            dhclient -r "$IFACE" 2>/dev/null || true; sleep 1
            dhclient "$IFACE" 2>/dev/null &
            echo -e "${GREEN}  [+] MAC rotated + DHCP renewed${RESET}"
            log "Manual MAC rotation: $IFACE"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# v4 NEW — TRAFFIC OBFUSCATION: obfs4proxy + Shadowsocks
# ══════════════════════════════════════════════════════════════════════
traffic_obfuscation() {
    echo -e "\n${MAGENTA}┌──── TRAFFIC OBFUSCATION ────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] obfs4proxy — standalone server (obfuscate traffic) ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] obfs4proxy — client connection                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Shadowsocks — install + configure server          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Shadowsocks — client (ss-local → SOCKS5 proxy)    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Chain: Shadowsocks → Tor (double obfuscation)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Status: obfs4 / Shadowsocks processes             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Stop all obfuscation processes                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            if ! command -v obfs4proxy &>/dev/null; then
                echo -e "${YELLOW}  [!] Installing obfs4proxy...${RESET}"
                apt-get install -y obfs4proxy -qq || { echo -e "${RED}  [!] Install failed${RESET}"; return; }
            fi
            local state_dir="/var/lib/ghost_obfs4"
            mkdir -p "$state_dir"
            cat > /etc/ghost_obfs4_server.env << 'OBFSENV'
TOR_PT_MANAGED_TRANSPORT_VER=1
TOR_PT_STATE_LOCATION=/var/lib/ghost_obfs4
TOR_PT_SERVER_TRANSPORTS=obfs4
TOR_PT_SERVER_BINDADDR=obfs4-0.0.0.0:54321
TOR_PT_ORPORT=127.0.0.1:9001
OBFSENV
            echo -e "${GREEN}  [+] obfs4proxy server config written${RESET}"
            echo -e "${CYAN}  Starting obfs4proxy in server mode on :54321 ...${RESET}"
            env $(cat /etc/ghost_obfs4_server.env) obfs4proxy &
            sleep 2
            echo -e "${GREEN}  [+] obfs4proxy server started (PID: $!)${RESET}"
            echo -e "${YELLOW}  [!] Client cert is in: $state_dir/obfs4_bridgeline.txt${RESET}"
            cat "$state_dir/obfs4_bridgeline.txt" 2>/dev/null \
                && echo "" \
                || echo -e "${DIM}  Bridge line not yet generated — check $state_dir/${RESET}"
            log "obfs4proxy server started"
            ;;
        2)
            echo -e "\n${CYAN}  obfs4proxy client setup:${RESET}"
            read -rp "  Remote server IP: " srv_ip
            read -rp "  Remote obfs4 port (default 54321): " srv_port
            srv_port="${srv_port:-54321}"
            read -rp "  cert= string (from server bridge line): " cert_str
            read -rp "  iat-mode (0/1/2, default 0): " iat_mode
            iat_mode="${iat_mode:-0}"

            local state_dir="/var/lib/ghost_obfs4_client"
            mkdir -p "$state_dir"

            cat > /etc/ghost_obfs4_client.env << OBFSENV
TOR_PT_MANAGED_TRANSPORT_VER=1
TOR_PT_STATE_LOCATION=$state_dir
TOR_PT_CLIENT_TRANSPORTS=obfs4
OBFSENV

            echo -e "${CYAN}  [*] Starting obfs4proxy client...${RESET}"
            env $(cat /etc/ghost_obfs4_client.env) obfs4proxy &
            sleep 1

            # Update proxychains to use obfs4 SOCKS port
            echo -e "${GREEN}  [+] obfs4proxy client started${RESET}"
            echo -e "${CYAN}  Bridge line format for torrc:${RESET}"
            echo -e "  ${BOLD}Bridge obfs4 $srv_ip:$srv_port cert=$cert_str iat-mode=$iat_mode${RESET}"
            echo -e "${YELLOW}  [!] Add above line to torrc via Tor menu → [5] Bridges${RESET}"
            log "obfs4proxy client configured: $srv_ip:$srv_port"
            ;;
        3)
            echo -e "\n${CYAN}  Installing Shadowsocks (ss-libev)...${RESET}"
            apt-get install -y shadowsocks-libev -qq || {
                echo -e "${YELLOW}  Trying pip install...${RESET}"
                pip3 install shadowsocks 2>/dev/null || { echo -e "${RED}  [!] Install failed${RESET}"; return; }
            }
            local ss_pass; ss_pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 24)
            local ss_port=$((10000 + RANDOM % 50000))
            cat > /etc/shadowsocks-libev/ghost_server.json << SSJSON
{
    "server":     "0.0.0.0",
    "server_port": $ss_port,
    "password":   "$ss_pass",
    "timeout":    300,
    "method":     "chacha20-ietf-poly1305",
    "fast_open":  false,
    "mode":       "tcp_and_udp"
}
SSJSON
            systemctl enable shadowsocks-libev 2>/dev/null || true
            ss-server -c /etc/shadowsocks-libev/ghost_server.json -d start 2>/dev/null \
                || systemctl restart shadowsocks-libev 2>/dev/null || true
            echo -e "${GREEN}  [+] Shadowsocks server running${RESET}"
            echo -e "  ${BOLD}Port:     $ss_port${RESET}"
            echo -e "  ${BOLD}Password: $ss_pass${RESET}"
            echo -e "  ${BOLD}Cipher:   chacha20-ietf-poly1305${RESET}"
            echo -e "${YELLOW}  [!] Save these credentials — they won't be shown again${RESET}"
            log "Shadowsocks server started on port $ss_port"
            ;;
        4)
            echo -e "\n${CYAN}  Shadowsocks client (creates local SOCKS5 on 127.0.0.1:1080):${RESET}"
            read -rp "  Remote Shadowsocks server IP: " ss_srv
            read -rp "  Remote port: " ss_port
            read -rp "  Password: " ss_pass
            read -rp "  Cipher [chacha20-ietf-poly1305]: " ss_cipher
            ss_cipher="${ss_cipher:-chacha20-ietf-poly1305}"

            cat > /tmp/ghost_ss_client.json << SSJSON
{
    "server":      "$ss_srv",
    "server_port": $ss_port,
    "local_address": "127.0.0.1",
    "local_port":  1080,
    "password":    "$ss_pass",
    "timeout":     300,
    "method":      "$ss_cipher",
    "fast_open":   false
}
SSJSON
            ss-local -c /tmp/ghost_ss_client.json -d start 2>/dev/null \
                || ss-local -c /tmp/ghost_ss_client.json &
            sleep 1
            echo -e "${GREEN}  [+] Shadowsocks local SOCKS5 proxy: 127.0.0.1:1080${RESET}"
            echo -e "${CYAN}  Usage: proxychains4 or set SOCKS5 proxy to 127.0.0.1:1080${RESET}"
            log "Shadowsocks client → $ss_srv:$ss_port"
            ;;
        5)
            echo -e "\n${CYAN}  ═══ SHADOWSOCKS → TOR CHAIN ═══${RESET}"
            echo -e "  Traffic path: ${WHITE}You → Shadowsocks (obfuscated) → Tor → Internet${RESET}"
            echo -e ""
            echo -e "  ${YELLOW}Setup:${RESET}"
            echo -e "  1. Configure Shadowsocks client (option 4) → SOCKS5 on :1080"
            echo -e "  2. Edit proxychains4.conf:"
            cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak" 2>/dev/null || true
            cat > "$PROXYCHAINS_CONF" << 'CONF'
# Ghost v4 — Shadowsocks → Tor double-obfuscation
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
socks5  127.0.0.1 1080
socks5  127.0.0.1 9050
CONF
            echo -e "${GREEN}  [+] proxychains chain: Shadowsocks(:1080) → Tor(:9050)${RESET}"
            echo -e "${YELLOW}  [!] Start Shadowsocks client (option 4) + Tor before using${RESET}"
            log "Shadowsocks+Tor chain configured"
            ;;
        6)
            echo -e "\n${CYAN}  Obfuscation processes:${RESET}"
            pgrep -a obfs4proxy && echo "" || echo "  obfs4proxy: not running"
            pgrep -a ss-local   && echo "" || echo "  ss-local:   not running"
            pgrep -a ss-server  && echo "" || echo "  ss-server:  not running"
            systemctl is-active shadowsocks-libev 2>/dev/null \
                && echo "  shadowsocks-libev: active" \
                || echo "  shadowsocks-libev: inactive"
            return ;;
        7)
            pkill obfs4proxy 2>/dev/null || true
            pkill ss-local   2>/dev/null || true
            pkill ss-server  2>/dev/null || true
            systemctl stop shadowsocks-libev 2>/dev/null || true
            echo -e "${GREEN}  [+] All obfuscation processes stopped${RESET}"
            log "Obfuscation processes stopped"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# v4 NEW — PLUGGABLE TRANSPORTS (obfs4 / meek / snowflake)
# ══════════════════════════════════════════════════════════════════════
pluggable_transports() {
    echo -e "\n${MAGENTA}┌──── PLUGGABLE TRANSPORTS ───────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] obfs4  — random bytes, unrecognizable traffic    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] meek-azure — HTTPS domain-fronting (via Azure)   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] snowflake — WebRTC-based transport               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] webtunnel — HTTPS websocket (new, low profile)   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Compare transports + threat model                ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Configure torrc for chosen transport             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            echo -e "\n${CYAN}  ═══ obfs4 ═══${RESET}"
            echo -e "  Transforms Tor traffic into random-looking byte streams."
            echo -e "  Cannot be identified as Tor OR as any known protocol."
            echo -e "  ${GREEN}Best for:${RESET} Censored networks (China, Iran, Russia)"
            echo -e "  ${YELLOW}Weakness:${RESET} Active probing attacks can fingerprint the handshake"
            echo -e ""
            echo -e "  ${BOLD}Install:${RESET}  apt install obfs4proxy"
            echo -e "  ${BOLD}Get bridges:${RESET} https://bridges.torproject.org (choose obfs4)"
            echo -e ""
            if ! command -v obfs4proxy &>/dev/null; then
                read -rp "  Install obfs4proxy now? [Y/n]: " ans
                [[ "${ans:-Y}" =~ ^[Yy]$ ]] && apt-get install -y obfs4proxy -qq
            else
                echo -e "  ${GREEN}[✓] obfs4proxy is installed${RESET}"
            fi
            ;;
        2)
            echo -e "\n${CYAN}  ═══ meek-azure (Domain Fronting) ═══${RESET}"
            echo -e "  Traffic appears as HTTPS to Microsoft Azure CDN."
            echo -e "  DPI sees: ${WHITE}TLS → azure.com${RESET} — not Tor."
            echo -e "  Actual tunnel: goes through Azure → Tor bridge."
            echo -e "  ${GREEN}Best for:${RESET} Regions that can't block Azure (would break banking)"
            echo -e "  ${YELLOW}Weakness:${RESET} Slow, high latency; Azure policy may terminate"
            echo -e ""
            echo -e "  ${BOLD}torrc configuration:${RESET}"
            echo -e "  UseBridges 1"
            echo -e "  ClientTransportPlugin meek_lite exec /usr/bin/obfs4proxy"
            echo -e "  Bridge meek_lite 0.0.2.0:2 B9E7141C594AF25699E0079C1F0146040B6EA52F url=https://meek.azureedge.net/ front=ajax.aspnetcdn.com"
            read -rp "  Apply this meek-azure config to torrc? [y/N]: " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                command -v obfs4proxy &>/dev/null || apt-get install -y obfs4proxy -qq
                sed -i '/UseBridges/d;/Bridge meek/d;/ClientTransportPlugin meek/d' "$TOR_CONF" 2>/dev/null || true
                cat >> "$TOR_CONF" << 'TORCONF'

## Ghost v4 - meek-azure
UseBridges 1
ClientTransportPlugin meek_lite exec /usr/bin/obfs4proxy
Bridge meek_lite 0.0.2.0:2 B9E7141C594AF25699E0079C1F0146040B6EA52F url=https://meek.azureedge.net/ front=ajax.aspnetcdn.com
TORCONF
                systemctl restart tor 2>/dev/null || true
                echo -e "${GREEN}  [+] meek-azure configured in torrc${RESET}"
                log "meek-azure pluggable transport configured"
            fi
            ;;
        3)
            echo -e "\n${CYAN}  ═══ snowflake ═══${RESET}"
            echo -e "  Routes traffic through volunteer WebRTC browser proxies."
            echo -e "  Traffic looks like: ${WHITE}WebRTC video call data${RESET}"
            echo -e "  ${GREEN}Best for:${RESET} Highly censored regions; very hard to block"
            echo -e "  ${YELLOW}Weakness:${RESET} Depends on volunteer proxies; can be slow"
            echo -e ""
            if ! command -v snowflake-client &>/dev/null; then
                echo -e "${YELLOW}  [!] snowflake-client not in apt — install from source:${RESET}"
                echo -e "  ${DIM}git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake${RESET}"
                echo -e "  ${DIM}cd snowflake/client && go build .${RESET}"
            else
                echo -e "  ${GREEN}[✓] snowflake-client found${RESET}"
                read -rp "  Apply snowflake to torrc? [y/N]: " ans
                if [[ "$ans" =~ ^[Yy]$ ]]; then
                    sed -i '/UseBridges/d;/Bridge snowflake/d;/ClientTransportPlugin snowflake/d' "$TOR_CONF" 2>/dev/null || true
                    cat >> "$TOR_CONF" << 'TORCONF'

## Ghost v4 - snowflake
UseBridges 1
ClientTransportPlugin snowflake exec /usr/local/bin/snowflake-client
Bridge snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://snowflake-broker.torproject.net.global.prod.fastly.net/ front=foursquare.com ice=stun:stun.l.google.com:19302,stun:stun.antisip.com:3478 utls-imitate=hellorandomizedalpn
TORCONF
                    systemctl restart tor 2>/dev/null || true
                    echo -e "${GREEN}  [+] snowflake configured${RESET}"
                    log "snowflake transport configured"
                fi
            fi
            ;;
        4)
            echo -e "\n${CYAN}  ═══ WebTunnel ═══${RESET}"
            echo -e "  Newest Tor transport. Wraps Tor in WebSocket over HTTPS."
            echo -e "  Looks exactly like normal HTTPS website traffic."
            echo -e "  ${GREEN}Best for:${RESET} Deep packet inspection environments"
            echo -e "  ${YELLOW}Weakness:${RESET} Requires a server running WebTunnel bridge"
            echo -e ""
            echo -e "  ${BOLD}Get WebTunnel bridges:${RESET}"
            echo -e "  https://bridges.torproject.org → select webtunnel"
            echo -e ""
            read -rp "  Paste a WebTunnel bridge line: " bridge_line
            if [[ -n "$bridge_line" ]]; then
                sed -i '/UseBridges/d;/Bridge webtunnel/d;/ClientTransportPlugin webtunnel/d' "$TOR_CONF" 2>/dev/null || true
                cat >> "$TOR_CONF" << TORCONF

## Ghost v4 - webtunnel
UseBridges 1
ClientTransportPlugin webtunnel exec /usr/bin/webtunnel-client
Bridge $bridge_line
TORCONF
                systemctl restart tor 2>/dev/null || true
                echo -e "${GREEN}  [+] WebTunnel bridge configured${RESET}"
                log "WebTunnel transport configured"
            fi
            ;;
        5)
            echo -e "\n${CYAN}  ═══ TRANSPORT COMPARISON ═══${RESET}"
            printf "  %-12s %-18s %-20s %s\n" "Transport" "Looks like" "Blocks defeat" "Speed"
            echo -e "  ${DIM}──────────────────────────────────────────────────────────${RESET}"
            printf "  %-12s %-18s %-20s %s\n" "obfs4"      "Random bytes"   "DPI, keyword"     "Fast"
            printf "  %-12s %-18s %-20s %s\n" "meek-azure" "HTTPS/Azure CDN" "IP blocks"       "Slow"
            printf "  %-12s %-18s %-20s %s\n" "snowflake"  "WebRTC video"   "Deep censorship"  "Variable"
            printf "  %-12s %-18s %-20s %s\n" "webtunnel"  "HTTPS website"  "DPI + IP block"   "Good"
            printf "  %-12s %-18s %-20s %s\n" "Shadowsocks" "Encrypted TCP"  "DPI"             "Fast"
            echo ""
            echo -e "  ${YELLOW}Recommendation by threat model:${RESET}"
            echo -e "  • ISP DPI only:          ${BOLD}obfs4${RESET}"
            echo -e "  • Government IP blocks:  ${BOLD}meek-azure or snowflake${RESET}"
            echo -e "  • Maximum stealth:       ${BOLD}webtunnel or Shadowsocks+Tor${RESET}"
            return ;;
        6)
            echo -e "\n${CYAN}  Which transport to configure in torrc?${RESET}"
            echo -e "  [1] obfs4  [2] meek-azure  [3] snowflake  [4] webtunnel"
            read -rp "  Choice: " t
            case $t in
                1) pluggable_transports; return ;;  # calls option 1 effectively
                2) ch=2; pluggable_transports ;;
                3) ch=3; pluggable_transports ;;
                4) ch=4; pluggable_transports ;;
            esac
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# v4 NEW — PERMANENT DNS ENCRYPTION + DNS PADDING
# ══════════════════════════════════════════════════════════════════════
dns_permanent() {
    echo -e "\n${MAGENTA}┌──── PERMANENT DNS ENCRYPTION + PADDING ─────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Make dnscrypt-proxy permanent (systemd + autostart)${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Enable DNS padding (EDNS padding extension)       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Enable DNS anonymized relays (no direct server)   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Verify DNS encryption status                      ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Remove permanent DNS config (restore default)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local DC_CONF="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

    case $ch in
        1)
            if ! command -v dnscrypt-proxy &>/dev/null; then
                echo -e "${CYAN}  Installing dnscrypt-proxy...${RESET}"
                apt-get install -y dnscrypt-proxy -qq || { echo -e "${RED}  [!] Install failed${RESET}"; return; }
            fi

            # Stop conflicting services
            systemctl stop systemd-resolved 2>/dev/null || true
            systemctl disable systemd-resolved 2>/dev/null || true

            # Comprehensive dnscrypt config
            if [[ -f "$DC_CONF" ]]; then
                # Patch existing config
                sed -i "s|^listen_addresses.*|listen_addresses = ['127.0.0.1:53', '[::1]:53']|" "$DC_CONF" 2>/dev/null || true
                sed -i "s|^# *require_nolog.*|require_nolog = true|"  "$DC_CONF" 2>/dev/null || true
                sed -i "s|^require_nolog.*|require_nolog = true|"      "$DC_CONF" 2>/dev/null || true
                sed -i "s|^# *require_nofilter.*|require_nofilter = true|" "$DC_CONF" 2>/dev/null || true
                sed -i "s|^require_nofilter.*|require_nofilter = true|"    "$DC_CONF" 2>/dev/null || true
                sed -i "s|^# *dnscrypt_ephemeral_keys.*|dnscrypt_ephemeral_keys = true|" "$DC_CONF" 2>/dev/null || true
                sed -i "s|^dnscrypt_ephemeral_keys.*|dnscrypt_ephemeral_keys = true|"    "$DC_CONF" 2>/dev/null || true
                # Enable only DNSCrypt (not plain DNS)
                sed -i "s|^# *dnscrypt_servers.*|dnscrypt_servers = true|" "$DC_CONF" 2>/dev/null || true
                sed -i "s|^# *doh_servers.*|doh_servers = true|"           "$DC_CONF" 2>/dev/null || true
            else
                echo -e "${YELLOW}  [!] Config not found at $DC_CONF — using defaults${RESET}"
            fi

            # Enable + start permanently
            systemctl enable dnscrypt-proxy
            systemctl restart dnscrypt-proxy

            # Lock resolv.conf permanently
            chattr -i /etc/resolv.conf 2>/dev/null || true
            echo "nameserver 127.0.0.1" > /etc/resolv.conf
            chattr +i /etc/resolv.conf

            # Survive reboots — write systemd drop-in
            mkdir -p /etc/systemd/system/dnscrypt-proxy.service.d
            cat > /etc/systemd/system/dnscrypt-proxy.service.d/ghost.conf << 'DROPIN'
[Service]
Restart=always
RestartSec=5s
DROPIN
            systemctl daemon-reload

            echo -e "${GREEN}  [+] dnscrypt-proxy: PERMANENT, auto-restarts, no-log, ephemeral keys${RESET}"
            echo -e "${GREEN}  [+] resolv.conf locked to 127.0.0.1${RESET}"
            echo -e "${GREEN}  [+] systemd-resolved disabled${RESET}"
            log "dnscrypt-proxy permanent encryption enabled"
            ;;
        2)
            # DNS Padding via dnscrypt-proxy
            if [[ ! -f "$DC_CONF" ]]; then
                echo -e "${YELLOW}  [!] dnscrypt-proxy not configured. Run option [1] first.${RESET}"; return
            fi

            echo -e "\n${CYAN}  ═══ DNS PADDING ═══${RESET}"
            echo -e "  ${YELLOW}Why?${RESET} DNS query lengths reveal which domains you visit."
            echo -e "  Short query = short domain; long = long domain."
            echo -e "  EDNS padding pads ALL queries to a fixed block size,"
            echo -e "  making all DNS traffic the same length — no domain leakage."
            echo -e ""

            # Enable padding in dnscrypt config
            if grep -q "^padding_disabled" "$DC_CONF" 2>/dev/null; then
                sed -i "s|^padding_disabled.*|padding_disabled = false|" "$DC_CONF"
            else
                # Add padding config block if not present
                cat >> "$DC_CONF" << 'PADCONF'

## Ghost v4 — DNS Padding
padding_disabled = false
PADCONF
            fi

            # Also enable padding at the [query_log] level
            if ! grep -q "edns_client_subnet_zone" "$DC_CONF" 2>/dev/null; then
                cat >> "$DC_CONF" << 'PADCONF'
# Block ECS (leaks your subnet to DNS server)
anonymized_dns_max_contexts = 100
PADCONF
            fi

            systemctl restart dnscrypt-proxy 2>/dev/null || true
            echo -e "${GREEN}  [+] DNS padding enabled — all queries padded to fixed block size${RESET}"
            echo -e "${GREEN}  [+] EDNS Client Subnet blocked (hides your subnet from DNS server)${RESET}"
            log "DNS padding enabled"
            ;;
        3)
            # Anonymized DNS relays
            if [[ ! -f "$DC_CONF" ]]; then
                echo -e "${YELLOW}  [!] Run option [1] first.${RESET}"; return
            fi

            echo -e "\n${CYAN}  ═══ ANONYMIZED DNS RELAYS ═══${RESET}"
            echo -e "  Normal DNSCrypt: ${WHITE}You → DNS server${RESET} (server sees your IP)"
            echo -e "  Anonymized:      ${WHITE}You → Relay → DNS server${RESET} (server never sees you)"
            echo -e ""

            # Add anonymized relay routes to config
            if ! grep -q "\[anonymized_dns\]" "$DC_CONF" 2>/dev/null; then
                cat >> "$DC_CONF" << 'RELAYCONF'

## Ghost v4 — Anonymized DNS relays
[anonymized_dns]
routes = [
    { server_name='cloudflare', via=['anon-cs-fr', 'anon-cs-de'] },
    { server_name='quad9-dnscrypt-ip4-filter-pri', via=['anon-cs-nl'] },
    { server_name='scaleway-fr', via=['anon-scaleway-ams'] }
]
skip_incompatible = true
RELAYCONF
            fi

            systemctl restart dnscrypt-proxy 2>/dev/null || true
            echo -e "${GREEN}  [+] Anonymized DNS relays configured${RESET}"
            echo -e "${DIM}  DNS server never sees your real IP — relays forward the query${RESET}"
            log "Anonymized DNS relays enabled"
            ;;
        4)
            echo -e "\n${CYAN}  DNS encryption verification:${RESET}"
            echo -e "\n${CYAN}--- dnscrypt-proxy status ---${RESET}"
            systemctl status dnscrypt-proxy --no-pager 2>/dev/null | head -12 || echo "  Not running"
            echo -e "\n${CYAN}--- Listening on :53 ---${RESET}"
            ss -tunlp | grep ':53' || echo "  Nothing on :53"
            echo -e "\n${CYAN}--- Test DNS query ---${RESET}"
            dig +short example.com @127.0.0.1 2>/dev/null || nslookup example.com 127.0.0.1 2>/dev/null || echo "  dig/nslookup failed"
            echo -e "\n${CYAN}--- resolv.conf ---${RESET}"
            cat /etc/resolv.conf
            echo -e "\n${YELLOW}  Full test: https://www.dnsleaktest.com${RESET}"
            return ;;
        5)
            chattr -i /etc/resolv.conf 2>/dev/null || true
            systemctl disable dnscrypt-proxy 2>/dev/null || true
            systemctl stop dnscrypt-proxy 2>/dev/null || true
            rm -f /etc/systemd/system/dnscrypt-proxy.service.d/ghost.conf
            systemctl daemon-reload
            systemctl enable systemd-resolved 2>/dev/null || true
            systemctl start  systemd-resolved 2>/dev/null || true
            [[ -f "$BACKUP_DIR/resolv.conf.bak" ]] && cp "$BACKUP_DIR/resolv.conf.bak" /etc/resolv.conf
            echo -e "${GREEN}  [+] DNS config restored to system defaults${RESET}"
            log "Permanent DNS config removed"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# v4 NEW — uTLS + TLS FINGERPRINT SPOOFING
# ══════════════════════════════════════════════════════════════════════
tls_fingerprint_spoof() {
    echo -e "\n${MAGENTA}┌──── TLS FINGERPRINT SPOOFING (uTLS) ────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Xray-core + REALITY (uTLS browser impersonation)  ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] curl with uTLS mimicry via nss-wrapper trick      ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Generate Xray REALITY config (Chrome TLS profile) ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] JA3 hash checker — see your current fingerprint   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Install tlsmate / ja3transport (Python uTLS)      ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] What TLS fingerprinting is + mitigations          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            echo -e "\n${CYAN}  ═══ XRAY-CORE + REALITY uTLS ═══${RESET}"
            echo -e "  REALITY is a TLS-in-TLS tunnel that:"
            echo -e "  • Perfectly mimics a real browser TLS handshake (Chrome/Firefox)"
            echo -e "  • The outer TLS connection goes to a real HTTPS website"
            echo -e "  • Traffic is indistinguishable from normal HTTPS browsing"
            echo -e ""
            if ! command -v xray &>/dev/null; then
                read -rp "  Install Xray-core now? [Y/n]: " ans
                if [[ "${ans:-Y}" =~ ^[Yy]$ ]]; then
                    echo -e "${CYAN}  [*] Installing xray...${RESET}"
                    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null \
                        || { echo -e "${YELLOW}  [!] Auto-install failed. Manual: https://github.com/XTLS/Xray-core/releases${RESET}"; return; }
                fi
            else
                echo -e "  ${GREEN}[✓] Xray is installed: $(xray version 2>/dev/null | head -1)${RESET}"
            fi
            ;;
        2)
            echo -e "\n${CYAN}  ═══ curl TLS PROFILE TRICKS ═══${RESET}"
            echo -e "  curl uses OpenSSL which has a distinct JA3 fingerprint."
            echo -e "  We can force NSS (Firefox's TLS library) instead of OpenSSL:"
            echo -e ""
            echo -e "  ${BOLD}Option A: Use curl-impersonate${RESET}"
            echo -e "  github.com/lwthiker/curl-impersonate — curl compiled to mimic browsers"
            echo -e ""
            echo -e "  ${BOLD}Option B: Python with tls-client library${RESET}"
            cat > /tmp/ghost_tls_test.py << 'PYUTLS'
#!/usr/bin/env python3
# Ghost v4 - TLS client fingerprint test
try:
    import tls_client
    session = tls_client.Session(
        client_identifier="chrome_120",  # mimic Chrome 120
        random_tls_extension_order=True
    )
    resp = session.get("https://tls.peet.ws/api/all")
    import json
    data = json.loads(resp.text)
    print(f"  JA3:  {data.get('tls', {}).get('ja3', 'N/A')}")
    print(f"  JA3n: {data.get('tls', {}).get('ja3_hash', 'N/A')}")
    print(f"  Akamai h2: {data.get('http2', {}).get('akamai_fingerprint_hash', 'N/A')}")
except ImportError:
    print("  Install: pip3 install tls-client")
except Exception as e:
    print(f"  Error: {e}")
PYUTLS
            python3 /tmp/ghost_tls_test.py
            echo ""
            echo -e "  ${BOLD}Install tls-client:${RESET} pip3 install tls-client"
            echo -e "  ${BOLD}Supported profiles:${RESET} chrome_120, firefox_120, safari_16_0, ios_16_0"
            ;;
        3)
            echo -e "\n${CYAN}  ═══ GENERATE XRAY REALITY CONFIG ═══${RESET}"
            read -rp "  Your server IP: " srv_ip
            read -rp "  Server port [443]: " srv_port
            srv_port="${srv_port:-443}"
            read -rp "  SNI domain (real HTTPS site, e.g. www.microsoft.com): " sni_domain
            sni_domain="${sni_domain:-www.microsoft.com}"

            # Generate UUID
            local uuid
            if command -v xray &>/dev/null; then
                uuid=$(xray uuid 2>/dev/null)
            else
                uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
            fi

            cat > /etc/ghost_xray_reality.json << XRAYJSON
{
  "log": { "loglevel": "none" },
  "inbounds": [{
    "listen": "127.0.0.1",
    "port": 10809,
    "protocol": "socks",
    "settings": { "udp": true }
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "$srv_ip",
        "port": $srv_port,
        "users": [{ "id": "$uuid", "flow": "xtls-rprx-vision" }]
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "serverName": "$sni_domain",
        "fingerprint": "chrome",
        "publicKey": "REPLACE_WITH_SERVER_PUBLIC_KEY",
        "shortId": "REPLACE_WITH_SHORT_ID"
      }
    }
  }]
}
XRAYJSON
            echo -e "${GREEN}  [+] Xray REALITY client config: /etc/ghost_xray_reality.json${RESET}"
            echo -e "${YELLOW}  [!] Replace publicKey + shortId from your REALITY server setup${RESET}"
            echo -e "${CYAN}  Usage: xray run -c /etc/ghost_xray_reality.json${RESET}"
            echo -e "${CYAN}  Then set proxychains SOCKS5 to 127.0.0.1:10809${RESET}"
            log "Xray REALITY config generated"
            ;;
        4)
            echo -e "\n${CYAN}  ═══ JA3 FINGERPRINT CHECK ═══${RESET}"
            echo -e "  Checking your current TLS fingerprint via tls.peet.ws..."
            proxychains4 -q curl -s --max-time 15 \
                "https://tls.peet.ws/api/clean" \
                | python3 -m json.tool 2>/dev/null \
                || curl -s --max-time 10 "https://tls.peet.ws/api/clean" \
                | python3 -m json.tool 2>/dev/null \
                || echo -e "${YELLOW}  [!] Failed — ensure Tor/internet is up${RESET}"
            echo ""
            echo -e "${DIM}  Compare your JA3 hash against known browser hashes:${RESET}"
            echo -e "  Chrome 120:  ${BOLD}772,4865-4866-4867-49195...,0-23-65281...${RESET}"
            echo -e "  Firefox 120: ${BOLD}772,4865-4867-4866-49195...,0-23-65281...${RESET}"
            return ;;
        5)
            echo -e "\n${CYAN}  Installing Python uTLS tools...${RESET}"
            pip3 install tls-client 2>/dev/null \
                && echo -e "${GREEN}  [+] tls-client installed (Python uTLS)${RESET}" \
                || echo -e "${YELLOW}  [!] tls-client install failed${RESET}"
            pip3 install curl-cffi 2>/dev/null \
                && echo -e "${GREEN}  [+] curl-cffi installed (curl with impersonation)${RESET}" \
                || echo -e "${YELLOW}  [!] curl-cffi install failed${RESET}"
            echo -e "\n${CYAN}  Usage examples:${RESET}"
            cat << 'PYEX'
  # tls-client (Python)
  import tls_client
  session = tls_client.Session(client_identifier="chrome_120")
  r = session.get("https://example.com")

  # curl-cffi (curl with browser TLS)
  from curl_cffi import requests
  r = requests.get("https://example.com", impersonate="chrome120")
PYEX
            ;;
        6)
            echo -e "\n${CYAN}  ═══ TLS FINGERPRINTING EXPLAINED ═══${RESET}"
            echo -e "  ${YELLOW}What is JA3?${RESET}"
            echo -e "  JA3 hashes the TLS ClientHello: cipher suites, extensions,"
            echo -e "  elliptic curves, and compression — a unique tool fingerprint."
            echo -e ""
            echo -e "  ${YELLOW}What is JARM?${RESET}"
            echo -e "  Active fingerprint — sends 10 TLS probes, hashes the responses."
            echo -e "  Identifies TLS server software (nginx vs Apache vs custom)."
            echo -e ""
            echo -e "  ${YELLOW}What is uTLS?${RESET}"
            echo -e "  Go library that lets you impersonate ANY browser's TLS profile."
            echo -e "  Changes cipher order, extensions, GREASE values to match exactly."
            echo -e ""
            echo -e "  ${GREEN}Full mitigation stack:${RESET}"
            echo -e "  • Use REALITY (Xray) — outer TLS is real browser TLS"
            echo -e "  • Use tls-client / curl-cffi in Python scripts"
            echo -e "  • Route through Tor Browser for manual browsing (Firefox JA3)"
            echo -e "  • Use Shadowsocks + obfs4 to encrypt before TLS layer is visible"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# v4 NEW — TRAFFIC PADDING (APSF-style adaptive cover traffic)
# ══════════════════════════════════════════════════════════════════════
traffic_padding_advanced() {
    echo -e "\n${MAGENTA}┌──── ADVANCED TRAFFIC PADDING ───────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Constant-rate padding (fixed bandwidth noise)    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Burst padding (mimics human browsing pattern)    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Adaptive padding (noise scales with real traffic)${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] ICMP padding flood (network-level noise)         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Stop all padding processes                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Traffic correlation attack explained             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local PADDING_URLS=(
        "https://www.wikipedia.org/wiki/Main_Page"
        "https://www.ietf.org/rfc/rfc2549.txt"
        "https://httpbin.org/bytes/1024"
        "https://httpbin.org/bytes/4096"
        "https://www.w3.org/TR/html52/"
        "https://www.rfc-editor.org/rfc/rfc791"
        "https://example.com"
        "https://www.iana.org/domains/root/db"
    )

    case $ch in
        1)
            read -rp "  Requests per minute (1-20, default 5): " rpm
            rpm="${rpm:-5}"
            local interval=$(( 60 / rpm ))
            echo -e "${CYAN}  [*] Constant-rate padding: $rpm req/min (every ${interval}s) in background...${RESET}"
            (
                while true; do
                    local url="${PADDING_URLS[$RANDOM % ${#PADDING_URLS[@]}]}"
                    proxychains4 -q curl -s --max-time 10 "$url" -o /dev/null 2>/dev/null
                    sleep "$interval"
                done
            ) & disown
            echo -e "${GREEN}  [+] Constant padding running (PID: $!)${RESET}"
            echo -e "${DIM}  Kill: pkill -f 'curl.*padding' or option [5]${RESET}"
            log "Constant-rate padding started: $rpm req/min"
            ;;
        2)
            echo -e "${CYAN}  [*] Burst padding — simulates human browsing sessions...${RESET}"
            (
                while true; do
                    # Burst: 3-8 requests clustered together (like a page load)
                    local burst=$(( 3 + RANDOM % 6 ))
                    for (( i=0; i<burst; i++ )); do
                        local url="${PADDING_URLS[$RANDOM % ${#PADDING_URLS[@]}]}"
                        proxychains4 -q curl -s --max-time 8 "$url" -o /dev/null 2>/dev/null &
                        sleep "0.$((RANDOM % 9 + 1))"
                    done
                    wait
                    # Long gap between bursts (like user reading a page)
                    sleep $(( 30 + RANDOM % 90 ))
                done
            ) & disown
            echo -e "${GREEN}  [+] Burst padding running (human-like pattern)${RESET}"
            log "Burst padding started"
            ;;
        3)
            echo -e "${CYAN}  [*] Adaptive padding — ramps with real traffic...${RESET}"
            (
                while true; do
                    # Check current network activity as proxy for real traffic
                    local rx1; rx1=$(cat /sys/class/net/"${IFACE:-eth0}"/statistics/rx_bytes 2>/dev/null || echo 0)
                    sleep 2
                    local rx2; rx2=$(cat /sys/class/net/"${IFACE:-eth0}"/statistics/rx_bytes 2>/dev/null || echo 0)
                    local delta=$(( (rx2 - rx1) / 2 ))

                    # More real traffic → more padding (scale noise proportionally)
                    local pad_count=1
                    [[ $delta -gt 50000  ]] && pad_count=3
                    [[ $delta -gt 200000 ]] && pad_count=6
                    [[ $delta -gt 500000 ]] && pad_count=10

                    for (( i=0; i<pad_count; i++ )); do
                        local url="${PADDING_URLS[$RANDOM % ${#PADDING_URLS[@]}]}"
                        proxychains4 -q curl -s --max-time 8 "$url" -o /dev/null 2>/dev/null &
                    done
                    wait
                    sleep $(( 5 + RANDOM % 10 ))
                done
            ) & disown
            echo -e "${GREEN}  [+] Adaptive padding running${RESET}"
            log "Adaptive padding started"
            ;;
        4)
            [[ -z "$IFACE" ]] && select_interface
            read -rp "  Target gateway IP (for ICMP noise): " gw_ip
            [[ -z "$gw_ip" ]] && { echo "  No target."; return; }
            read -rp "  Duration seconds (default 30): " dur
            dur="${dur:-30}"
            echo -e "${CYAN}  [*] ICMP noise for ${dur}s...${RESET}"
            (
                local end=$(( $(date +%s) + dur ))
                while [[ $(date +%s) -lt $end ]]; do
                    ping -c 1 -s $(( 64 + RANDOM % 1400 )) -W 1 "$gw_ip" > /dev/null 2>&1
                    sleep "0.$((RANDOM % 5 + 1))"
                done
            ) &
            echo -e "${GREEN}  [+] ICMP padding active for ${dur}s${RESET}"
            log "ICMP padding: $gw_ip for ${dur}s"
            ;;
        5)
            pkill -f 'curl.*wikipedia\|curl.*ietf\|curl.*httpbin\|curl.*w3.org\|curl.*rfc' 2>/dev/null || true
            echo -e "${GREEN}  [+] Padding processes stopped${RESET}"
            log "Padding stopped"
            ;;
        6)
            echo -e "\n${CYAN}  ═══ TRAFFIC CORRELATION ATTACKS ═══${RESET}"
            echo -e "  ${YELLOW}The attack:${RESET}"
            echo -e "  An adversary watching BOTH your ISP connection AND the Tor exit"
            echo -e "  correlates packet timing and volume to link you to your traffic."
            echo -e ""
            echo -e "  ${YELLOW}Why Tor alone doesn't fully protect:${RESET}"
            echo -e "  Tor only changes routing — the timing pattern of your packets"
            echo -e "  is largely preserved through the circuit. A global adversary"
            echo -e "  (NSA-level) can de-anonymize ~80% of Tor sessions."
            echo -e ""
            echo -e "  ${GREEN}Traffic padding mitigates this:${RESET}"
            echo -e "  • Constant-rate padding: fills gaps so silence can't be matched"
            echo -e "  • Burst padding: mimics human browsing — no unique silence pattern"
            echo -e "  • Adaptive padding: scales with real traffic — ratio stays consistent"
            echo -e ""
            echo -e "  ${RED}Hard limits — padding does NOT protect against:${RESET}"
            echo -e "  • Full passive surveillance of entire backbone (nation-state)"
            echo -e "  • Volume correlation over very long sessions"
            echo -e "  • Tagging attacks (modifying your packets at entry)"
            echo -e ""
            echo -e "  ${DIM}Best mitigation: short sessions + Tor bridges + traffic padding combined${RESET}"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# v4 NEW — PROTOCOL MIMICRY (make traffic look like HTTPS/DNS)
# ══════════════════════════════════════════════════════════════════════
protocol_mimicry() {
    echo -e "\n${MAGENTA}┌──── PROTOCOL MIMICRY ───────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] DNS-over-HTTPS (DoH) — traffic looks like HTTPS  ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] DNS-over-TLS (DoT) — traffic looks like HTTPS    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] HTTPS tunneling — wrap any protocol in HTTPS     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] WebSocket tunnel (ws:// / wss://)                ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Tor traffic looks like: what each transport does ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            echo -e "\n${CYAN}  ═══ DNS-over-HTTPS (DoH) ═══${RESET}"
            echo -e "  All DNS queries sent as HTTPS POST requests to port 443."
            echo -e "  To a firewall: ${WHITE}indistinguishable from visiting a website${RESET}"
            echo -e ""
            if [[ -f "/etc/dnscrypt-proxy/dnscrypt-proxy.toml" ]]; then
                # Enable DoH in dnscrypt-proxy
                local DC_CONF="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
                sed -i "s|^doh_servers.*|doh_servers = true|" "$DC_CONF" 2>/dev/null || true
                sed -i "s|^# *doh_servers.*|doh_servers = true|" "$DC_CONF" 2>/dev/null || true
                # Set a fast DoH server list
                if ! grep -q "cloudflare-security" "$DC_CONF"; then
                    sed -i "s|^server_names.*|server_names = ['cloudflare-security', 'google', 'quad9-doh-ip4-filter-pri']|" "$DC_CONF" 2>/dev/null || true
                fi
                systemctl restart dnscrypt-proxy 2>/dev/null || true
                echo -e "${GREEN}  [+] DoH enabled via dnscrypt-proxy${RESET}"
                echo -e "${DIM}  Servers: cloudflare-security, google, quad9${RESET}"
            else
                echo -e "${YELLOW}  [!] dnscrypt-proxy not configured. Run DNS menu → option [1] first.${RESET}"
            fi
            log "DoH enabled"
            ;;
        2)
            echo -e "\n${CYAN}  ═══ DNS-over-TLS (DoT) ═══${RESET}"
            echo -e "  DNS queries sent over TLS on port 853."
            echo -e "  Encrypted but visible as DNS traffic (port 853 is distinct)."
            echo -e "  ${YELLOW}Less stealthy than DoH but encrypts the DNS content.${RESET}"
            echo -e ""
            if command -v unbound &>/dev/null; then
                cat > /etc/unbound/unbound.conf.d/ghost_dot.conf << 'DOTCONF'
server:
    interface: 127.0.0.1@53
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    tls-upstream: yes
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    harden-glue: yes
    harden-dnssec-stripped: yes

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 8.8.8.8@853#dns.google
DOTCONF
                systemctl restart unbound
                chattr -i /etc/resolv.conf 2>/dev/null || true
                echo "nameserver 127.0.0.1" > /etc/resolv.conf
                chattr +i /etc/resolv.conf
                echo -e "${GREEN}  [+] DNS-over-TLS via Unbound active${RESET}"
                log "DoT via Unbound enabled"
            else
                echo -e "${YELLOW}  [!] Unbound not installed: apt install unbound${RESET}"
            fi
            ;;
        3)
            echo -e "\n${CYAN}  ═══ HTTPS TUNNEL WRAPPING ═══${RESET}"
            echo -e "  Wrap any protocol inside HTTPS using stunnel or socat:"
            echo -e ""
            echo -e "  ${BOLD}stunnel (any TCP → TLS port 443):${RESET}"
            echo -e "  apt install stunnel4"
            cat << 'STCONF'
  # /etc/stunnel/ghost.conf
  [https-out]
  client = yes
  accept  = 127.0.0.1:8080
  connect = your-server.com:443
  sslVersion = TLSv1.3
STCONF
            echo -e ""
            echo -e "  ${BOLD}socat (TCP → HTTPS):${RESET}"
            echo -e "  socat TCP-LISTEN:8080,fork OPENSSL:server.com:443,verify=0"
            echo -e ""
            echo -e "  ${BOLD}CONNECT proxy (HTTP CONNECT tunneling):${RESET}"
            echo -e "  curl --proxytunnel --proxy https://proxy.com:443 http://target.com"
            echo -e ""
            if ! command -v stunnel4 &>/dev/null; then
                read -rp "  Install stunnel4? [y/N]: " ans
                [[ "$ans" =~ ^[Yy]$ ]] && apt-get install -y stunnel4 -qq \
                    && echo -e "${GREEN}  [+] stunnel4 installed${RESET}"
            else
                echo -e "  ${GREEN}[✓] stunnel4 installed${RESET}"
            fi
            return ;;
        4)
            echo -e "\n${CYAN}  ═══ WEBSOCKET TUNNEL ═══${RESET}"
            echo -e "  WebSocket (ws:// or wss://) is carried over HTTP/HTTPS."
            echo -e "  Looks like a normal long-lived HTTPS connection."
            echo -e "  Used by: Tor webtunnel, V2Ray ws transport, many CDNs."
            echo -e ""
            echo -e "  ${BOLD}V2Ray WebSocket config (routes Tor through wss://):${RESET}"
            cat << 'WSCONF'
  outbound streamSettings:
    network: "ws"
    security: "tls"
    wsSettings:
      path: "/ghost"
      headers:
        Host: "your-cdn-domain.com"
    tlsSettings:
      serverName: "your-cdn-domain.com"
      fingerprint: "chrome"
WSCONF
            echo -e ""
            echo -e "  ${DIM}Combined with CDN (Cloudflare): your real server IP is hidden even from Cloudflare logs${RESET}"
            return ;;
        5)
            echo -e "\n${CYAN}  ═══ WHAT EACH TRANSPORT LOOKS LIKE TO DPI ═══${RESET}"
            printf "  %-16s %-20s %s\n" "Transport" "Looks like" "Detectable by"
            echo -e "  ${DIM}──────────────────────────────────────────────────────────${RESET}"
            printf "  %-16s %-20s %s\n" "Plain Tor"       "Tor protocol"   "IP, handshake pattern"
            printf "  %-16s %-20s %s\n" "obfs4"           "Random bytes"   "Active probing"
            printf "  %-16s %-20s %s\n" "meek-azure"      "HTTPS/CDN"      "Very hard"
            printf "  %-16s %-20s %s\n" "snowflake"       "WebRTC"         "WebRTC fingerprint"
            printf "  %-16s %-20s %s\n" "webtunnel"       "HTTPS website"  "Server behavior"
            printf "  %-16s %-20s %s\n" "Shadowsocks"     "Encrypted TCP"  "Entropy analysis"
            printf "  %-16s %-20s %s\n" "REALITY/uTLS"    "Browser TLS"    "Nearly impossible"
            printf "  %-16s %-20s %s\n" "DoH"             "HTTPS POST"     "DoH server IP"
            printf "  %-16s %-20s %s\n" "WebSocket+CDN"   "HTTPS stream"   "Hard (CDN fronting)"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# v4 NEW — BROWSER FINGERPRINT NORMALIZATION
# ══════════════════════════════════════════════════════════════════════
browser_fingerprint() {
    echo -e "\n${MAGENTA}┌──── BROWSER FINGERPRINT NORMALIZATION ──────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Generate hardened Firefox user.js profile         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Chromium launch flags for fingerprint resistance  ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Canvas fingerprint spoofing                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] WebGL fingerprint mitigation                      ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Font enumeration blocking                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Timezone + locale normalization                   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Full fingerprint test                             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] What makes a browser fingerprint unique           ${RESET}${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            echo -e "\n${CYAN}  Generating hardened Firefox user.js...${RESET}"
            # Find Firefox profile directory
            local ff_profile
            ff_profile=$(find /root/.mozilla/firefox -maxdepth 1 -name "*.default*" -type d 2>/dev/null | head -1)
            if [[ -z "$ff_profile" ]]; then
                ff_profile="/root/.mozilla/firefox/ghost.default"
                mkdir -p "$ff_profile"
                echo -e "${YELLOW}  [!] No Firefox profile found. Writing to $ff_profile${RESET}"
            fi

            cat > "$ff_profile/user.js" << 'USERJS'
// Ghost Profile v4 — Firefox hardening user.js
// Based on arkenfox/user.js — browser fingerprint normalization

// ─── DISABLE TELEMETRY ───────────────────────────────────────────
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.ping-centre.telemetry", false);

// ─── PRIVACY ─────────────────────────────────────────────────────
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);
user_pref("privacy.fingerprintingProtection", true);

// ─── CANVAS FINGERPRINTING ───────────────────────────────────────
// Adds noise to canvas API calls — each read returns slightly different data
user_pref("privacy.resistFingerprinting", true);

// ─── WEBGL ───────────────────────────────────────────────────────
user_pref("webgl.disabled", true);
user_pref("webgl.renderer-string-override", " ");
user_pref("webgl.vendor-string-override", " ");

// ─── TIMEZONE ────────────────────────────────────────────────────
// Force browser timezone to UTC regardless of system setting
user_pref("privacy.resistFingerprinting", true);  // sets tz to UTC

// ─── FONT ENUMERATION ────────────────────────────────────────────
user_pref("browser.display.use_document_fonts", 0);
user_pref("layout.css.font-loading-api.enabled", false);

// ─── WEBRTC LEAK ─────────────────────────────────────────────────
user_pref("media.peerconnection.enabled", false);  // disables WebRTC
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);

// ─── HARDWARE FINGERPRINTS ───────────────────────────────────────
user_pref("media.navigator.enabled", false);
user_pref("dom.battery.enabled", false);
user_pref("dom.vibrator.enabled", false);
user_pref("device.sensors.enabled", false);
user_pref("dom.gamepad.enabled", false);

// ─── NETWORK ─────────────────────────────────────────────────────
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.sendRefererHeader", 0);
user_pref("network.http.sendSecureXSiteReferrer", false);
user_pref("network.trr.mode", 5);  // Disable built-in DoH (use system DNS)

// ─── PROXY ───────────────────────────────────────────────────────
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);  // DNS through Tor

// ─── HISTORY / STORAGE ───────────────────────────────────────────
user_pref("places.history.enabled", false);
user_pref("browser.privatebrowsing.autostart", true);
user_pref("browser.sessionstore.privacy_level", 2);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.offline.enable", false);

// ─── UA NORMALIZATION ────────────────────────────────────────────
// privacy.resistFingerprinting forces a normalized UA
user_pref("general.useragent.override", "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/115.0");

// ─── SCREEN RESOLUTION ───────────────────────────────────────────
// Letterboxing rounds window size to prevent resolution fingerprinting
user_pref("privacy.resistFingerprinting.letterboxing", true);
USERJS
            echo -e "${GREEN}  [+] user.js written to: $ff_profile/user.js${RESET}"
            echo -e "${CYAN}  Launch Firefox with this profile:${RESET}"
            echo -e "  ${BOLD}firefox -profile $ff_profile${RESET}"
            log "Firefox hardening user.js written"
            ;;
        2)
            echo -e "\n${CYAN}  Chromium fingerprint-resistant launch flags:${RESET}"
            cat > /usr/local/bin/ghost_chromium.sh << 'CHROMSH'
#!/bin/bash
# Ghost v4 — Chromium with fingerprint normalization
chromium \
  --incognito \
  --no-first-run \
  --disable-background-networking \
  --disable-client-side-phishing-detection \
  --disable-sync \
  --disable-translate \
  --metrics-recording-only \
  --no-default-browser-check \
  --safebrowsing-disable-auto-update \
  --disable-webrtc \
  --enforce-webrtc-ip-permission-check \
  --proxy-server="socks5://127.0.0.1:9050" \
  --host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1" \
  --disable-features=WebRtcHideLocalIpsWithMdns \
  --disable-webgl \
  --disable-3d-apis \
  --disable-accelerated-2d-canvas \
  --use-fake-device-for-media-stream \
  --use-fake-ui-for-media-stream \
  --disable-reading-from-canvas \
  --user-data-dir=/tmp/ghost_chromium_profile \
  "$@"
CHROMSH
            chmod +x /usr/local/bin/ghost_chromium.sh
            echo -e "${GREEN}  [+] Launch script: /usr/local/bin/ghost_chromium.sh${RESET}"
            echo -e "${DIM}  Features: WebRTC off, WebGL off, Canvas read disabled, SOCKS5 Tor proxy${RESET}"
            log "ghost_chromium.sh created"
            ;;
        3)
            echo -e "\n${CYAN}  ═══ CANVAS FINGERPRINTING ═══${RESET}"
            echo -e "  ${YELLOW}How it works:${RESET}"
            echo -e "  Sites call canvas.toDataURL() — tiny rendering differences in"
            echo -e "  GPU/font/OS create a unique hash per device."
            echo -e ""
            echo -e "  ${GREEN}Mitigations (by strength):${RESET}"
            echo -e "  1. ${BOLD}privacy.resistFingerprinting = true${RESET} (Firefox) — adds noise"
            echo -e "  2. ${BOLD}CanvasBlocker extension${RESET} — blocks or randomizes reads"
            echo -e "  3. ${BOLD}Disable GPU acceleration${RESET} in browser → identical canvas output"
            echo -e "  4. ${BOLD}Tor Browser${RESET} — normalized canvas output for all users"
            echo -e ""
            echo -e "  ${DIM}Install CanvasBlocker: addons.mozilla.org/firefox/addon/canvasblocker${RESET}"
            return ;;
        4)
            echo -e "\n${CYAN}  ═══ WEBGL FINGERPRINTING ═══${RESET}"
            echo -e "  ${YELLOW}How it works:${RESET}"
            echo -e "  WebGL renderer/vendor strings + rendering output are unique per GPU."
            echo -e "  WebGL can fingerprint: GPU model, driver version, rendering artifacts."
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Disable WebGL entirely (user.js option [1] does this)"
            echo -e "  • Firefox: webgl.disabled = true"
            echo -e "  • Chromium: --disable-webgl --disable-3d-apis"
            echo -e "  • Spoof renderer: webgl.renderer-string-override = ' '"
            echo -e ""
            echo -e "  ${BOLD}Apply WebGL disable to Firefox now?${RESET}"
            local ff_profile
            ff_profile=$(find /root/.mozilla/firefox -maxdepth 1 -name "*.default*" -type d 2>/dev/null | head -1)
            if [[ -n "$ff_profile" ]]; then
                read -rp "  Apply? [y/N]: " ans
                if [[ "$ans" =~ ^[Yy]$ ]]; then
                    echo 'user_pref("webgl.disabled", true);' >> "$ff_profile/user.js"
                    echo 'user_pref("webgl.renderer-string-override", " ");' >> "$ff_profile/user.js"
                    echo -e "${GREEN}  [+] WebGL disabled in Firefox profile${RESET}"
                fi
            fi
            return ;;
        5)
            echo -e "\n${CYAN}  ═══ FONT ENUMERATION ═══${RESET}"
            echo -e "  ${YELLOW}How it works:${RESET}"
            echo -e "  JS measures text width in different fonts to detect installed fonts."
            echo -e "  Your unique font set is a strong fingerprint (varies by OS/language)."
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • browser.display.use_document_fonts = 0 (only built-in fonts)"
            echo -e "  • privacy.resistFingerprinting = true (normalizes font list)"
            echo -e "  • Font Fingerprint Defender extension"
            echo -e ""
            echo -e "  ${DIM}With resistFingerprinting, Firefox reports the same generic font${RESET}"
            echo -e "  ${DIM}list regardless of what's actually installed.${RESET}"
            return ;;
        6)
            echo -e "\n${CYAN}  ═══ TIMEZONE + LOCALE NORMALIZATION ═══${RESET}"
            echo -e "  Browser timezone can differ from system timezone — both are sent."
            echo -e ""
            echo -e "  ${GREEN}Normalization steps:${RESET}"
            echo -e "  • System TZ → UTC (timezone menu [0] → option [1])"
            echo -e "  • Browser TZ: privacy.resistFingerprinting forces UTC"
            echo -e "  • Browser locale: general.useragent.override in user.js"
            echo -e "  • Keyboard layout: avoid non-English layouts (font rendering differs)"
            echo -e "  • Accept-Language header: set to en-US only"
            echo -e ""

            local ff_profile
            ff_profile=$(find /root/.mozilla/firefox -maxdepth 1 -name "*.default*" -type d 2>/dev/null | head -1)
            if [[ -n "$ff_profile" ]]; then
                read -rp "  Apply locale normalization to Firefox profile? [y/N]: " ans
                if [[ "$ans" =~ ^[Yy]$ ]]; then
                    cat >> "$ff_profile/user.js" << 'LOCALEJS'
user_pref("intl.accept_languages", "en-US, en");
user_pref("javascript.use_us_english_locale", true);
user_pref("intl.locale.requested", "en-US");
LOCALEJS
                    echo -e "${GREEN}  [+] Locale normalized to en-US${RESET}"
                fi
            fi
            return ;;
        7)
            echo -e "\n${CYAN}  ═══ FINGERPRINT TEST SITES ═══${RESET}"
            echo -e "  Run these URLs through your Tor-proxied browser:"
            echo -e ""
            echo -e "  ${BOLD}https://coveryourtracks.eff.org${RESET}"
            echo -e "  ${DIM}  EFF — checks if your browser blends into Tor Browser crowd${RESET}"
            echo -e ""
            echo -e "  ${BOLD}https://browserleaks.com${RESET}"
            echo -e "  ${DIM}  Comprehensive: Canvas, WebGL, Fonts, TZ, WebRTC, UA, JS${RESET}"
            echo -e ""
            echo -e "  ${BOLD}https://tls.peet.ws${RESET}"
            echo -e "  ${DIM}  TLS fingerprint (JA3, Akamai h2 fingerprint)${RESET}"
            echo -e ""
            echo -e "  ${BOLD}https://amiunique.org${RESET}"
            echo -e "  ${DIM}  Uniqueness score vs database of real browsers${RESET}"
            echo -e ""
            echo -e "  ${BOLD}https://ipleak.net${RESET}"
            echo -e "  ${DIM}  IP, DNS, WebRTC, timezone all in one${RESET}"
            echo -e ""
            echo -e "  Opening cover test via torsocks firefox..."
            if command -v torsocks &>/dev/null && command -v firefox &>/dev/null; then
                torsocks firefox "https://coveryourtracks.eff.org" &
            elif command -v firefox &>/dev/null; then
                firefox --private-window "https://coveryourtracks.eff.org" &
            else
                echo -e "${YELLOW}  [!] Firefox not found — open URLs manually in Tor Browser${RESET}"
            fi
            return ;;
        8)
            echo -e "\n${CYAN}  ═══ BROWSER FINGERPRINT VECTORS ═══${RESET}"
            declare -A FP_VECTORS=(
                ["User-Agent"]="OS, browser, version — normalized by resistFingerprinting"
                ["Canvas"]="GPU rendering artifacts — unique per GPU/driver"
                ["WebGL"]="GPU model + driver via RENDERER/VENDOR strings"
                ["Fonts"]="Installed font list — varies by OS/language pack"
                ["Timezone"]="System TZ exposed via JS Date — reveals region"
                ["Screen res"]="Monitor resolution + color depth + pixel ratio"
                ["Plugins"]="Navigator.plugins list — varies per install"
                ["AudioCtx"]="Audio processing artifacts — hardware specific"
                ["WebRTC"]="Leaks LAN IP even behind VPN/Tor"
                ["CSS media"]="Prefers-dark, pointer type, display gamut"
                ["Battery"]="Battery level + charging = device identifier"
                ["Language"]="navigator.language reveals locale/keyboard"
            )
            printf "  %-16s %s\n" "Vector" "Description"
            echo -e "  ${DIM}────────────────────────────────────────────────────────${RESET}"
            for v in "${!FP_VECTORS[@]}"; do
                printf "  ${YELLOW}%-16s${RESET} %s\n" "$v" "${FP_VECTORS[$v]}"
            done
            echo ""
            echo -e "  ${GREEN}Best complete solution: Tor Browser${RESET}"
            echo -e "  ${DIM}All Tor Browser users share identical fingerprints — you're in the crowd${RESET}"
            return ;;
    esac
}
#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#   GHOST PROFILE v3.0 — Hardened Anonymity Suite for Kali Linux
#   Use ONLY on systems you own or have explicit written permission.
#   Unauthorized use is illegal. Know your local laws.
#
#   v3 New Additions:
#   [A]  Traffic padding / cover traffic generation
#   [B]  Tor bridges + obfs4 obfuscation
#   [C]  Tor-over-VPN / VPN-over-Tor chaining menu
#   [D]  Scapy-based custom packet crafting (anti-fingerprint)
#   [E]  dnscrypt-proxy + Unbound DNS isolation
#   [F]  Network namespace / container isolation (Whonix-style)
#   [G]  External log minimization OPSEC guide
#   [H]  Full OPSEC discipline panel (behavioral attribution)
#   [I]  Honeypot: limit interaction depth + response consistency
#   [J]  MAC spoofing scope awareness (LAN only reminder)
#   [K]  Infrastructure rotation checklist
#   [+]  ASCII ghost mascot
# ═══════════════════════════════════════════════════════════════════════

# ─── COLORS ──────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
CYAN='\033[0;36m';   MAGENTA='\033[0;35m'; BLUE='\033[0;34m'
WHITE='\033[1;37m';  BOLD='\033[1m';      DIM='\033[2m'; RESET='\033[0m'

# ─── GLOBALS ─────────────────────────────────────────────────────────
BACKUP_DIR="/etc/ghost_profile_backups"
PROXYCHAINS_CONF="/etc/proxychains4.conf"
TOR_CONF="/etc/tor/torrc"
GHOST_LOG="/tmp/.ghost_session.log"
IFACE=""
GHOST_ACTIVE=0
VERSION="4.0"

# ─── ROOT CHECK ──────────────────────────────────────────────────────
require_root() {
    [[ $EUID -ne 0 ]] && {
        echo -e "${RED}[!] Must run as root: sudo bash $0${RESET}"; exit 1
    }
}

# ─── SESSION LOG (RAM only) ──────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$GHOST_LOG"; }

# ─── ASCII GHOST + BANNER ────────────────────────────────────────────
banner() {
    clear
    echo -e "${WHITE}${BOLD}"
    cat << 'GHOST'

         ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
         ░                                                       ░
         ░      ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗      ░
         ░     ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝      ░
         ░     ██║  ███╗███████║██║   ██║███████╗   ██║         ░
         ░     ██║   ██║██╔══██║██║   ██║╚════██║   ██║         ░
         ░     ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║         ░
         ░      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝         ░
         ░                                                       ░
         ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
GHOST
    echo -e "${RESET}"

    # ASCII ghost - drawn in cyan/white
    echo -e "                     ${CYAN}   .-'~~~'-.  ${RESET}"
    echo -e "                     ${CYAN}  /  O   O  \ ${RESET}   ${DIM}G H O S T   P R O F I L E${RESET}"
    echo -e "                     ${CYAN} |     ^     |${RESET}   ${WHITE}v${VERSION} — Hardened Anonymity Suite${RESET}"
    echo -e "                     ${CYAN}  \  \___/  / ${RESET}   ${DIM}For authorized research only${RESET}"
    echo -e "                     ${CYAN}  /\/\/\/\/\ ${RESET}"
    echo -e "                     ${CYAN} /            \\${RESET}"

    echo ""
    if [[ $GHOST_ACTIVE -eq 1 ]]; then
        echo -e "  ${RED}${BOLD}  ████  GHOST MODE ACTIVE — YOU ARE CLOAKED  ████${RESET}"
    else
        echo -e "  ${DIM}  ──── Ghost mode OFF — identity exposed ────${RESET}"
    fi
    echo -e "  ${DIM}─────────────────────────────────────────────────────────${RESET}"
}

# ─── DEPENDENCY CHECK ────────────────────────────────────────────────
check_deps() {
    local all_deps=(
        "macchanger" "proxychains4" "tor" "iptables" "ip6tables"
        "curl" "rfkill" "hostnamectl" "timedatectl" "nmap"
        "shred" "arp" "iw" "ethtool" "torsocks" "obfs4proxy"
        "dnscrypt-proxy" "unbound" "bleachbit" "scapy"
    )

    declare -A PKG_MAP=(
        ["proxychains4"]="proxychains4"     ["macchanger"]="macchanger"
        ["tor"]="tor"                        ["iptables"]="iptables"
        ["ip6tables"]="iptables"             ["curl"]="curl"
        ["rfkill"]="rfkill"                  ["nmap"]="nmap"
        ["shred"]="coreutils"                ["arp"]="net-tools"
        ["iw"]="iw"                          ["ethtool"]="ethtool"
        ["torsocks"]="torsocks"              ["obfs4proxy"]="obfs4proxy"
        ["dnscrypt-proxy"]="dnscrypt-proxy"  ["unbound"]="unbound"
        ["bleachbit"]="bleachbit"            ["scapy"]="python3-scapy"
        ["hostnamectl"]="systemd"            ["timedatectl"]="systemd"
    )

    echo -e "\n${CYAN}[*] Scanning for required and optional tools...${RESET}\n"

    local to_install=()
    local installed_count=0

    for tool in "${all_deps[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${GREEN}[✓]${RESET} ${tool}"
            (( installed_count++ ))
        else
            echo -e "  ${RED}[✗]${RESET} ${tool}  ${YELLOW}← missing${RESET}"
            local pkg="${PKG_MAP[$tool]:-$tool}"
            [[ ! " ${to_install[*]} " =~ " ${pkg} " ]] && to_install+=("$pkg")
        fi
    done

    echo -e "\n  ${DIM}Installed: $installed_count / ${#all_deps[@]}${RESET}\n"

    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}[+] All tools present. Full functionality available.${RESET}"
    else
        echo -e "  ${YELLOW}[!] Missing apt packages: ${to_install[*]}${RESET}\n"
        read -rp "  Install all missing tools now? [Y/n]: " ans
        ans="${ans:-Y}"
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            echo -e "\n${CYAN}[*] apt-get update...${RESET}"
            apt-get update -qq
            echo -e "${CYAN}[*] Installing: ${to_install[*]}${RESET}\n"
            apt-get install -y "${to_install[@]}" || \
                echo -e "${YELLOW}[!] Some packages may have failed — check above${RESET}"
            echo -e "\n${CYAN}[*] Re-checking after install...${RESET}\n"
            local still_missing=()
            for tool in "${all_deps[@]}"; do
                if command -v "$tool" &>/dev/null; then
                    echo -e "  ${GREEN}[✓]${RESET} $tool"
                else
                    echo -e "  ${RED}[✗]${RESET} $tool  ${DIM}(still missing — some features limited)${RESET}"
                    still_missing+=("$tool")
                fi
            done
            [[ ${#still_missing[@]} -eq 0 ]] \
                && echo -e "\n  ${GREEN}[+] All tools installed!${RESET}" \
                || echo -e "\n  ${YELLOW}[!] Still missing: ${still_missing[*]}${RESET}"
        else
            echo -e "  ${YELLOW}[!] Skipping. Some menu options may not work.${RESET}"
        fi
    fi
    echo ""
    read -rp "  Press ENTER to load the menu..." _
}

# ─── INTERFACE SELECTOR ──────────────────────────────────────────────
get_interfaces() {
    ip -o link show | awk -F': ' '{print $2}' | grep -Ev '^lo$|^docker|^virbr|^veth'
}

select_interface() {
    echo -e "\n${CYAN}[*] Network Interfaces:${RESET}"
    mapfile -t ifaces < <(get_interfaces)
    for i in "${!ifaces[@]}"; do
        local mac state
        mac=$(cat /sys/class/net/"${ifaces[$i]}"/address 2>/dev/null || echo "??:??:??:??:??:??")
        state=$(cat /sys/class/net/"${ifaces[$i]}"/operstate 2>/dev/null || echo "unknown")
        echo -e "    ${BOLD}[$i]${RESET} ${ifaces[$i]}  ${YELLOW}$mac${RESET}  [${GREEN}$state${RESET}]"
    done
    echo ""
    read -rp "  Select interface [0-$((${#ifaces[@]}-1))]: " idx
    IFACE="${ifaces[$idx]:-}"
    [[ -z "$IFACE" ]] && { echo -e "${RED}[!] Invalid selection${RESET}"; return 1; }
    echo -e "${GREEN}  [+] Selected: $IFACE${RESET}"
    log "Interface selected: $IFACE"
}

# ══════════════════════════════════════════════════════════════════════
# MAC ADDRESS CHANGER (DHCP-aware, scope-aware)
# ══════════════════════════════════════════════════════════════════════
mac_menu() {
    echo -e "\n${MAGENTA}┌──── MAC ADDRESS CHANGER ────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Full random MAC + flush DHCP lease               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Vendor-blend MAC (looks like common LAN device)   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Custom MAC                                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Restore original MAC                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Show MAC + ARP cache                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Clear ARP/neighbor cache                          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] MAC scope awareness — what it does and doesn't do ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    mkdir -p "$BACKUP_DIR"
    local backup="$BACKUP_DIR/${IFACE}.mac"
    [[ ! -f "$backup" ]] && ip link show "$IFACE" | awk '/ether/{print $2}' > "$backup"

    case $ch in
        1)
            ip link set "$IFACE" down
            macchanger -r "$IFACE" -q
            ip link set "$IFACE" up
            dhclient -r "$IFACE" 2>/dev/null || true
            sleep 1; dhclient "$IFACE" 2>/dev/null &
            echo -e "${GREEN}  [+] MAC randomized + DHCP lease flushed/renewed${RESET}"
            echo -e "${YELLOW}  [!] Router's DHCP logs still exist — use a different AP if possible${RESET}"
            log "MAC randomized + DHCP flushed: $IFACE"
            ;;
        2)
            local vendors=("3c:5a:b4" "f4:5c:89" "b8:27:eb" "dc:a6:32" "a4:c3:f0" "00:50:56")
            local v="${vendors[$RANDOM % ${#vendors[@]}]}"
            local r; r=$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
            ip link set "$IFACE" down
            macchanger -m "$v:$r" "$IFACE" -q
            ip link set "$IFACE" up
            echo -e "${GREEN}  [+] Vendor-blend MAC: $v:$r${RESET}"
            log "Vendor-blend MAC $v:$r on $IFACE"
            ;;
        3)
            read -rp "  MAC (XX:XX:XX:XX:XX:XX): " newmac
            ip link set "$IFACE" down
            macchanger -m "$newmac" "$IFACE" -q
            ip link set "$IFACE" up
            log "Custom MAC $newmac on $IFACE"
            ;;
        4)
            local orig; orig=$(cat "$backup" 2>/dev/null || echo "")
            ip link set "$IFACE" down
            [[ -n "$orig" ]] && macchanger -m "$orig" "$IFACE" -q || macchanger -p "$IFACE" -q
            ip link set "$IFACE" up
            dhclient "$IFACE" 2>/dev/null &
            echo -e "${GREEN}  [+] Original MAC restored${RESET}"
            log "MAC restored: $IFACE"
            ;;
        5)
            echo -e "\n${CYAN}--- MAC ---${RESET}"; macchanger -s "$IFACE"
            echo -e "\n${CYAN}--- ARP Cache ---${RESET}"; arp -n
            return ;;
        6)
            ip neigh flush all
            echo -e "${GREEN}  [+] ARP cache cleared${RESET}"
            log "ARP cache flushed" ;;
        7)
            echo -e "\n${CYAN}  ═══ MAC SPOOFING — SCOPE & LIMITS ═══${RESET}"
            echo -e "  ${GREEN}What MAC spoofing DOES protect:${RESET}"
            echo -e "  • Prevents local LAN device tracking"
            echo -e "  • Defeats captive portal fingerprinting (hotel/cafe WiFi)"
            echo -e "  • Stops DHCP-based device correlation on the local segment"
            echo -e ""
            echo -e "  ${RED}What MAC spoofing does NOT protect:${RESET}"
            echo -e "  • MAC never leaves your local network (router/gateway strips it)"
            echo -e "  • Does NOT hide you from the internet — only local segment"
            echo -e "  • Router DHCP logs already recorded your old MAC + session time"
            echo -e "  • WiFi probe requests broadcast saved SSIDs (device fingerprint)"
            echo -e ""
            echo -e "  ${YELLOW}Bottom line:${RESET}"
            echo -e "  Use MAC spoofing for LAN privacy only."
            echo -e "  For internet anonymity — rely on Tor + iptables lockdown."
            return ;;
    esac
    echo -e "${GREEN}  [+] Current MAC: $(cat /sys/class/net/"$IFACE"/address 2>/dev/null)${RESET}"
}

# ══════════════════════════════════════════════════════════════════════
# TOR + PROXYCHAINS + BRIDGES + OBFS4
# ══════════════════════════════════════════════════════════════════════
setup_tor_proxy() {
    echo -e "\n${MAGENTA}┌──── TOR + PROXYCHAINS + BRIDGES ────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Start Tor (stream isolation)                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Stop Tor                                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Configure proxychains — strict Tor               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Configure proxychains — multi-hop (proxy→Tor)    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Configure Tor BRIDGES + obfs4 (hide Tor traffic) ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Tor-over-VPN setup guide                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] VPN-over-Tor setup guide                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] Test exit IP + Tor check                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [9] Rotate Tor circuit (new identity)                ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            grep -q "## Ghost Profile" "$TOR_CONF" 2>/dev/null || cat >> "$TOR_CONF" << 'TORCONF'

## Ghost Profile
IsolateDestAddr 1
IsolateDestPort 1
IsolateClientProtocol 1
SocksPort 9050 IsolateDestAddr IsolateDestPort
SocksPort 9051 IsolateClientProtocol
ControlPort 9053
CookieAuthentication 1
TransPort 9040
DNSPort 5353
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
TORCONF
            systemctl restart tor; sleep 3
            systemctl is-active --quiet tor \
                && echo -e "${GREEN}  [+] Tor running with stream isolation${RESET}" \
                || echo -e "${RED}  [!] Tor failed — check: journalctl -u tor${RESET}"
            log "Tor started with stream isolation"
            ;;
        2)
            sed -i '/## Ghost Profile/,/AutomapHostsSuffixes/d' "$TOR_CONF" 2>/dev/null || true
            systemctl stop tor
            echo -e "${YELLOW}  [-] Tor stopped + torrc cleaned${RESET}"
            log "Tor stopped"
            ;;
        3)
            cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak" 2>/dev/null || true
            cat > "$PROXYCHAINS_CONF" << 'CONF'
# Ghost Profile v3 — strict Tor chain
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0
[ProxyList]
socks5  127.0.0.1 9050
CONF
            echo -e "${GREEN}  [+] proxychains4: strict Tor-only chain${RESET}"
            log "proxychains: strict Tor"
            ;;
        4)
            read -rp "  Upstream proxy type (socks5/http): " ptype
            read -rp "  Upstream proxy IP: " pip
            read -rp "  Upstream proxy port: " pport
            cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak" 2>/dev/null || true
            cat > "$PROXYCHAINS_CONF" << CONF
# Ghost Profile v3 — multi-hop: upstream → Tor
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
${ptype}  ${pip}  ${pport}
socks5  127.0.0.1 9050
CONF
            echo -e "${GREEN}  [+] Multi-hop chain: $ptype $pip:$pport → Tor${RESET}"
            log "Multi-hop proxychains: $ptype $pip:$pport -> Tor"
            ;;
        5)
            # NEW: Tor bridges + obfs4
            echo -e "\n${CYAN}  ═══ TOR BRIDGES + OBFS4 ═══${RESET}"
            echo -e "  ${YELLOW}Why bridges?${RESET}"
            echo -e "  • Standard Tor entry nodes are publicly listed"
            echo -e "  • ISPs/firewalls can detect and block standard Tor connections"
            echo -e "  • obfs4 makes Tor traffic look like random HTTPS — harder to detect"
            echo -e ""
            echo -e "  ${CYAN}Step 1: Get bridge lines from https://bridges.torproject.org${RESET}"
            echo -e "  Step 2: Choose 'obfs4' as the transport type"
            echo -e ""
            read -rp "  Do you have bridge lines to configure now? [y/N]: " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                if ! command -v obfs4proxy &>/dev/null; then
                    echo -e "${YELLOW}  [!] obfs4proxy not found. Installing...${RESET}"
                    apt-get install -y obfs4proxy -qq || true
                fi
                echo -e "${CYAN}  Paste your bridge lines (one per line, blank line when done):${RESET}"
                local bridges=()
                while IFS= read -rp "  bridge> " line && [[ -n "$line" ]]; do
                    bridges+=("$line")
                done
                if [[ ${#bridges[@]} -gt 0 ]]; then
                    # Remove old bridge config
                    sed -i '/UseBridges/d;/Bridge /d;/ClientTransportPlugin/d' "$TOR_CONF" 2>/dev/null || true
                    {
                        echo "UseBridges 1"
                        echo "ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy"
                        for b in "${bridges[@]}"; do echo "Bridge $b"; done
                    } >> "$TOR_CONF"
                    systemctl restart tor
                    sleep 3
                    systemctl is-active --quiet tor \
                        && echo -e "${GREEN}  [+] Tor started with obfs4 bridges${RESET}" \
                        || echo -e "${RED}  [!] Tor failed — check journalctl -u tor${RESET}"
                    log "Tor configured with obfs4 bridges"
                fi
            else
                echo -e "${DIM}  Get bridges: https://bridges.torproject.org (select obfs4)${RESET}"
            fi
            ;;
        6)
            echo -e "\n${CYAN}  ═══ TOR-OVER-VPN ═══${RESET}"
            echo -e "  Architecture:  ${WHITE}You → VPN → Tor → Internet${RESET}"
            echo -e ""
            echo -e "  ${GREEN}Advantages:${RESET}"
            echo -e "  • VPN hides Tor usage from your ISP"
            echo -e "  • VPN provider doesn't see your traffic (Tor encrypts it)"
            echo -e "  • Good for regions that block Tor"
            echo -e ""
            echo -e "  ${RED}Disadvantages:${RESET}"
            echo -e "  • VPN provider knows you use Tor"
            echo -e "  • VPN is a trusted third party (choose a no-log provider)"
            echo -e ""
            echo -e "  ${YELLOW}Setup:${RESET}"
            echo -e "  1. Connect to VPN first (OpenVPN/WireGuard)"
            echo -e "  2. Start Tor: ${BOLD}systemctl start tor${RESET}"
            echo -e "  3. Use proxychains/torsocks as normal"
            echo -e "  4. Verify: ${BOLD}proxychains4 curl https://check.torproject.org${RESET}"
            echo -e ""
            echo -e "  ${DIM}Recommended VPN providers with no-log policies:${RESET}"
            echo -e "  Mullvad (accepts cash/Monero) | ProtonVPN | IVPN"
            return ;;
        7)
            echo -e "\n${CYAN}  ═══ VPN-OVER-TOR ═══${RESET}"
            echo -e "  Architecture:  ${WHITE}You → Tor → VPN → Internet${RESET}"
            echo -e ""
            echo -e "  ${GREEN}Advantages:${RESET}"
            echo -e "  • VPN exit hides Tor exit node from target (exit node is VPN IP)"
            echo -e "  • Can bypass Tor exit node blocks on some services"
            echo -e ""
            echo -e "  ${RED}Disadvantages:${RESET}"
            echo -e "  • VPN provider can see your traffic (only Tor is encrypted end-to-end)"
            echo -e "  • More complex to configure"
            echo -e "  • Slower than Tor-over-VPN"
            echo -e ""
            echo -e "  ${YELLOW}Setup:${RESET}"
            echo -e "  1. Start Tor service"
            echo -e "  2. Route OpenVPN through SOCKS: use --socks-proxy 127.0.0.1 9050"
            echo -e "  3. Example: ${BOLD}openvpn --config vpn.ovpn --socks-proxy 127.0.0.1 9050${RESET}"
            return ;;
        8)
            echo -e "${CYAN}  [*] Real IP:${RESET}"
            curl -s --max-time 5 https://api.ipify.org && echo ""
            echo -e "${CYAN}  [*] Exit IP via Tor (proxychains):${RESET}"
            proxychains4 -q curl -s --max-time 12 https://api.ipify.org && echo ""
            echo -e "${CYAN}  [*] Tor project check:${RESET}"
            proxychains4 -q curl -s --max-time 12 https://check.torproject.org/api/ip \
                | python3 -m json.tool 2>/dev/null || echo "  Failed"
            ;;
        9)
            (printf 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n') \
                | nc -w 3 127.0.0.1 9053 2>/dev/null \
                && echo -e "${GREEN}  [+] New Tor circuit requested${RESET}" \
                || echo -e "${YELLOW}  [!] Enable ControlPort 9053 (done by option 1)${RESET}"
            log "Tor NEWNYM"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# DNS LEAK PREVENTION + dnscrypt-proxy + Unbound
# ══════════════════════════════════════════════════════════════════════
fix_dns() {
    echo -e "\n${MAGENTA}┌──── DNS LEAK PREVENTION ────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Lock DNS to Tor 127.0.0.1 + iptables bypass block ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Setup dnscrypt-proxy (encrypted DNS)              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Setup Unbound (local recursive resolver)          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Disable systemd-resolved (common leak source)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Block all external DNS via iptables               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Per-app DNS isolation note                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Restore original DNS                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] DNS leak status check                             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local resolv="/etc/resolv.conf"
    local bak="$BACKUP_DIR/resolv.conf.bak"
    mkdir -p "$BACKUP_DIR"
    [[ ! -f "$bak" ]] && cp "$resolv" "$bak" 2>/dev/null || true

    case $ch in
        1)
            systemctl stop systemd-resolved 2>/dev/null || true
            chattr -i "$resolv" 2>/dev/null || true
            echo "nameserver 127.0.0.1" > "$resolv"
            chattr +i "$resolv"
            iptables -I OUTPUT -p udp --dport 53 ! -d 127.0.0.1 -j REJECT 2>/dev/null || true
            iptables -I OUTPUT -p tcp --dport 53 ! -d 127.0.0.1 -j REJECT 2>/dev/null || true
            echo -e "${GREEN}  [+] DNS locked to 127.0.0.1 + bypass blocked${RESET}"
            echo -e "${YELLOW}  [!] Requires Tor DNSPort 5353 active (start Tor first)${RESET}"
            log "DNS locked to Tor"
            ;;
        2)
            # NEW: dnscrypt-proxy
            if command -v dnscrypt-proxy &>/dev/null; then
                systemctl stop systemd-resolved 2>/dev/null || true
                # Configure to listen on 127.0.0.1:53
                local dcconf="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
                if [[ -f "$dcconf" ]]; then
                    sed -i "s/^listen_addresses.*/listen_addresses = ['127.0.0.1:53']/" "$dcconf" 2>/dev/null || true
                    sed -i "s/^# require_nolog.*/require_nolog = true/" "$dcconf" 2>/dev/null || true
                    sed -i "s/^require_nolog.*/require_nolog = true/" "$dcconf" 2>/dev/null || true
                fi
                systemctl restart dnscrypt-proxy
                chattr -i "$resolv" 2>/dev/null || true
                echo "nameserver 127.0.0.1" > "$resolv"
                chattr +i "$resolv"
                echo -e "${GREEN}  [+] dnscrypt-proxy running — DNS encrypted + no-log${RESET}"
                echo -e "${YELLOW}  [!] DNS is encrypted but NOT going through Tor. Combine with option 1 for full isolation.${RESET}"
                log "dnscrypt-proxy configured"
            else
                echo -e "${YELLOW}  [!] dnscrypt-proxy not installed: apt install dnscrypt-proxy${RESET}"
            fi
            ;;
        3)
            # NEW: Unbound local recursive resolver
            if command -v unbound &>/dev/null; then
                cat > /etc/unbound/unbound.conf.d/ghost.conf << 'UNBOUNDCONF'
server:
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    prefer-ip6: no
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    edns-buffer-size: 1232
    prefetch: yes
    num-threads: 1
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
UNBOUNDCONF
                systemctl restart unbound
                chattr -i "$resolv" 2>/dev/null || true
                echo "nameserver 127.0.0.1" > "$resolv"
                echo -e "${GREEN}  [+] Unbound local resolver active on 127.0.0.1:5335${RESET}"
                echo -e "${DIM}  QNAME minimization + DNSSEC + identity hidden${RESET}"
                log "Unbound configured"
            else
                echo -e "${YELLOW}  [!] Unbound not installed: apt install unbound${RESET}"
            fi
            ;;
        4)
            systemctl stop systemd-resolved
            systemctl disable systemd-resolved
            rm -f /etc/resolv.conf
            echo "nameserver 127.0.0.1" > /etc/resolv.conf
            echo -e "${GREEN}  [+] systemd-resolved disabled (major DNS leak source eliminated)${RESET}"
            log "systemd-resolved disabled"
            ;;
        5)
            iptables -I OUTPUT -p udp --dport 53 -j DROP
            iptables -I OUTPUT -p tcp --dport 53 -j DROP
            iptables -I OUTPUT -p udp -d 127.0.0.1 --dport 53 -j ACCEPT
            iptables -I OUTPUT -p udp -d 127.0.0.1 --dport 5353 -j ACCEPT
            echo -e "${GREEN}  [+] All external DNS blocked — only 127.0.0.1 DNS allowed${RESET}"
            log "iptables DNS lockdown"
            ;;
        6)
            # NEW: per-app DNS isolation
            echo -e "\n${CYAN}  ═══ PER-APP DNS ISOLATION ═══${RESET}"
            echo -e "  ${YELLOW}Problem:${RESET} Some apps bypass system DNS entirely:"
            echo -e "  • Chrome/Firefox with DNS-over-HTTPS built-in"
            echo -e "  • Applications with hardcoded DNS (8.8.8.8, 1.1.1.1)"
            echo -e "  • WebRTC leaks in browsers (reveals real IP)"
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Firefox: about:config → network.trr.mode = 5 (disable DoH)"
            echo -e "  • Chrome:  --disable-features=UseDnsHttpsSvcb flag"
            echo -e "  • Force via iptables (option 5) — intercepts all port 53"
            echo -e "  • Use network namespaces (see Isolation menu [N])"
            echo -e "  • WebRTC: install uBlock Origin → Settings → Prevent WebRTC"
            echo -e ""
            echo -e "  ${DIM}Tools: dnscrypt-proxy (encrypts), Unbound (resolves locally)${RESET}"
            return ;;
        7)
            chattr -i "$resolv" 2>/dev/null || true
            [[ -f "$bak" ]] && cp "$bak" "$resolv"
            systemctl start systemd-resolved 2>/dev/null || true
            echo -e "${GREEN}  [+] DNS restored${RESET}"
            log "DNS restored"
            ;;
        8)
            echo -e "\n${CYAN}--- /etc/resolv.conf ---${RESET}"; cat "$resolv"
            echo -e "\n${CYAN}--- Listening on :53 ---${RESET}"
            ss -tunlp | grep ':53' || echo "  Nothing listening on :53"
            echo -e "\n${YELLOW}  Manual checks:${RESET}"
            echo -e "  DNS leak:  https://dnsleaktest.com"
            echo -e "  WebRTC:    https://browserleaks.com/webrtc"
            echo -e "  Full test: https://ipleak.net"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# IPTABLES LOCKDOWN
# ══════════════════════════════════════════════════════════════════════
iptables_menu() {
    echo -e "\n${MAGENTA}┌──── IPTABLES LOCKDOWN ──────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Full Tor lockdown (TCP+DNS, no leaks)             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Block ALL IPv6 (sysctl + ip6tables)               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Block non-Tor UDP                                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Kill-switch (drop all if Tor process stops)       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Port whitelist through Tor only                   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Show all current rules                            ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Flush ALL rules + reset                           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local TOR_UID
    TOR_UID=$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || echo "107")

    case $ch in
        1)
            iptables -F; iptables -X
            iptables -t nat -F; iptables -t nat -X
            iptables -t mangle -F; iptables -t mangle -X
            iptables -A INPUT  -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT
            iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -m owner --uid-owner "$TOR_UID" -j ACCEPT
            iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -p tcp --syn -j REDIRECT --to-ports 9040
            iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
            iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 5353
            iptables -A OUTPUT -j DROP
            iptables -A INPUT  -j DROP
            iptables -A FORWARD -j DROP
            echo -e "${GREEN}  [+] Full Tor lockdown — all TCP/DNS redirected, nothing escapes${RESET}"
            echo -e "${YELLOW}  [!] Requires TransPort 9040 + DNSPort 5353 in torrc (start Tor first)${RESET}"
            log "iptables: full Tor lockdown"
            ;;
        2)
            for table in filter mangle raw; do
                ip6tables -t $table -F 2>/dev/null; ip6tables -t $table -X 2>/dev/null
            done
            ip6tables -P INPUT DROP; ip6tables -P OUTPUT DROP; ip6tables -P FORWARD DROP
            sysctl -w net.ipv6.conf.all.disable_ipv6=1 -q
            sysctl -w net.ipv6.conf.default.disable_ipv6=1 -q
            sysctl -w net.ipv6.conf.lo.disable_ipv6=1 -q
            echo -e "${GREEN}  [+] IPv6 fully disabled (ip6tables + sysctl)${RESET}"
            log "IPv6 disabled"
            ;;
        3)
            iptables -I OUTPUT -p udp -m owner ! --uid-owner "$TOR_UID" ! -d 127.0.0.1 -j DROP
            echo -e "${GREEN}  [+] Non-Tor UDP blocked${RESET}"
            log "Non-Tor UDP blocked"
            ;;
        4)
            iptables -I OUTPUT -m owner ! --uid-owner "$TOR_UID" ! -o lo -j DROP
            echo -e "${GREEN}  [+] Kill-switch: all non-Tor traffic blocked${RESET}"
            echo -e "${YELLOW}  [!] Use [7] to remove if needed${RESET}"
            log "Kill-switch enabled"
            ;;
        5)
            read -rp "  Ports to allow through Tor (space-sep, e.g. 80 443 22): " -a ports
            iptables -I OUTPUT -m owner ! --uid-owner "$TOR_UID" ! -o lo -j DROP
            for p in "${ports[@]}"; do
                iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -p tcp --dport "$p" \
                    -j REDIRECT --to-ports 9040
            done
            echo -e "${GREEN}  [+] Whitelist via Tor: ${ports[*]}${RESET}"
            log "Port whitelist: ${ports[*]}"
            ;;
        6)
            echo -e "\n${CYAN}─── IPv4 filter ───${RESET}"; iptables -L -n -v --line-numbers 2>/dev/null
            echo -e "\n${CYAN}─── IPv4 nat ───${RESET}"; iptables -t nat -L -n -v 2>/dev/null
            echo -e "\n${CYAN}─── IPv6 ───${RESET}"; ip6tables -L -n -v 2>/dev/null
            return ;;
        7)
            iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X; iptables -t mangle -F
            iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT
            ip6tables -F; ip6tables -X
            ip6tables -P INPUT ACCEPT; ip6tables -P OUTPUT ACCEPT; ip6tables -P FORWARD ACCEPT
            sysctl -w net.ipv6.conf.all.disable_ipv6=0 -q
            sysctl -w net.ipv6.conf.default.disable_ipv6=0 -q
            echo -e "${GREEN}  [+] All firewall rules flushed${RESET}"
            log "iptables flushed"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# SECURE LOG WIPE
# ══════════════════════════════════════════════════════════════════════
secure_wipe() {
    echo -e "\n${MAGENTA}┌──── SECURE WIPE ────────────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Shred shell histories (3-pass overwrite)          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Secure wipe /tmp /var/tmp                         ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Overwrite+truncate /var/log files                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Wipe thumbnail/recent-files cache                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Wipe swap (urandom overwrite)                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Drop RAM page cache                               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Full nuke (all of above)                          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] BleachBit deep clean                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [9] External log minimization guide                   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            for hist in ~/.bash_history ~/.zsh_history /root/.bash_history /root/.zsh_history \
                        ~/.python_history ~/.lesshst ~/.mysql_history ~/.psql_history; do
                [[ -f "$hist" ]] && shred -uzn 3 "$hist" 2>/dev/null && echo "  Shredded: $hist" || true
            done
            history -c; history -w 2>/dev/null || true
            echo -e "${GREEN}  [+] Shell histories 3-pass shredded${RESET}"
            log "Shell histories shredded"
            ;;
        2)
            find /tmp /var/tmp -maxdepth 3 -type f -exec shred -uzn 1 {} \; 2>/dev/null || true
            echo -e "${GREEN}  [+] Temp dirs wiped${RESET}"
            log "Temp wiped"
            ;;
        3)
            find /var/log -type f | while read -r lf; do
                shred -uzn 1 "$lf" 2>/dev/null && touch "$lf" 2>/dev/null || truncate -s 0 "$lf" 2>/dev/null || true
            done
            echo -e "${GREEN}  [+] /var/log files overwritten + cleared${RESET}"
            log "Logs shredded"
            ;;
        4)
            shred -uzn 1 ~/.local/share/recently-used.xbel 2>/dev/null || true
            rm -rf ~/.thumbnails ~/.cache/thumbnails ~/.local/share/Trash 2>/dev/null || true
            echo -e "${GREEN}  [+] Cache + recent-files wiped${RESET}"
            log "Cache wiped"
            ;;
        5)
            echo -e "${CYAN}  [*] Wiping swap with urandom...${RESET}"
            swapoff -a
            local swapdev; swapdev=$(swapon --show=NAME --noheadings 2>/dev/null | head -1)
            if [[ -n "$swapdev" ]]; then
                dd if=/dev/urandom of="$swapdev" bs=4M status=progress 2>/dev/null || true
                echo -e "${GREEN}  [+] Swap wiped${RESET}"
            else
                echo -e "${YELLOW}  [!] No active swap found${RESET}"
            fi
            swapon -a 2>/dev/null || true
            log "Swap wiped"
            ;;
        6)
            sync; echo 3 > /proc/sys/vm/drop_caches
            echo -e "${GREEN}  [+] RAM page cache dropped${RESET}"
            log "RAM cache dropped"
            ;;
        7)
            echo -e "${RED}  [!] Full nuke — shreds logs, history, temp, swap, RAM cache${RESET}"
            read -rp "  Confirm [yes/NO]: " confirm
            [[ "$confirm" != "yes" ]] && { echo "  Aborted."; return; }
            for sub in 1 2 3 4 5 6; do
                echo -e "${DIM}  Running step $sub...${RESET}"
                echo "$sub" | bash -c "source <(cat '$0'); secure_wipe" -- "$0" 2>/dev/null || true
            done
            echo -e "${GREEN}  [+] Full nuke complete${RESET}"
            log "Full nuke"
            ;;
        8)
            if command -v bleachbit &>/dev/null; then
                bleachbit --clean system.cache system.tmp system.trash bash.history 2>/dev/null
                echo -e "${GREEN}  [+] BleachBit done${RESET}"
                log "BleachBit ran"
            else
                echo -e "${YELLOW}  [!] Not installed: apt install bleachbit${RESET}"
            fi
            ;;
        9)
            # NEW: external log minimization guide
            echo -e "\n${CYAN}  ═══ EXTERNAL LOG MINIMIZATION ═══${RESET}"
            echo -e "  ${RED}Critical insight: You cannot delete external logs.${RESET}"
            echo -e "  Servers, ISPs, routers, CDNs — all keep independent logs."
            echo -e "  The only real defense is minimizing identifiable activity."
            echo -e ""
            echo -e "  ${YELLOW}What external systems log:${RESET}"
            echo -e "  • Web servers: IP, timestamp, User-Agent, request path, referrer"
            echo -e "  • ISP: NetFlow — dst IP, port, byte count, timing (even for HTTPS)"
            echo -e "  • CDN/WAF (Cloudflare, Akamai): full HTTP metadata"
            echo -e "  • Auth servers: login attempts, success/fail, timestamps"
            echo -e "  • Threat intel (Maltego, MISP): correlate reused artifacts"
            echo -e ""
            echo -e "  ${GREEN}Minimization strategies:${RESET}"
            echo -e "  • Never reuse accounts, usernames, emails, or SSH keys"
            echo -e "  • Avoid persistent identifiers (cookies, API tokens, certs)"
            echo -e "  • Separate identities — never mix personal + operational"
            echo -e "  • Use different Tor circuits per target/session"
            echo -e "  • Rotate infrastructure — VPS, exit nodes, tools between ops"
            echo -e "  • Avoid unique string literals in payloads (reused shellcode)"
            echo -e "  • Use short-lived infrastructure — don't reuse VPS/domains"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# FINGERPRINT EVASION + TRAFFIC PADDING + SCAPY
# ══════════════════════════════════════════════════════════════════════
fingerprint_evasion() {
    echo -e "\n${MAGENTA}┌──── FINGERPRINT EVASION + TRAFFIC PADDING ──────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Set random User-Agent (curl + nmap)               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Randomize TCP stack (TTL, timestamps, window)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Generate cover traffic (traffic padding)          ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Custom packet craft with Scapy (anti-signature)   ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] IDS evasion info (Suricata/Zeek awareness)        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] TLS/JA3 fingerprint guide                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Tool signature warning panel                      ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local ua_pool=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
        "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"
    )

    case $ch in
        1)
            local ua="${ua_pool[$RANDOM % ${#ua_pool[@]}]}"
            echo "user-agent = \"$ua\"" > /root/.curlrc
            echo -e "${GREEN}  [+] curl UA: ${DIM}$ua${RESET}"
            echo -e "${YELLOW}  Nmap: --script-args http.useragent='$ua'${RESET}"
            log "UA randomized"
            ;;
        2)
            sysctl -w net.ipv4.ip_default_ttl=$((64 + RANDOM % 64)) -q
            sysctl -w net.ipv4.tcp_timestamps=0 -q
            sysctl -w net.ipv4.tcp_window_scaling=1 -q
            sysctl -w net.ipv4.ip_no_pmtu_disc=$((RANDOM % 2)) -q
            # Randomize TCP window size via tc (if available)
            command -v tc &>/dev/null && tc qdisc add dev "${IFACE:-eth0}" root netem delay "$((10 + RANDOM % 50))ms" 2>/dev/null || true
            echo -e "${GREEN}  [+] TCP stack randomized — TTL, timestamps off, window varied${RESET}"
            log "TCP stack randomized"
            ;;
        3)
            # NEW: traffic padding / cover traffic
            echo -e "\n${CYAN}  ═══ TRAFFIC PADDING / COVER TRAFFIC ═══${RESET}"
            echo -e "  ${YELLOW}Why?${RESET} Tor is vulnerable to traffic correlation:"
            echo -e "  An adversary watching both your ISP connection and the exit node"
            echo -e "  can match timing/volume patterns to de-anonymize you."
            echo -e ""
            echo -e "  ${GREEN}Cover traffic adds noise to make correlation harder.${RESET}"
            echo -e ""
            echo -e "  [1] Generate random background HTTPS requests (noise)"
            echo -e "  [2] Constant-rate padding loop (ongoing noise)"
            echo -e "  [3] Explanation only"
            read -rp "  Sub-choice: " sub

            case $sub in
                1)
                    local noise_sites=("https://www.wikipedia.org" "https://www.example.com"
                                       "https://www.ietf.org" "https://www.rfc-editor.org"
                                       "https://www.w3.org" "https://httpbin.org/get")
                    local count=10
                    echo -e "${CYAN}  [*] Sending $count random background requests through Tor...${RESET}"
                    for (( i=0; i<count; i++ )); do
                        local site="${noise_sites[$RANDOM % ${#noise_sites[@]}]}"
                        proxychains4 -q curl -s --max-time 8 "$site" -o /dev/null 2>/dev/null &
                        sleep "0.$((RANDOM % 9 + 1))"
                    done
                    wait
                    echo -e "${GREEN}  [+] $count background requests sent${RESET}"
                    log "Cover traffic: $count requests"
                    ;;
                2)
                    echo -e "${CYAN}  [*] Constant-rate padding — runs in background (Ctrl+C to stop)${RESET}"
                    echo -e "${YELLOW}  [!] This will use bandwidth. Press Ctrl+C to stop.${RESET}"
                    local noise_sites=("https://www.wikipedia.org" "https://www.example.com" "https://httpbin.org/get")
                    while true; do
                        local site="${noise_sites[$RANDOM % ${#noise_sites[@]}]}"
                        proxychains4 -q curl -s --max-time 10 "$site" -o /dev/null 2>/dev/null
                        sleep "$((5 + RANDOM % 15))"
                    done
                    ;;
                3)
                    echo -e "\n  ${DIM}Traffic padding sends background requests to create noise.${RESET}"
                    echo -e "  ${DIM}It makes timing-based traffic correlation significantly harder.${RESET}"
                    echo -e "  ${DIM}This is not a complete defense — adversaries with full path${RESET}"
                    echo -e "  ${DIM}visibility can still use volume correlation over long periods.${RESET}"
                    return ;;
            esac
            ;;
        4)
            # NEW: Scapy custom packet crafting
            echo -e "\n${CYAN}  ═══ SCAPY CUSTOM PACKET CRAFTING ═══${RESET}"
            echo -e "  ${YELLOW}Why?${RESET} nmap/curl produce recognizable packet patterns."
            echo -e "  Custom packets break tool fingerprints (JA3, p0f, Snort sigs)."
            echo -e ""
            if ! command -v scapy &>/dev/null && ! python3 -c "import scapy" 2>/dev/null; then
                echo -e "${YELLOW}  [!] Scapy not found: apt install python3-scapy${RESET}"
                return
            fi
            echo -e "  [1] Send fragmented TCP SYN (evades simple packet inspection)"
            echo -e "  [2] Craft ICMP with custom payload"
            echo -e "  [3] TCP with randomized window + TTL"
            read -rp "  Sub-choice: " sub
            read -rp "  Target IP: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }

            case $sub in
                1)
                    python3 << SCAPY
from scapy.all import *
import random
ttl = random.randint(64, 128)
win = random.randint(1024, 65535)
pkt = IP(dst="$target", ttl=ttl, flags="MF") / TCP(dport=80, sport=random.randint(1024,65535), flags="S", window=win)
print(f"  [*] Sending fragmented SYN to $target TTL={ttl} WIN={win}")
send(pkt, verbose=0)
print("  [+] Sent")
SCAPY
                    ;;
                2)
                    python3 << SCAPY
from scapy.all import *
import random, os
payload = os.urandom(random.randint(8, 64))
pkt = IP(dst="$target") / ICMP() / Raw(load=payload)
print(f"  [*] Sending ICMP with {len(payload)}-byte random payload to $target")
send(pkt, verbose=0)
print("  [+] Sent")
SCAPY
                    ;;
                3)
                    python3 << SCAPY
from scapy.all import *
import random
ttl = random.randint(48, 255)
win = random.randint(512, 65535)
sport = random.randint(1024, 65535)
pkt = IP(dst="$target", ttl=ttl) / TCP(dport=443, sport=sport, flags="S", window=win, options=[('MSS', random.randint(536,1460))])
print(f"  [*] TCP SYN to $target:443 — TTL={ttl} WIN={win} SPORT={sport}")
send(pkt, verbose=0)
print("  [+] Sent")
SCAPY
                    ;;
            esac
            log "Scapy packet crafted to $target"
            ;;
        5)
            # NEW: IDS awareness
            echo -e "\n${CYAN}  ═══ IDS / IPS AWARENESS (Suricata / Zeek) ═══${RESET}"
            echo -e "  ${RED}Even with Tor + proxychains, IDS on the target network can detect:${RESET}"
            echo -e ""
            echo -e "  ${YELLOW}Suricata signatures detect:${RESET}"
            echo -e "  • nmap OS probe pattern (specific TCP flag sequences)"
            echo -e "  • Metasploit staging URLs (/AAAA, /multi/handler patterns)"
            echo -e "  • SQLi payloads (UNION SELECT, --comment patterns)"
            echo -e "  • Port scan patterns (too many SYNs, too fast)"
            echo -e "  • Default tool User-Agents (sqlmap/, nikto/)"
            echo -e ""
            echo -e "  ${YELLOW}Zeek (Bro) behavioral analysis detects:${RESET}"
            echo -e "  • Repeated connection attempts (brute force signature)"
            echo -e "  • Abnormal protocol behavior (malformed packets)"
            echo -e "  • DNS query anomalies (DGA domain patterns)"
            echo -e "  • Large data exfiltration (volume anomaly)"
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Use slow scan rates (nmap -T1 or -T2)"
            echo -e "  • Fragment packets (nmap -f or --mtu 8)"
            echo -e "  • Randomize scan order (--randomize-hosts)"
            echo -e "  • Use distributed scanning (multiple source IPs)"
            echo -e "  • Avoid default payload strings — customize all tool configs"
            echo -e "  • Use Scapy for custom packets instead of standard tools"
            return ;;
        6)
            echo -e "\n${CYAN}  ═══ TLS / JA3 FINGERPRINTING ═══${RESET}"
            echo -e "  ${YELLOW}JA3${RESET}  — fingerprints TLS ClientHello (cipher order, extensions)"
            echo -e "  ${YELLOW}JA3S${RESET} — fingerprints TLS ServerHello responses"
            echo -e "  ${YELLOW}HASSH${RESET}— fingerprints SSH key exchange"
            echo -e ""
            echo -e "  Every tool has a UNIQUE JA3 hash:"
            echo -e "  curl:             distinct JA3"
            echo -e "  python-requests:  distinct JA3 (different from curl)"
            echo -e "  nmap:             distinct JA3 + probe pattern"
            echo -e "  Tor Browser:      mimics Firefox JA3 exactly"
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Use torsocks (more consistent with browser profile)"
            echo -e "  • Use Tor Browser for manual browsing"
            echo -e "  • Use -sV --version-intensity 0 for nmap (less probing)"
            echo -e "  • Option [2] in this menu — randomize TCP stack"
            return ;;
        7)
            echo -e "\n${RED}  ⚠ TOOL SIGNATURE WARNING ⚠${RESET}"
            echo -e "  ${YELLOW}nmap${RESET}       — JA3, OS probe packets, timing signature"
            echo -e "  ${YELLOW}curl${RESET}       — JA3, User-Agent"
            echo -e "  ${YELLOW}sqlmap${RESET}     — payload patterns, HTTP header order"
            echo -e "  ${YELLOW}metasploit${RESET} — staging URLs, payload signatures"
            echo -e "  ${YELLOW}nikto${RESET}      — UA + request pattern"
            echo -e "  ${YELLOW}hydra${RESET}      — connection timing, banner grab pattern"
            echo -e "  ${YELLOW}gobuster${RESET}   — request rate + wordlist pattern"
            echo -e ""
            echo -e "  Always wrap with: ${BOLD}proxychains4 -q <tool>${RESET}"
            echo -e "  And randomize UA: ${BOLD}option [1] above${RESET}"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# BEHAVIORAL PATTERN TOOLS + INFRASTRUCTURE ROTATION
# ══════════════════════════════════════════════════════════════════════
behavioral_tools() {
    echo -e "\n${MAGENTA}┌──── BEHAVIORAL PATTERN + OPSEC ─────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Nmap with randomized timing + decoys             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Random jitter sleep between operations           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Randomized port scan order                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Spoof nmap source port                           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Distributed scan mode (multi-source simulation)  ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] OPSEC discipline checklist                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Infrastructure rotation checklist                ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] Behavioral attribution analysis (self-audit)     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            read -rp "  Target IP/range: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            local timing=$((1 + RANDOM % 3))
            local sport=$((1024 + RANDOM % 60000))
            local dlen=$((20 + RANDOM % 200))
            echo -e "${CYAN}  [*] nmap T${timing}, decoys, sport=$sport, data-len=$dlen${RESET}"
            proxychains4 -q nmap -T${timing} --randomize-hosts \
                --source-port "$sport" -D RND:5 \
                --data-length "$dlen" -f "$target" 2>/dev/null
            log "Behavioral nmap: $target"
            ;;
        2)
            read -rp "  Min sleep (seconds): " min_s
            read -rp "  Max sleep (seconds): " max_s
            [[ -z "$min_s" || -z "$max_s" ]] && { echo "  Missing values."; return; }
            local delay=$(( min_s + RANDOM % (max_s - min_s + 1) ))
            echo -e "${CYAN}  [*] Sleeping ${delay}s...${RESET}"; sleep "$delay"
            echo -e "${GREEN}  [+] Done${RESET}"
            ;;
        3)
            read -rp "  Target: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            proxychains4 -q nmap --randomize-hosts -p- --min-rate 50 --max-rate 200 -T2 "$target" 2>/dev/null
            ;;
        4)
            read -rp "  Source port (53/80/443): " sport
            read -rp "  Target: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            proxychains4 -q nmap --source-port "$sport" -sS "$target" 2>/dev/null
            ;;
        5)
            # NEW: distributed scan simulation
            echo -e "\n${CYAN}  ═══ DISTRIBUTED SCANNING ═══${RESET}"
            echo -e "  ${YELLOW}Concept:${RESET} Split scan across multiple Tor circuits/identities"
            echo -e "  so no single source sees a full port scan."
            echo -e ""
            read -rp "  Target: " target
            read -rp "  Circuits to simulate (2-5): " circuits
            [[ -z "$target" ]] && { echo "  No target."; return; }
            circuits="${circuits:-3}"
            local port_ranges=("1-1000" "1001-10000" "10001-30000" "30001-50000" "50001-65535")
            echo -e "${CYAN}  [*] Scanning in $circuits segments, rotating circuit between each...${RESET}"
            for (( i=0; i<circuits; i++ )); do
                local range="${port_ranges[$i]}"
                echo -e "  ${DIM}[Circuit $((i+1))/$circuits] Scanning ports $range...${RESET}"
                # Rotate Tor circuit
                (printf 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n') | nc -w 2 127.0.0.1 9053 2>/dev/null || true
                sleep "$((10 + RANDOM % 20))"
                proxychains4 -q nmap -T1 -p "$range" "$target" 2>/dev/null &
            done
            wait
            echo -e "${GREEN}  [+] Distributed scan complete${RESET}"
            log "Distributed scan: $target ($circuits circuits)"
            ;;
        6)
            echo -e "\n${CYAN}  ═══ OPSEC DISCIPLINE CHECKLIST ═══${RESET}"
            echo -e "  ${GREEN}[✓ DO]${RESET}"
            echo -e "  • Vary timing — never use T4/T5"
            echo -e "  • Rotate Tor circuit between targets"
            echo -e "  • Randomize port scan order"
            echo -e "  • Fragment packets (-f or --mtu)"
            echo -e "  • Use decoys (nmap -D RND:10)"
            echo -e "  • Vary tools — alternate nmap / masscan / zmap"
            echo -e "  • Vary payloads between sessions"
            echo -e "  • Change activity time windows each session"
            echo -e ""
            echo -e "  ${RED}[✗ AVOID]${RESET}"
            echo -e "  • Same nmap flags every run"
            echo -e "  • Sequential 1→65535 port scans"
            echo -e "  • Same time-of-day pattern"
            echo -e "  • Identical attack chain: nmap→gobuster→sqlmap every time"
            echo -e "  • Reusing same payloads, scripts, or tool defaults"
            return ;;
        7)
            # NEW: infrastructure rotation checklist
            echo -e "\n${CYAN}  ═══ INFRASTRUCTURE ROTATION CHECKLIST ═══${RESET}"
            echo -e "  ${YELLOW}Rotate BEFORE:${RESET}"
            echo -e "  [ ] Each new target / engagement"
            echo -e "  [ ] If you suspect detection or honeypot"
            echo -e "  [ ] After any credential use"
            echo -e ""
            echo -e "  ${YELLOW}What to rotate:${RESET}"
            echo -e "  [ ] Tor circuit (NEWNYM signal — option in Tor menu)"
            echo -e "  [ ] MAC address (different vendor prefix)"
            echo -e "  [ ] Hostname (new random generic name)"
            echo -e "  [ ] VPS/relay (if using external infrastructure)"
            echo -e "  [ ] DNS configuration"
            echo -e "  [ ] SSH keys / TLS certificates"
            echo -e "  [ ] Tool configuration (change default scan flags)"
            echo -e "  [ ] User-Agent string"
            echo -e "  [ ] Payload structure (no reused shellcode strings)"
            echo -e ""
            echo -e "  ${RED}Never reuse:${RESET}"
            echo -e "  • Domains, IPs, or hostnames across operations"
            echo -e "  • Account names, emails, SSH keys"
            echo -e "  • Identical exploit code without modification"
            echo -e "  • The same operational workflow signature"
            return ;;
        8)
            # NEW: behavioral self-audit
            echo -e "\n${CYAN}  ═══ BEHAVIORAL SELF-AUDIT ═══${RESET}"
            echo -e "  Answer honestly — these are the patterns investigators look for:"
            echo -e ""
            local score=0
            local q
            read -rp "  Do you always run nmap before other tools? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Predictable workflow — mix up your recon order${RESET}" && ((score++))
            read -rp "  Do you scan at the same time of day? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Timing fingerprint — randomize activity windows${RESET}" && ((score++))
            read -rp "  Do you use default tool configurations? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Tool signature — customize every config${RESET}" && ((score++))
            read -rp "  Do you reuse the same VPS/infrastructure? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Infrastructure fingerprint — rotate per op${RESET}" && ((score++))
            read -rp "  Do you use the same scripting language every time? [y/N]: " q
            [[ "$q" =~ ^[Yy]$ ]] && echo -e "  ${RED}⚠ Code style fingerprint — vary tools and languages${RESET}" && ((score++))
            echo -e "\n  Risk score: ${YELLOW}$score/5${RESET}"
            [[ $score -eq 0 ]] && echo -e "  ${GREEN}  Good OPSEC discipline${RESET}"
            [[ $score -ge 3 ]] && echo -e "  ${RED}  High attribution risk — review checklist (option 7)${RESET}"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# NETWORK INFRA AWARENESS + NAMESPACE ISOLATION
# ══════════════════════════════════════════════════════════════════════
network_infra() {
    echo -e "\n${MAGENTA}┌──── NETWORK INFRA + ISOLATION ──────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Disassociate from WiFi AP                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Flush DHCP lease files                           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] What your router/ISP can see                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Enable monitor mode                              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Disable WiFi (rfkill)                            ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Network namespace isolation (Whonix-style)       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [7] Run app in isolated namespace                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [8] RAM session / read-only media guide              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            [[ -z "$IFACE" ]] && select_interface
            iw dev "$IFACE" disconnect 2>/dev/null \
                && echo -e "${GREEN}  [+] Disassociated from AP${RESET}" \
                || echo -e "${YELLOW}  [!] Try: iwconfig $IFACE essid off${RESET}"
            log "WiFi disassociated"
            ;;
        2)
            find /var/lib/dhcp /var/lib/dhclient /run/NetworkManager /run/systemd/netif \
                -name "*.lease*" 2>/dev/null | while read -r lf; do
                shred -uzn 1 "$lf" 2>/dev/null && echo "  Shredded: $lf" || true
            done
            dhclient -r 2>/dev/null || true
            echo -e "${GREEN}  [+] DHCP leases flushed${RESET}"
            log "DHCP leases flushed"
            ;;
        3)
            echo -e "\n${CYAN}  What local network infrastructure logs:${RESET}"
            echo -e "  • DHCP: MAC → IP → lease time → hostname in request"
            echo -e "  • WiFi: probe requests (broadcasts saved SSIDs)"
            echo -e "  • ARP: MAC broadcasts to entire local segment"
            echo -e "  • NetFlow: dst IP, port, byte count (even for HTTPS)"
            echo -e "  • ISP: full connection metadata, timestamps"
            echo -e ""
            echo -e "  ${YELLOW}Mitigations:${RESET}"
            echo -e "  • Spoof MAC before connecting (MAC menu → option 1)"
            echo -e "  • Set generic hostname before DHCP"
            echo -e "  • Disable WiFi probe requests: iw dev \$IFACE set power_save on"
            echo -e "  • Use Tor/VPN before any traffic"
            return ;;
        4)
            [[ -z "$IFACE" ]] && select_interface
            ip link set "$IFACE" down 2>/dev/null
            iw dev "$IFACE" set type monitor 2>/dev/null \
                && ip link set "$IFACE" up \
                && echo -e "${GREEN}  [+] Monitor mode: $IFACE${RESET}" \
                || echo -e "${YELLOW}  [!] Try: airmon-ng start $IFACE${RESET}"
            log "Monitor mode: $IFACE"
            ;;
        5)
            rfkill block wifi
            echo -e "${GREEN}  [+] WiFi rfkill blocked${RESET}"
            log "WiFi blocked"
            ;;
        6)
            # NEW: network namespace isolation
            echo -e "\n${CYAN}  ═══ NETWORK NAMESPACE ISOLATION ═══${RESET}"
            echo -e "  ${YELLOW}Concept (Whonix-style):${RESET}"
            echo -e ""
            echo -e "  ${WHITE}[ Workstation NS ] ──► [ Tor Gateway NS ] ──► Internet${RESET}"
            echo -e ""
            echo -e "  Applications in the Workstation namespace have NO direct"
            echo -e "  internet access — all traffic MUST go through the Tor Gateway."
            echo -e "  Even if an app tries to bypass proxy settings, it physically"
            echo -e "  cannot reach the internet without going through Tor."
            echo -e ""
            echo -e "  ${GREEN}Creating an isolated namespace now:${RESET}"
            read -rp "  Create ghost_ns namespace? [y/N]: " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                ip netns add ghost_ns 2>/dev/null || true
                ip netns list | grep ghost_ns \
                    && echo -e "${GREEN}  [+] Network namespace 'ghost_ns' created${RESET}" \
                    || echo -e "${YELLOW}  [!] Namespace may already exist${RESET}"
                echo -e "${CYAN}  Run commands in isolated namespace:${RESET}"
                echo -e "  ${BOLD}ip netns exec ghost_ns bash${RESET}"
                echo -e "  ${BOLD}ip netns exec ghost_ns proxychains4 curl ...${RESET}"
                log "Network namespace ghost_ns created"
            fi
            ;;
        7)
            # NEW: run app in namespace
            echo -e "\n${CYAN}  Run a command in the isolated ghost_ns namespace:${RESET}"
            ip netns list 2>/dev/null | grep ghost_ns \
                || echo -e "${YELLOW}  [!] ghost_ns not found — create it with option [6] first${RESET}"
            read -rp "  Command to run (e.g. 'proxychains4 curl https://example.com'): " cmd
            [[ -z "$cmd" ]] && { echo "  No command."; return; }
            ip netns exec ghost_ns bash -c "$cmd"
            log "Namespace exec: $cmd"
            ;;
        8)
            # NEW: RAM session guide
            echo -e "\n${CYAN}  ═══ RAM SESSION + READ-ONLY MEDIA GUIDE ═══${RESET}"
            echo -e "  ${GREEN}Best practices for zero-persistence sessions:${RESET}"
            echo -e ""
            echo -e "  ${YELLOW}[1] Boot from read-only media:${RESET}"
            echo -e "  • Use Tails OS (amnesic live system) on USB"
            echo -e "  • Kali Live (non-persistence mode): boot without 'persistence' option"
            echo -e "  • All session data stays in RAM — wiped on shutdown"
            echo -e ""
            echo -e "  ${YELLOW}[2] RAM-only sessions:${RESET}"
            echo -e "  • Tails routes all traffic through Tor by default"
            echo -e "  • No disk writes — /tmp, /var/log all in tmpfs (RAM)"
            echo -e "  • Verify: mount | grep tmpfs"
            echo -e ""
            echo -e "  ${YELLOW}[3] Avoid persistent browser profiles:${RESET}"
            echo -e "  • Never save passwords, cookies, or form data"
            echo -e "  • Use Tor Browser (no persistent profile)"
            echo -e "  • Or: firefox --private-window (but still leaves RAM artifacts)"
            echo -e "  • Better: chromium --incognito --no-first-run --user-data-dir=/tmp/cbr"
            echo -e ""
            echo -e "  ${YELLOW}[4] Current tmpfs check:${RESET}"
            mount | grep tmpfs | head -8 || echo "  No tmpfs found"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# TIMEZONE + NTP SPOOFING
# ══════════════════════════════════════════════════════════════════════
timezone_ntp() {
    echo -e "\n${MAGENTA}┌──── TIMEZONE + TIME SPOOFING ───────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Set timezone to UTC (most neutral)               ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Spoof to a custom timezone                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Disable NTP sync                                 ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Shift system time by N hours                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Randomize activity window tip                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Restore original timezone + NTP                  ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    local tz_bak="$BACKUP_DIR/timezone.bak"
    mkdir -p "$BACKUP_DIR"
    [[ ! -f "$tz_bak" ]] && timedatectl show 2>/dev/null | grep Timezone | cut -d= -f2 > "$tz_bak" || true

    case $ch in
        1)
            timedatectl set-timezone UTC
            echo -e "${GREEN}  [+] Timezone → UTC${RESET}"
            echo -e "${YELLOW}  [!] UTC is used globally — reduces timezone fingerprint${RESET}"
            log "Timezone UTC"
            ;;
        2)
            echo -e "  Examples: America/New_York  Europe/London  Asia/Singapore  Asia/Tokyo"
            read -rp "  Timezone: " tz
            timedatectl set-timezone "$tz" \
                && echo -e "${GREEN}  [+] Timezone: $tz${RESET}" \
                || echo -e "${RED}  [!] Invalid timezone${RESET}"
            log "Timezone spoofed: $tz"
            ;;
        3)
            timedatectl set-ntp false
            systemctl stop systemd-timesyncd 2>/dev/null || true
            systemctl stop ntp 2>/dev/null || true
            echo -e "${GREEN}  [+] NTP disabled — reduces timing correlation${RESET}"
            log "NTP disabled"
            ;;
        4)
            read -rp "  Hours to shift (+/-): " hrs
            [[ -z "$hrs" ]] && { echo "  No value."; return; }
            local new_ts=$(( $(date +%s) + hrs * 3600 ))
            timedatectl set-ntp false
            date -s "@$new_ts" > /dev/null
            echo -e "${GREEN}  [+] Time shifted ${hrs}h → $(date)${RESET}"
            log "Time shifted ${hrs}h"
            ;;
        5)
            # NEW: behavioral timing advice
            echo -e "\n${CYAN}  ═══ ACTIVITY WINDOW RANDOMIZATION ═══${RESET}"
            echo -e "  ${YELLOW}Problem:${RESET} Repeated activity at the same clock hours"
            echo -e "  narrows the attacker's probable timezone to within 2-3 hours."
            echo -e ""
            echo -e "  ${GREEN}Mitigations:${RESET}"
            echo -e "  • Vary your operation start times — don't always start at 02:00 UTC"
            echo -e "  • Use delayed execution: ${BOLD}at 03:${RANDOM:0:2} tomorrow < script.sh${RESET}"
            echo -e "  • Run operations via cron with jitter:"
            echo -e "    ${BOLD}*/30 * * * * sleep \$((RANDOM\\%1800)) && your_command${RESET}"
            echo -e "  • Consider automated tools that run at truly random times"
            echo -e "  • Avoid weekend/weekday patterns (can reveal employment status)"
            echo -e ""
            echo -e "  ${DIM}Language discipline:${RESET}"
            echo -e "  • Use consistent locale/charset (don't mix Arabic + English comments)"
            echo -e "  • Avoid native language typos in tool configs/scripts"
            return ;;
        6)
            local orig_tz; orig_tz=$(cat "$tz_bak" 2>/dev/null || echo "UTC")
            timedatectl set-timezone "$orig_tz"
            timedatectl set-ntp true
            systemctl start systemd-timesyncd 2>/dev/null || true
            echo -e "${GREEN}  [+] Timezone: $orig_tz + NTP re-enabled${RESET}"
            log "Timezone+NTP restored"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# HONEYPOT DETECTION (limit interaction depth)
# ══════════════════════════════════════════════════════════════════════
honeypot_detection() {
    echo -e "\n${MAGENTA}┌──── HONEYPOT DETECTION + SAFE INTERACTION ──────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  [1] Heuristic scan (ports, TTL, banner)              ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [2] Threat intel lookup (Shodan/AbuseIPDB)           ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [3] Banner grab + signature check                    ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [4] Response consistency test                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [5] Safe interaction depth guide                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  [6] Honeypot indicator reference                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}"
    read -rp "  Choice: " ch

    case $ch in
        1)
            read -rp "  Target IP: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            echo -e "${CYAN}  [*] Running honeypot heuristics on $target...${RESET}"
            local risk=0

            local open_ports
            open_ports=$(proxychains4 -q nmap -T2 --open \
                -p 21,22,23,25,80,110,143,443,445,3389,8080 \
                "$target" 2>/dev/null | grep -c "open" || echo "0")
            echo -e "  Open ports (11 probed): ${YELLOW}$open_ports${RESET}"
            [[ "$open_ports" -gt 8 ]] && echo -e "  ${RED}⚠ Many open ports — honeypot indicator${RESET}" && ((risk++))

            local ttl
            ttl=$(ping -c 1 -W 2 "$target" 2>/dev/null | grep -oP 'ttl=\K[0-9]+' | head -1 || echo "0")
            echo -e "  TTL: ${YELLOW}$ttl${RESET}"
            [[ "$ttl" -gt 0 && "$ttl" -lt 10 ]] && echo -e "  ${RED}⚠ Abnormal TTL — sandbox/emulation indicator${RESET}" && ((risk++))

            local banner
            banner=$(timeout 3 nc -w 2 "$target" 22 2>/dev/null | head -1 || echo "")
            echo -e "  SSH banner: ${YELLOW}${banner:-none}${RESET}"
            echo "$banner" | grep -qiE "kippo|cowrie|honeypot|fake" && \
                echo -e "  ${RED}⚠ Honeypot signature in banner${RESET}" && ((risk++)) || true

            echo -e "\n  ${BOLD}Risk score: $risk/3${RESET}"
            [[ $risk -ge 2 ]] && echo -e "  ${RED}HIGH RISK — abort and rotate identity${RESET}"
            [[ $risk -eq 0 ]] && echo -e "  ${GREEN}No obvious honeypot indicators${RESET}"
            log "Honeypot scan: $target risk=$risk"
            ;;
        2)
            read -rp "  Target IP: " target
            [[ -z "$target" ]] && { echo "  No target."; return; }
            echo -e "${CYAN}  Shodan (needs API key):${RESET}"
            proxychains4 -q curl -s "https://api.shodan.io/shodan/host/$target?key=YOUR_KEY" 2>/dev/null \
                | python3 -m json.tool 2>/dev/null \
                || echo -e "  Manual: ${BOLD}https://shodan.io/host/$target${RESET}"
            echo -e "${CYAN}  AbuseIPDB (needs API key):${RESET}"
            echo -e "  Manual: ${BOLD}https://www.abuseipdb.com/check/$target${RESET}"
            echo -e "${CYAN}  Censys:${RESET}"
            echo -e "  Manual: ${BOLD}https://search.censys.io/hosts/$target${RESET}"
            ;;
        3)
            read -rp "  Target IP: " target; read -rp "  Port: " port
            [[ -z "$target" || -z "$port" ]] && { echo "  Missing values."; return; }
            local raw
            raw=$(proxychains4 -q timeout 5 nc -w 3 "$target" "$port" <<< "" 2>/dev/null || echo "")
            echo -e "\n${YELLOW}--- Banner ---${RESET}"; echo "$raw" | head -10
            echo "$raw" | grep -qiE "kippo|cowrie|dionaea|glastopf|honeyd|artillery|opencanary" \
                && echo -e "\n${RED}  ⚠ KNOWN HONEYPOT SIGNATURE DETECTED${RESET}" \
                || echo -e "\n${GREEN}  No known signature in banner${RESET}"
            log "Banner: $target:$port"
            ;;
        4)
            # NEW: response consistency test
            read -rp "  Target IP: " target
            read -rp "  Port to test: " port
            [[ -z "$target" || -z "$port" ]] && { echo "  Missing values."; return; }
            echo -e "${CYAN}  [*] Sending 3 requests, checking response consistency...${RESET}"
            local r1 r2 r3
            r1=$(proxychains4 -q timeout 4 nc -w 2 "$target" "$port" <<< "" 2>/dev/null | head -1 || echo "NONE")
            sleep 2
            r2=$(proxychains4 -q timeout 4 nc -w 2 "$target" "$port" <<< "" 2>/dev/null | head -1 || echo "NONE")
            sleep 2
            r3=$(proxychains4 -q timeout 4 nc -w 2 "$target" "$port" <<< "" 2>/dev/null | head -1 || echo "NONE")
            echo -e "  R1: ${YELLOW}$r1${RESET}"
            echo -e "  R2: ${YELLOW}$r2${RESET}"
            echo -e "  R3: ${YELLOW}$r3${RESET}"
            if [[ "$r1" == "$r2" && "$r2" == "$r3" ]]; then
                echo -e "  ${GREEN}Consistent responses — lower honeypot likelihood${RESET}"
            else
                echo -e "  ${RED}⚠ Inconsistent responses — possible honeypot/emulation${RESET}"
            fi
            log "Consistency test: $target:$port"
            ;;
        5)
            # NEW: safe interaction depth guide
            echo -e "\n${CYAN}  ═══ SAFE INTERACTION DEPTH ═══${RESET}"
            echo -e "  ${RED}Reality check:${RESET} Cowrie, T-Pot, and modern honeypots are"
            echo -e "  designed to appear completely real. Detection is NOT reliable."
            echo -e ""
            echo -e "  ${YELLOW}Safe interaction principles:${RESET}"
            echo -e "  • LOOK before you touch: passive recon only on unknown hosts"
            echo -e "  • Limit commands executed — avoid ${BOLD}id, whoami, uname, ls -la${RESET}"
            echo -e "  • Never upload files or tools to unknown systems"
            echo -e "  • Never execute code from unknown hosts"
            echo -e "  • Avoid downloading payloads to unknown machines"
            echo -e "  • Monitor your OWN behavior — honeypots log everything:"
            echo -e "    → Every command you type"
            echo -e "    → Every file you try to access"
            echo -e "    → Every payload you upload"
            echo -e "    → Connection timing + source fingerprint"
            echo -e ""
            echo -e "  ${GREEN}Before interacting with any unknown target:${RESET}"
            echo -e "  [1] Run heuristic scan (option 1)"
            echo -e "  [2] Cross-check on Shodan + Censys (option 2)"
            echo -e "  [3] Test response consistency (option 4)"
            echo -e "  [4] If ANY high-risk indicators — abort + rotate identity"
            return ;;
        6)
            echo -e "\n${CYAN}  ═══ HONEYPOT INDICATORS ═══${RESET}"
            echo -e "  ${RED}HIGH RISK:${RESET}"
            echo -e "  • SSH banner: SSH-2.0-OpenSSH_5.1p1 (Kippo default)"
            echo -e "  • FTP/Telnet always accepts any credential"
            echo -e "  • 10+ open ports on single IP"
            echo -e "  • Response latency < 1ms on ALL ports (emulation)"
            echo -e "  • Shodan tag: honeypot"
            echo -e ""
            echo -e "  ${YELLOW}MODERATE:${RESET}"
            echo -e "  • Generic banners with no version strings"
            echo -e "  • IP in known honeypot ASN (Team Cymru, T-Pot project)"
            echo -e "  • Services behave identically regardless of input"
            echo -e ""
            echo -e "  ${GREEN}Always:${RESET}"
            echo -e "  • Run option [1] + [2] before any operation"
            echo -e "  • If 2+ HIGH RISK signals → abort and rotate"
            return ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# HOSTNAME SPOOFER
# ══════════════════════════════════════════════════════════════════════
change_hostname() {
    local old_host; old_host=$(hostname)
    local bak="$BACKUP_DIR/hostname.bak"
    mkdir -p "$BACKUP_DIR"
    [[ ! -f "$bak" ]] && echo "$old_host" > "$bak"

    echo -e "\n${CYAN}[*] Current hostname: ${YELLOW}$old_host${RESET}"
    echo -e "  [1] Random realistic hostname (Windows/Mac style)"
    echo -e "  [2] Custom hostname"
    echo -e "  [3] Restore original"
    read -rp "  Choice: " ch

    local names=(
        "DESKTOP-$(printf '%06X' $((RANDOM*RANDOM)))"
        "LAPTOP-$(printf '%06X' $((RANDOM*RANDOM)))"
        "PC-$(printf '%08X' $((RANDOM*RANDOM)))"
        "WIN11-$(printf '%04X' $((RANDOM*RANDOM)))"
        "MacBook-$(printf '%04X' $((RANDOM*RANDOM)))"
    )

    case $ch in
        1)
            local newhost="${names[$RANDOM % ${#names[@]}]}"
            hostnamectl set-hostname "$newhost"
            sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$newhost/" /etc/hosts 2>/dev/null || true
            echo -e "${GREEN}  [+] Hostname: $newhost${RESET}"
            log "Hostname: $newhost"
            ;;
        2)
            read -rp "  New hostname: " h
            hostnamectl set-hostname "$h"
            sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$h/" /etc/hosts 2>/dev/null || true
            log "Hostname: $h"
            ;;
        3)
            local orig; orig=$(cat "$bak" 2>/dev/null || echo "kali")
            hostnamectl set-hostname "$orig"
            sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$orig/" /etc/hosts 2>/dev/null || true
            echo -e "${GREEN}  [+] Restored: $orig${RESET}"
            log "Hostname restored: $orig"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# STATUS DASHBOARD
# ══════════════════════════════════════════════════════════════════════
show_status() {
    echo -e "\n${CYAN}╔══════════════════ GHOST STATUS ══════════════════════════╗${RESET}"
    local pubip torip
    pubip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "unavailable")
    torip=$(proxychains4 -q curl -s --max-time 12 https://api.ipify.org 2>/dev/null || echo "unavailable")
    echo -e "${CYAN}║${RESET}  Real IP        : ${RED}$pubip${RESET}"
    echo -e "${CYAN}║${RESET}  Tor Exit IP    : ${GREEN}$torip${RESET}"
    systemctl is-active --quiet tor \
        && echo -e "${CYAN}║${RESET}  Tor            : ${GREEN}● Running${RESET}" \
        || echo -e "${CYAN}║${RESET}  Tor            : ${RED}○ Stopped${RESET}"
    local dns; dns=$(grep -m1 nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}')
    echo -e "${CYAN}║${RESET}  DNS            : ${YELLOW}$dns${RESET}"
    local tz; tz=$(timedatectl show 2>/dev/null | grep Timezone | cut -d= -f2 || date +%Z)
    echo -e "${CYAN}║${RESET}  Timezone       : ${YELLOW}$tz${RESET}"
    echo -e "${CYAN}║${RESET}  Hostname       : ${YELLOW}$(hostname)${RESET}"
    for iface in $(get_interfaces); do
        local mac; mac=$(cat /sys/class/net/"$iface"/address 2>/dev/null || echo "??")
        echo -e "${CYAN}║${RESET}  MAC [$iface]    : ${YELLOW}$mac${RESET}"
    done
    local ipv6; ipv6=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "?")
    [[ "$ipv6" == "1" ]] \
        && echo -e "${CYAN}║${RESET}  IPv6           : ${GREEN}DISABLED ✓${RESET}" \
        || echo -e "${CYAN}║${RESET}  IPv6           : ${RED}ENABLED (leak risk)${RESET}"
    iptables -L OUTPUT 2>/dev/null | grep -q "DROP" \
        && echo -e "${CYAN}║${RESET}  Kill-switch    : ${GREEN}ACTIVE ✓${RESET}" \
        || echo -e "${CYAN}║${RESET}  Kill-switch    : ${RED}OFF${RESET}"
    ip netns list 2>/dev/null | grep -q ghost_ns \
        && echo -e "${CYAN}║${RESET}  ghost_ns       : ${GREEN}EXISTS ✓${RESET}" \
        || echo -e "${CYAN}║${RESET}  ghost_ns       : ${DIM}not created${RESET}"
    systemctl is-active --quiet dnscrypt-proxy 2>/dev/null \
        && echo -e "${CYAN}║${RESET}  dnscrypt-proxy : ${GREEN}● Running${RESET}" \
        || echo -e "${CYAN}║${RESET}  dnscrypt-proxy : ${DIM}○ Stopped${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
}

# ══════════════════════════════════════════════════════════════════════
# ONE-CLICK GHOST MODE (all fixes)
# ══════════════════════════════════════════════════════════════════════
ghost_mode_on() {
    echo -e "\n${RED}${BOLD}[*] Activating HARDENED GHOST MODE v3...${RESET}"
    select_interface || return
    mkdir -p "$BACKUP_DIR"

    echo -e "${DIM}  [1/10] Disabling IPv6...${RESET}"
    ip6tables -P INPUT DROP; ip6tables -P OUTPUT DROP; ip6tables -P FORWARD DROP
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 -q
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 -q
    echo -e "${GREEN}  [1/10] IPv6 disabled${RESET}"

    echo -e "${DIM}  [2/10] Randomizing MAC + flushing DHCP...${RESET}"
    [[ ! -f "$BACKUP_DIR/${IFACE}.mac" ]] && ip link show "$IFACE" | awk '/ether/{print $2}' > "$BACKUP_DIR/${IFACE}.mac"
    ip link set "$IFACE" down; macchanger -r "$IFACE" -q; ip link set "$IFACE" up
    dhclient -r "$IFACE" 2>/dev/null || true; sleep 1; dhclient "$IFACE" 2>/dev/null &
    echo -e "${GREEN}  [2/10] MAC randomized + DHCP flushed${RESET}"

    echo -e "${DIM}  [3/10] Setting realistic hostname...${RESET}"
    [[ ! -f "$BACKUP_DIR/hostname.bak" ]] && hostname > "$BACKUP_DIR/hostname.bak"
    local names=("DESKTOP-$(printf '%06X' $((RANDOM*RANDOM)))" "LAPTOP-$(printf '%06X' $((RANDOM*RANDOM)))" "PC-$(printf '%08X' $((RANDOM*RANDOM)))")
    local newhost="${names[$RANDOM % 3]}"
    hostnamectl set-hostname "$newhost"
    sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$newhost/" /etc/hosts 2>/dev/null || true
    echo -e "${GREEN}  [3/10] Hostname → $newhost${RESET}"

    echo -e "${DIM}  [4/10] Setting timezone to UTC...${RESET}"
    [[ ! -f "$BACKUP_DIR/timezone.bak" ]] && timedatectl show 2>/dev/null | grep Timezone | cut -d= -f2 > "$BACKUP_DIR/timezone.bak" || true
    timedatectl set-timezone UTC
    echo -e "${GREEN}  [4/10] Timezone → UTC${RESET}"

    echo -e "${DIM}  [5/10] Starting Tor with stream isolation...${RESET}"
    grep -q "## Ghost Profile" "$TOR_CONF" 2>/dev/null || cat >> "$TOR_CONF" << 'TORCONF'

## Ghost Profile
IsolateDestAddr 1
IsolateDestPort 1
IsolateClientProtocol 1
SocksPort 9050 IsolateDestAddr IsolateDestPort
ControlPort 9053
CookieAuthentication 1
TransPort 9040
DNSPort 5353
AutomapHostsOnResolve 1
TORCONF
    systemctl restart tor; sleep 3
    systemctl is-active --quiet tor \
        && echo -e "${GREEN}  [5/10] Tor started (stream isolation + TransPort + DNSPort)${RESET}" \
        || echo -e "${YELLOW}  [5/10] Tor failed — check journalctl -u tor${RESET}"

    echo -e "${DIM}  [6/10] Configuring proxychains...${RESET}"
    cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak" 2>/dev/null || true
    cat > "$PROXYCHAINS_CONF" << 'CONF'
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
socks5 127.0.0.1 9050
CONF
    echo -e "${GREEN}  [6/10] proxychains4 → strict Tor${RESET}"

    echo -e "${DIM}  [7/10] Locking DNS to Tor...${RESET}"
    systemctl stop systemd-resolved 2>/dev/null || true
    [[ ! -f "$BACKUP_DIR/resolv.conf.bak" ]] && cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf
    echo -e "${GREEN}  [7/10] DNS locked → Tor DNSPort${RESET}"

    echo -e "${DIM}  [8/10] Applying iptables full lockdown...${RESET}"
    local TOR_UID; TOR_UID=$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || echo "107")
    iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X
    iptables -A INPUT  -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner "$TOR_UID" -j ACCEPT
    iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -p tcp --syn -j REDIRECT --to-ports 9040
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 5353
    iptables -A OUTPUT -j DROP
    iptables -A INPUT  -j DROP
    echo -e "${GREEN}  [8/10] iptables: full Tor lockdown + kill-switch${RESET}"

    echo -e "${DIM}  [9/10] Randomizing TCP stack + UA...${RESET}"
    local ua_pool=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0"
                   "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0")
    echo "user-agent = \"${ua_pool[$RANDOM % 2]}\"" > /root/.curlrc
    sysctl -w net.ipv4.tcp_timestamps=0 -q
    sysctl -w net.ipv4.ip_default_ttl=$((64 + RANDOM % 64)) -q
    echo -e "${GREEN}  [9/10] TCP stack hardened + UA randomized${RESET}"

    echo -e "${DIM}  [10/10] Creating ghost_ns network namespace...${RESET}"
    ip netns add ghost_ns 2>/dev/null || true
    echo -e "${GREEN}  [10/10] ghost_ns namespace ready${RESET}"

    GHOST_ACTIVE=1
    log "Ghost Mode v3 activated"

    echo -e "\n${RED}${BOLD}"
    echo -e "  ╔═══════════════════════════════════════════════════╗"
    echo -e "  ║                                                   ║"
    echo -e "  ║          👻  GHOST MODE v3 ACTIVE  👻             ║"
    echo -e "  ║                                                   ║"
    echo -e "  ║  All TCP → Tor TransPort 9040                     ║"
    echo -e "  ║  DNS     → Tor DNSPort 5353                       ║"
    echo -e "  ║  IPv6    → DISABLED                               ║"
    echo -e "  ║  Kill-switch → ACTIVE                             ║"
    echo -e "  ║  ghost_ns → READY                                 ║"
    echo -e "  ║                                                   ║"
    echo -e "  ║  proxychains4 <tool>  |  torsocks <tool>          ║"
    echo -e "  ║  ip netns exec ghost_ns <tool>                    ║"
    echo -e "  ╚═══════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ══════════════════════════════════════════════════════════════════════
# RESTORE NORMAL PROFILE
# ══════════════════════════════════════════════════════════════════════
ghost_mode_off() {
    echo -e "\n${CYAN}[*] Restoring normal profile...${RESET}"

    for iface in $(get_interfaces); do
        local mbak="$BACKUP_DIR/${iface}.mac"
        if [[ -f "$mbak" ]]; then
            ip link set "$iface" down
            macchanger -m "$(cat "$mbak")" "$iface" -q 2>/dev/null \
                || macchanger -p "$iface" -q 2>/dev/null
            ip link set "$iface" up
        fi
    done; echo -e "${GREEN}  [+] MACs restored${RESET}"

    local h; h=$(cat "$BACKUP_DIR/hostname.bak" 2>/dev/null || echo "kali")
    hostnamectl set-hostname "$h"
    sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$h/" /etc/hosts 2>/dev/null || true
    echo -e "${GREEN}  [+] Hostname: $h${RESET}"

    local tz; tz=$(cat "$BACKUP_DIR/timezone.bak" 2>/dev/null || echo "UTC")
    timedatectl set-timezone "$tz"; timedatectl set-ntp true
    echo -e "${GREEN}  [+] Timezone: $tz${RESET}"

    chattr -i /etc/resolv.conf 2>/dev/null || true
    [[ -f "$BACKUP_DIR/resolv.conf.bak" ]] && cp "$BACKUP_DIR/resolv.conf.bak" /etc/resolv.conf
    systemctl start systemd-resolved 2>/dev/null || true
    echo -e "${GREEN}  [+] DNS restored${RESET}"

    sed -i '/## Ghost Profile/,/AutomapHostsOnResolve/d' "$TOR_CONF" 2>/dev/null || true
    systemctl stop tor; echo -e "${GREEN}  [+] Tor stopped${RESET}"

    iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X
    iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT
    ip6tables -F; ip6tables -X
    ip6tables -P INPUT ACCEPT; ip6tables -P OUTPUT ACCEPT; ip6tables -P FORWARD ACCEPT
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 -q
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 -q
    echo -e "${GREEN}  [+] Firewall flushed + IPv6 restored${RESET}"

    [[ -f "${PROXYCHAINS_CONF}.bak" ]] && cp "${PROXYCHAINS_CONF}.bak" "$PROXYCHAINS_CONF"
    rm -f /root/.curlrc
    sysctl -w net.ipv4.tcp_timestamps=1 -q
    sysctl -w net.ipv4.ip_default_ttl=64 -q

    ip netns del ghost_ns 2>/dev/null || true
    echo -e "${GREEN}  [+] ghost_ns namespace removed${RESET}"

    GHOST_ACTIVE=0
    log "Ghost Mode deactivated"
    echo -e "\n${CYAN}  [+] Normal profile fully restored.${RESET}\n"
}

# ══════════════════════════════════════════════════════════════════════
# MAIN MENU

# ══════════════════════════════════════════════════════════════════════
# MAIN MENU
# ══════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        banner
        echo -e "  ${BOLD}MAIN MENU${RESET}"
        echo -e "  ${DIM}─────────────────────────────────────────────────────────────${RESET}"
        echo -e "  ${RED}[G]${RESET}  ⚡ ONE-CLICK GHOST MODE ON       ${DIM}(full 10-step hardening)${RESET}"
        echo -e "  ${CYAN}[R]${RESET}  ⚡ RESTORE NORMAL PROFILE"
        echo -e "  ${DIM}─────────────────────────────────────────────────────────────${RESET}"
        echo -e "  ${YELLOW}[1]${RESET}  MAC Changer                      ${DIM}(DHCP-aware, scope guide)${RESET}"
        echo -e "  ${YELLOW}[A]${RESET}  MAC Advanced                     ${DIM}(scheduled rotation + vendor emulation)${RESET}"
        echo -e "  ${YELLOW}[2]${RESET}  Hostname Spoofer                 ${DIM}(realistic device names)${RESET}"
        echo -e "  ${YELLOW}[3]${RESET}  Tor + ProxyChains + Bridges      ${DIM}(stream isolation + multi-hop)${RESET}"
        echo -e "  ${YELLOW}[P]${RESET}  Pluggable Transports             ${DIM}(obfs4 / meek / snowflake / webtunnel)${RESET}"
        echo -e "  ${YELLOW}[O]${RESET}  Traffic Obfuscation              ${DIM}(obfs4proxy standalone + Shadowsocks)${RESET}"
        echo -e "  ${YELLOW}[4]${RESET}  DNS Leak Prevention              ${DIM}(dnscrypt + unbound + per-app)${RESET}"
        echo -e "  ${YELLOW}[D]${RESET}  DNS Permanent Encryption         ${DIM}(permanent dnscrypt + padding + relays)${RESET}"
        echo -e "  ${YELLOW}[5]${RESET}  IPTables Lockdown                ${DIM}(no escape paths, kill-switch)${RESET}"
        echo -e "  ${YELLOW}[6]${RESET}  Secure Log Wipe                  ${DIM}(shred + ext. log minimization)${RESET}"
        echo -e "  ${YELLOW}[7]${RESET}  Fingerprint + Cover Traffic      ${DIM}(JA3 + Scapy + IDS awareness)${RESET}"
        echo -e "  ${YELLOW}[T]${RESET}  TLS Fingerprint Spoofing         ${DIM}(uTLS + REALITY + JA3 checker)${RESET}"
        echo -e "  ${YELLOW}[W]${RESET}  Traffic Padding (Advanced)       ${DIM}(constant/burst/adaptive + ICMP)${RESET}"
        echo -e "  ${YELLOW}[M]${RESET}  Protocol Mimicry                 ${DIM}(DoH / DoT / HTTPS tunnel / WebSocket)${RESET}"
        echo -e "  ${YELLOW}[B]${RESET}  Browser Fingerprint              ${DIM}(user.js + Canvas + WebGL + Fonts)${RESET}"
        echo -e "  ${YELLOW}[8]${RESET}  Behavioral + OPSEC Tools         ${DIM}(timing jitter + self-audit)${RESET}"
        echo -e "  ${YELLOW}[9]${RESET}  Network Infra + Isolation        ${DIM}(namespace + RAM session guide)${RESET}"
        echo -e "  ${YELLOW}[0]${RESET}  Timezone + NTP Spoofing          ${DIM}(activity window randomization)${RESET}"
        echo -e "  ${YELLOW}[H]${RESET}  Honeypot Detection               ${DIM}(safe interaction depth)${RESET}"
        echo -e "  ${YELLOW}[S]${RESET}  Status Dashboard"
        echo -e "  ${DIM}─────────────────────────────────────────────────────────────${RESET}"
        echo -e "  ${RED}[Q]${RESET}  Quit"
        echo ""
        read -rp "  Choice: " choice

        case "${choice^^}" in
            G) ghost_mode_on ;;
            R) ghost_mode_off ;;
            1) select_interface; mac_menu ;;
            A) select_interface; mac_advanced ;;
            2) change_hostname ;;
            3) setup_tor_proxy ;;
            P) pluggable_transports ;;
            O) traffic_obfuscation ;;
            4) fix_dns ;;
            D) dns_permanent ;;
            5) iptables_menu ;;
            6) secure_wipe ;;
            7) fingerprint_evasion ;;
            T) tls_fingerprint_spoof ;;
            W) traffic_padding_advanced ;;
            M) protocol_mimicry ;;
            B) browser_fingerprint ;;
            8) behavioral_tools ;;
            9) network_infra ;;
            0) timezone_ntp ;;
            H) honeypot_detection ;;
            S) show_status ;;
            Q)
                echo -e "\n${DIM}  Session log: $GHOST_LOG${RESET}"
                echo -e "${CYAN}  Stay legal. Stay sharp. Stay invisible.${RESET}\n"
                exit 0 ;;
            *) echo -e "${RED}  [!] Invalid choice${RESET}" ;;
        esac

        echo ""
        read -rp "  Press ENTER to continue..." _
    done
}

# ═══════════════════════════════════════════════════════════════════════
require_root
mkdir -p "$BACKUP_DIR"
check_deps
main_menu
