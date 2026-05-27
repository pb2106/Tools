#!/bin/bash
# ================================================================
#  sysaudit.sh — Menu-driven Security Audit & Hardening Tool
#  Usage : sudo bash sysaudit.sh
#  Log   : /var/log/sysaudit_<timestamp>.log
# ================================================================

# ── USER FLAGS: set true to auto-remove on every run ─────────
REMOVE_ZEROTIER=true
REMOVE_WAZUH=true
REMOVE_FILEBEAT=true
REMOVE_ANYDESK=true
# ─────────────────────────────────────────────────────────────

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m';    YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m';   BLUE='\033[0;34m';   BOLD='\033[1m'
MAGENTA='\033[0;35m';NC='\033[0m'

# ── Logging ──────────────────────────────────────────────────
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="/var/log/sysaudit_${TIMESTAMP}.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "Session started: $(date)" >> "$LOGFILE"

# ── Privilege check ──────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Run as root: sudo bash $0${NC}"; exit 1
fi

# ── Global findings accumulator ──────────────────────────────
FINDINGS=()

# ── Helpers ──────────────────────────────────────────────────
section() {
    echo ""
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════${NC}"
}
ok()          { echo -e "${GREEN}[✔]${NC} $1"; }
warn()        { echo -e "${YELLOW}[!]${NC} $1"; }
bad()         { echo -e "${RED}[✘]${NC} $1"; }
info()        { echo -e "    $1"; }
add_finding() { FINDINGS+=("$1"); }

pause() {
    echo ""
    read -rp "  Press Enter to return to menu..." _
}

# ================================================================
#  BOOT: install required tools (runs once at startup)
# ================================================================
install_tools() {
    section "Installing required tools"
    for tool in rkhunter chkrootkit debsums; do
        if ! command -v "$tool" &>/dev/null; then
            warn "$tool not found — installing..."
            apt-get install -y "$tool" &>/dev/null \
                && ok "$tool installed" \
                || bad "Failed to install $tool"
        else
            ok "$tool present"
        fi
    done
}

# ================================================================
#  SECTION FUNCTIONS
# ================================================================

# ── [1] System Snapshot ──────────────────────────────────────
run_snapshot() {
    section "System Snapshot"

    echo -e "\n${BOLD}── Enabled unit files ──${NC}"
    systemctl list-unit-files --state=enabled

    echo -e "\n${BOLD}── Running services ──${NC}"
    systemctl --type=service --state=running

    echo -e "\n${BOLD}── Listening ports ──${NC}"
    ss -tulpn

    echo -e "\n${BOLD}── Open network connections ──${NC}"
    lsof -i -P -n 2>/dev/null

    echo -e "\n${BOLD}── Process tree ──${NC}"
    ps auxf

    echo -e "\n${BOLD}── Login history ──${NC}"
    last

    echo -e "\n${BOLD}── Loaded kernel modules ──${NC}"
    lsmod

    ok "Snapshot complete"
}

# ── [2] Cron Audit ───────────────────────────────────────────
run_cron() {
    section "Cron Audit"

    echo "--- root crontab ---"
    crontab -l 2>/dev/null || echo "none"

    echo "--- /etc/crontab ---"
    cat /etc/crontab 2>/dev/null

    echo "--- /etc/cron.d/ ---"
    ls -la /etc/cron.d/
    for f in /etc/cron.d/*; do
        [[ "$f" == *placeholder ]] && continue
        echo "=== $f ==="
        cat "$f"
        if grep -qE '/tmp/|/dev/shm/|curl|wget|bash -i|nc |ncat' "$f" 2>/dev/null; then
            bad "Suspicious content in $f"
            add_finding "Suspicious cron entry in $f: $(grep -E '/tmp/|/dev/shm/|curl|wget|bash -i|nc |ncat' "$f")"
        fi
    done

    for dir in /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.hourly; do
        echo "--- $dir ---"
        ls -la "$dir"
    done

    echo "--- User crontabs ---"
    for user_home in /home/*; do
        user=$(basename "$user_home")
        ctab=$(crontab -u "$user" -l 2>/dev/null)
        [[ -n "$ctab" ]] && echo "[$user]: $ctab"
    done

    ok "Cron audit complete"
}

# ── [3] Security Checks ──────────────────────────────────────
run_security() {
    section "Security Checks"

    # ld.so.preload
    echo -e "\n${BOLD}── ld.so.preload ──${NC}"
    if [[ -s /etc/ld.so.preload ]]; then
        bad "/etc/ld.so.preload NOT empty — possible hijack!"
        cat /etc/ld.so.preload
        add_finding "ld.so.preload has entries: $(cat /etc/ld.so.preload)"
    else
        ok "/etc/ld.so.preload empty"
    fi

    # Processes in /tmp
    echo -e "\n${BOLD}── Processes in /tmp or /dev/shm ──${NC}"
    TMPPROCS=$(ps auxf 2>/dev/null | grep -E '(/tmp/|/dev/shm/)' | grep -v grep)
    [[ -n "$TMPPROCS" ]] && { bad "Processes in temp dirs!"; echo "$TMPPROCS"
        add_finding "Process running from temp dir: $TMPPROCS"; } \
    || ok "None"

    # Files in /tmp and /dev/shm
    echo -e "\n${BOLD}── Files in /tmp and /dev/shm ──${NC}"
    find /tmp /dev/shm -type f 2>/dev/null

    # Deleted file handles
    echo -e "\n${BOLD}── Deleted file handles ──${NC}"
    DELETED=$(lsof 2>/dev/null | grep -i deleted)
    if [[ -n "$DELETED" ]]; then
        warn "Deleted file handles open:"
        echo "$DELETED"
        SUSP=$(echo "$DELETED" | grep -vE 'chromium|firefox|systemd|journal|tmp.*lock')
        [[ -n "$SUSP" ]] && add_finding "Suspicious deleted file handles: $SUSP"
    else
        ok "None"
    fi

    # SUID audit
    echo -e "\n${BOLD}── SUID binary audit ──${NC}"
    find / -xdev -perm /4000 -type f 2>/dev/null | sort > /tmp/_suid.txt
    KNOWN_SUID=(
        /usr/bin/sudo /usr/bin/su /usr/bin/passwd /usr/bin/chsh /usr/bin/chfn
        /usr/bin/gpasswd /usr/bin/newgrp /usr/bin/mount /usr/bin/umount
        /usr/bin/pkexec /usr/bin/fusermount3 /usr/bin/fusermount
        /usr/sbin/pppd /usr/lib/openssh/ssh-keysign
        /usr/lib/dbus-1.0/dbus-daemon-launch-helper
        /usr/lib/policykit-1/polkit-agent-helper-1
        /usr/lib/polkit-1/polkit-agent-helper-1
    )
    while IFS= read -r bin; do
        known=false
        for k in "${KNOWN_SUID[@]}"; do [[ "$bin" == "$k" ]] && known=true && break; done
        [[ "$known" == false ]] && { warn "Unusual SUID: $bin"
            add_finding "Unusual SUID binary: $bin"; }
    done < /tmp/_suid.txt
    rm -f /tmp/_suid.txt
    ok "SUID scan done"

    # UID 0
    echo -e "\n${BOLD}── UID 0 accounts ──${NC}"
    while IFS=: read -r user _ uid _ _ _ _; do
        if [[ "$uid" == "0" && "$user" != "root" ]]; then
            bad "Non-root UID 0: $user"
            add_finding "UID 0 account (not root): $user"
        fi
    done < /etc/passwd
    ok "UID check done"

    # Interactive shells
    echo -e "\n${BOLD}── Interactive shell accounts ──${NC}"
    while IFS=: read -r user _ uid _ _ _ shell; do
        if [[ "$uid" -ge 1000 ]] 2>/dev/null && \
           [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" && -n "$shell" ]]; then
            info "Account: $user (uid=$uid shell=$shell)"
        fi
    done < /etc/passwd

    # SSH keys
    echo -e "\n${BOLD}── SSH authorized_keys ──${NC}"
    for dir in /root /home/*; do
        keyfile="$dir/.ssh/authorized_keys"
        if [[ -f "$keyfile" ]]; then
            warn "Found: $keyfile"
            cat "$keyfile"
            add_finding "SSH authorized_keys present: $keyfile — review keys"
        fi
    done
    ok "SSH key check done"

    # SSH config
    echo -e "\n${BOLD}── SSH config ──${NC}"
    SSHD_CFG="/etc/ssh/sshd_config"
    if [[ -f "$SSHD_CFG" ]]; then
        PASSAUTH=$(grep -iE '^PasswordAuthentication' "$SSHD_CFG" | awk '{print $2}')
        ROOTLOGIN=$(grep -iE '^PermitRootLogin' "$SSHD_CFG" | awk '{print $2}')
        info "PasswordAuthentication: ${PASSAUTH:-not set (default yes)}"
        info "PermitRootLogin: ${ROOTLOGIN:-not set}"
        [[ "${PASSAUTH,,}" == "yes" ]] && \
            add_finding "SSH PasswordAuthentication is YES — recommend key-only auth"
        [[ "${ROOTLOGIN,,}" == "yes" ]] && \
            add_finding "SSH PermitRootLogin is YES — recommend disabling"
    fi

    # Sudoers
    echo -e "\n${BOLD}── Sudoers ──${NC}"
    visudo -c 2>&1
    grep -vE '^#|^$' /etc/sudoers 2>/dev/null
    ls -la /etc/sudoers.d/ 2>/dev/null
    for f in /etc/sudoers.d/*; do
        [[ "$f" == *placeholder* ]] && continue
        echo "=== $f ==="; cat "$f" 2>/dev/null
    done

    # World-writable dirs
    echo -e "\n${BOLD}── World-writable directories ──${NC}"
    find / -xdev -type d -perm -0002 \
        -not -path "*/proc/*" -not -path "*/sys/*" \
        -not -path "*/tmp*"   -not -path "*/dev/shm*" \
        2>/dev/null | head -30

    # Recently modified system files
    echo -e "\n${BOLD}── Recently modified system files (24h) ──${NC}"
    find /etc /bin /sbin /usr/bin /usr/sbin \
        -type f -newer /proc/1/exe 2>/dev/null | head -40

    # Kernel modules
    echo -e "\n${BOLD}── Kernel modules without modinfo ──${NC}"
    lsmod | awk 'NR>1 {print $1}' | while read -r mod; do
        modinfo "$mod" &>/dev/null || {
            warn "No modinfo: $mod"
            add_finding "Suspicious kernel module (no modinfo): $mod"
        }
    done
    ok "Security checks complete"
}

# ── [4] Network Checks ───────────────────────────────────────
run_network() {
    section "Network Checks"

    echo -e "\n${BOLD}── Promiscuous interfaces ──${NC}"
    PROMISC=$(ip link show 2>/dev/null | grep -i promisc \
        | grep -v 'docker\|br-\|veth\|lo')
    if [[ -n "$PROMISC" ]]; then
        warn "Promiscuous interface detected:"
        echo "$PROMISC"
        add_finding "Promiscuous mode on non-virtual interface: $PROMISC"
    else
        ok "None"
    fi

    echo -e "\n${BOLD}── DNS resolvers ──${NC}"
    cat /etc/resolv.conf 2>/dev/null
    KNOWN_DNS=("1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4" "9.9.9.9" "127.0.0.53" "127.0.0.1")
    while IFS= read -r dns; do
        known=false
        for k in "${KNOWN_DNS[@]}"; do [[ "$dns" == "$k" ]] && known=true && break; done
        [[ "$known" == false ]] && { warn "Unusual DNS: $dns"
            add_finding "Unexpected DNS server: $dns"; } \
        || ok "DNS $dns — standard"
    done <<< "$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}')"

    echo -e "\n${BOLD}── ARP table (duplicate MACs) ──${NC}"
    arp -n 2>/dev/null || ip neigh 2>/dev/null
    DUPE=$(arp -n 2>/dev/null | awk '{print $3}' | sort \
        | uniq -d | grep -v '<incomplete>\|Address')
    if [[ -n "$DUPE" ]]; then
        bad "Duplicate MACs — possible ARP poisoning!"
        echo "$DUPE"
        add_finding "Duplicate MAC in ARP table: $DUPE"
    else
        ok "No duplicate MACs"
    fi

    echo -e "\n${BOLD}── Outbound connections + reverse DNS ──${NC}"
    OUTBOUND=$(ss -tnp state established 2>/dev/null | awk 'NR>1 {print $4, $5, $6}')
    echo "$OUTBOUND"
    MY_NETS=("192.168." "10." "172.1" "127." "::1")
    while IFS= read -r line; do
        remote_ip=$(echo "$line" | awk '{print $2}' | cut -d: -f1)
        [[ -z "$remote_ip" ]] && continue
        local_ip=false
        for net in "${MY_NETS[@]}"; do
            [[ "$remote_ip" == ${net}* ]] && local_ip=true && break
        done
        if [[ "$local_ip" == false ]]; then
            rdns=$(host "$remote_ip" 2>/dev/null \
                | awk '/domain name pointer/ {print $5}' | head -1)
            echo "  $remote_ip → ${rdns:-no PTR record}"
        fi
    done <<< "$OUTBOUND"

    echo -e "\n${BOLD}── UFW rules ──${NC}"
    if command -v ufw &>/dev/null; then
        ufw status verbose
    else
        warn "ufw not installed"
        iptables -L -n -v 2>/dev/null | head -60
    fi

    ok "Network checks complete"
}

# ── [5] Persistence Checks ───────────────────────────────────
run_persistence() {
    section "Persistence Checks"
    SUSPICIOUS_PATTERN='curl|wget|bash -i|/tmp/|/dev/shm/|nc |ncat|python.*-c|perl.*-e|base64'

    echo -e "\n${BOLD}── User-level systemd services ──${NC}"
    for user_home in /root /home/*; do
        sd="$user_home/.config/systemd/user"
        [[ ! -d "$sd" ]] && continue
        warn "Found: $sd"
        find "$sd" -type f | while read -r f; do
            echo "  $f"; cat "$f"
            add_finding "User-level systemd service: $f"
        done
    done
    ok "User systemd check done"

    echo -e "\n${BOLD}── Shell startup files ──${NC}"
    SHELL_FILES=(/root/.bashrc /root/.bash_profile /root/.profile
                 /etc/profile /etc/bash.bashrc)
    for h in /home/*; do
        SHELL_FILES+=("$h/.bashrc" "$h/.bash_profile" "$h/.profile")
    done
    for f in "${SHELL_FILES[@]}"; do
        [[ ! -f "$f" ]] && continue
        match=$(grep -nE "$SUSPICIOUS_PATTERN" "$f" 2>/dev/null)
        if [[ -n "$match" ]]; then
            bad "Suspicious content in $f:"; echo "$match"
            add_finding "Shell startup injection in $f: $match"
        else
            ok "$f — clean"
        fi
    done

    echo -e "\n${BOLD}── /etc/profile.d/ ──${NC}"
    ls -la /etc/profile.d/
    for f in /etc/profile.d/*.sh; do
        [[ ! -f "$f" ]] && continue
        echo "=== $f ==="; cat "$f"
        match=$(grep -nE "$SUSPICIOUS_PATTERN" "$f" 2>/dev/null)
        [[ -n "$match" ]] && {
            bad "Suspicious: $f"; add_finding "Suspicious profile.d script: $f — $match"; }
    done

    echo -e "\n${BOLD}── XDG autostart entries ──${NC}"
    for h in /root /home/*; do
        ad="$h/.config/autostart"
        [[ ! -d "$ad" ]] && continue
        warn "Autostart entries for $(basename "$h"):"
        for f in "$ad"/*.desktop; do
            [[ ! -f "$f" ]] && continue
            echo "  === $f ==="; cat "$f"
            exec_line=$(grep -i '^Exec=' "$f" | head -1)
            if echo "$exec_line" | grep -qE '/tmp/|/dev/shm/|curl|wget|bash -i'; then
                bad "Suspicious autostart: $f"
                add_finding "Suspicious XDG autostart: $f — $exec_line"
            fi
        done
    done
    ok "Autostart check done"

    echo -e "\n${BOLD}── SSH rc files ──${NC}"
    for dir in /root /home/*; do
        for rcfile in "$dir/.ssh/rc" /etc/ssh/sshrc; do
            if [[ -f "$rcfile" ]]; then
                warn "SSH rc: $rcfile"; cat "$rcfile"
                add_finding "SSH rc file present: $rcfile"
            fi
        done
    done
    ok "SSH rc check done"

    echo -e "\n${BOLD}── .rhosts and hosts.equiv ──${NC}"
    for dir in /root /home/*; do
        if [[ -f "$dir/.rhosts" ]]; then
            bad ".rhosts found: $dir/.rhosts"; cat "$dir/.rhosts"
            add_finding ".rhosts file — serious risk: $dir/.rhosts"
        fi
    done
    if [[ -f /etc/hosts.equiv ]]; then
        bad "/etc/hosts.equiv found!"; cat /etc/hosts.equiv
        add_finding "/etc/hosts.equiv present — serious risk"
    fi
    ok "Legacy trust file check done"
}

# ── [6] User & Auth Checks ───────────────────────────────────
run_users() {
    section "User & Auth Checks"

    echo -e "\n${BOLD}── Failed login attempts ──${NC}"
    AUTH_LOG=""
    for log in /var/log/auth.log /var/log/secure; do
        [[ -f "$log" ]] && AUTH_LOG="$log" && break
    done
    if [[ -n "$AUTH_LOG" ]]; then
        echo "Top 20 IPs with failed logins:"
        grep -iE 'failed|invalid|failure' "$AUTH_LOG" 2>/dev/null \
            | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' \
            | sort | uniq -c | sort -rn | head -20
        echo ""
        echo "Last 30 failed attempts:"
        grep -iE 'failed password|invalid user' "$AUTH_LOG" 2>/dev/null | tail -30
        HIGH=$(grep -iE 'failed|invalid|failure' "$AUTH_LOG" 2>/dev/null \
            | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' \
            | sort | uniq -c | sort -rn | awk '$1>20 {print $2}')
        [[ -n "$HIGH" ]] && {
            bad "Brute force suspects (>20 failures):"; echo "$HIGH"
            add_finding "Brute force suspects: $HIGH"; }
    else
        warn "No auth log found"
    fi

    echo -e "\n${BOLD}── Recently created home directories ──${NC}"
    find /home -maxdepth 1 -type d -newer /proc/1/exe \
        -not -name home 2>/dev/null | while read -r d; do
        warn "Recent home dir: $d"
        add_finding "Recently created user: $(basename "$d")"
    done
    ok "Recent user check done"

    echo -e "\n${BOLD}── Empty / no passwords ──${NC}"
    EMPTY=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null)
    if [[ -n "$EMPTY" ]]; then
        bad "Accounts with NO password:"; echo "$EMPTY"
        add_finding "Account with no password: $EMPTY"
    else
        ok "No accounts with empty passwords"
    fi

    echo -e "\n${BOLD}── Immutable files in /etc ──${NC}"
    IMMUT=$(lsattr /etc 2>/dev/null | grep '^----i' | awk '{print $2}')
    if [[ -n "$IMMUT" ]]; then
        warn "Immutable files in /etc:"; echo "$IMMUT"
        add_finding "Immutable files in /etc: $IMMUT"
    else
        ok "None"
    fi

    ok "User & auth checks complete"
}

# ── [7] Docker Audit ─────────────────────────────────────────
run_docker() {
    section "Docker Audit"

    if ! command -v docker &>/dev/null || \
       ! systemctl is-active --quiet docker 2>/dev/null; then
        info "Docker not running or not installed — skipping"
        return
    fi

    echo -e "\n${BOLD}── Running containers ──${NC}"
    docker ps --format \
        "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null

    echo -e "\n${BOLD}── All containers (inc. stopped) ──${NC}"
    docker ps -a --format \
        "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null

    echo -e "\n${BOLD}── High-risk container configs ──${NC}"
    docker ps -q 2>/dev/null | xargs -I{} docker inspect {} 2>/dev/null \
    | python3 -c "
import sys, json
try:
    containers = json.load(sys.stdin)
except:
    containers = []
for c in containers:
    name = c.get('Name','?')
    priv = c['HostConfig'].get('Privileged', False)
    mounts = [m.get('Source','') for m in c.get('Mounts', [])]
    net = c['HostConfig'].get('NetworkMode','')
    caps = c['HostConfig'].get('CapAdd') or []
    sock = '/var/run/docker.sock' in mounts
    if priv or sock or net=='host' or 'SYS_ADMIN' in caps:
        print(f'  FLAGGED: {name}')
        if priv:         print('    → Privileged mode')
        if sock:         print('    → Docker socket mounted (container escape risk)')
        if net=='host':  print('    → Host network mode')
        if caps:         print(f'    → Extra capabilities: {caps}')
" 2>/dev/null && ok "Container config check done"

    echo -e "\n${BOLD}── Docker images ──${NC}"
    docker images --format \
        "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" 2>/dev/null

    echo -e "\n${BOLD}── Docker networks ──${NC}"
    docker network ls 2>/dev/null

    # Interactive stop
    RUNNING=$(docker ps -q 2>/dev/null)
    if [[ -n "$RUNNING" ]]; then
        echo ""
        warn "Running containers:"
        docker ps --format "  [{{.ID}}] {{.Names}} — {{.Image}} ({{.Status}})" 2>/dev/null
        echo ""
        read -rp "  Stop ALL running containers? [y/N]: " stop_all
        if [[ "${stop_all,,}" == "y" ]]; then
            docker stop $(docker ps -q) 2>/dev/null
            ok "All containers stopped"
        else
            docker ps --format "{{.ID}} {{.Names}} {{.Image}}" 2>/dev/null \
            | while read -r cid cname cimage; do
                echo ""
                echo -e "  Container: ${BOLD}$cname${NC} | Image: $cimage | ID: $cid"
                read -rp "  Stop this container? [y/N]: " stop_one
                [[ "${stop_one,,}" == "y" ]] && \
                    docker stop "$cid" 2>/dev/null && ok "Stopped $cname" \
                    || info "Kept: $cname"
            done
        fi
    fi
    ok "Docker audit complete"
}

# ── [8] Package Integrity ────────────────────────────────────
run_packages() {
    section "Package Integrity"

    echo -e "\n${BOLD}── debsums: verify installed binaries ──${NC}"
    echo "(This may take a minute...)"
    DEBOUT=$(debsums --silent 2>/dev/null)
    if [[ -n "$DEBOUT" ]]; then
        bad "Changed/missing package files:"; echo "$DEBOUT"
        add_finding "debsums failures (possible tampered binaries): $DEBOUT"
    else
        ok "All package files intact"
    fi

    echo -e "\n${BOLD}── Recent installs/upgrades (dpkg log) ──${NC}"
    grep -E 'install|upgrade' /var/log/dpkg.log 2>/dev/null | tail -30

    echo -e "\n${BOLD}── Binaries newer than 7 days ──${NC}"
    find /usr/bin /usr/sbin /bin /sbin -type f -mtime -7 2>/dev/null | head -20

    echo -e "\n${BOLD}── Kernel version ──${NC}"
    echo "Kernel : $(uname -r)"
    echo "Arch   : $(uname -m)"
    echo "Full   : $(uname -a)"
    info "Check https://www.cvedetails.com/version-search.php for CVEs"

    ok "Package integrity check complete"
}

# ── [9] Rootkit Scans ────────────────────────────────────────
run_rootkit() {
    section "Rootkit Scans"

    echo -e "\n${BOLD}── rkhunter ──${NC}"
    rkhunter --update &>/dev/null \
        && ok "rkhunter DB updated" \
        || warn "rkhunter update failed"
    rkhunter --check --sk 2>&1
    RKH=$(rkhunter --check --sk 2>&1 | grep -iE 'warning|found')
    if [[ -n "$RKH" ]]; then
        warn "rkhunter warnings:"; echo "$RKH"
        add_finding "rkhunter: $RKH"
    else
        ok "rkhunter: clean"
    fi

    echo -e "\n${BOLD}── chkrootkit ──${NC}"
    CHKRK=$(chkrootkit 2>&1)
    echo "$CHKRK"
    INFECTED=$(echo "$CHKRK" | grep "INFECTED")
    if [[ -n "$INFECTED" ]]; then
        bad "chkrootkit INFECTED:"; echo "$INFECTED"
        add_finding "chkrootkit INFECTED: $INFECTED"
    else
        ok "chkrootkit: clean"
    fi
}

# ── [10] Auto-Remove Flagged Services ────────────────────────
run_autoremove() {
    section "Auto-Remove Flagged Services"

    purge_service() {
        local label="$1" unit="$2" pkgs="$3"; shift 3
        local extra_dirs=("$@")
        local found=false
        systemctl is-active --quiet "$unit" 2>/dev/null && found=true
        for pkg in $pkgs; do dpkg -l "$pkg" &>/dev/null && found=true; done
        if [[ "$found" == true ]]; then
            warn "Removing $label..."
            systemctl stop "$unit" 2>/dev/null
            systemctl disable "$unit" 2>/dev/null
            for pkg in $pkgs; do apt-get purge -y "$pkg" &>/dev/null; done
            for d in "${extra_dirs[@]}"; do rm -rf "$d"; done
            ok "$label removed"
        else
            info "$label not found — skipping"
        fi
    }

    [[ "$REMOVE_ZEROTIER" == true ]] && \
        purge_service "ZeroTier" "zerotier-one" "zerotier-one" \
            "/var/lib/zerotier-one"

    [[ "$REMOVE_WAZUH" == true ]] && {
        warn "Stopping Wazuh stack..."
        for svc in wazuh-manager wazuh-indexer wazuh-dashboard; do
            systemctl stop "$svc" 2>/dev/null
            systemctl disable "$svc" 2>/dev/null
        done
        for pkg in wazuh-manager wazuh-indexer wazuh-dashboard; do
            apt-get purge -y "$pkg" &>/dev/null
        done
        rm -rf /var/ossec /usr/share/wazuh-indexer /usr/share/wazuh-dashboard \
               /etc/wazuh-indexer /var/lib/wazuh-indexer /var/log/wazuh-indexer \
               /etc/wazuh-dashboard
        ok "Wazuh stack removed"
    }

    [[ "$REMOVE_FILEBEAT" == true ]] && \
        purge_service "Filebeat" "filebeat" "filebeat" \
            "/etc/filebeat" "/var/lib/filebeat" "/usr/share/filebeat"

    [[ "$REMOVE_ANYDESK" == true ]] && \
        purge_service "AnyDesk" "anydesk" "anydesk" \
            "/etc/anydesk" "/var/lib/anydesk"

    apt-get autoremove -y &>/dev/null && ok "Autoremove complete"
}

# ── [11] System Hardening ────────────────────────────────────
run_hardening() {
    section "System Hardening"
    echo -e "${YELLOW}Each check shows current state and asks before changing anything.${NC}"
    echo ""

    harden_ask() {
        local label="$1" check_cmd="$2" fix_cmd="$3" desc="$4"
        if eval "$check_cmd" &>/dev/null; then
            ok "[Already hardened] $label"
            echo "HARDENING_SKIP: $label" >> "$LOGFILE"
        else
            warn "[Not hardened] $label"
            echo -e "  What this does: ${CYAN}$desc${NC}"
            read -rp "  Apply? [y/N]: " ans
            if [[ "${ans,,}" == "y" ]]; then
                eval "$fix_cmd" && {
                    ok "Applied: $label"
                    echo "HARDENING_APPLIED: $label" >> "$LOGFILE"
                } || {
                    bad "Failed: $label"
                    echo "HARDENING_FAILED: $label" >> "$LOGFILE"
                }
            else
                info "Skipped: $label"
                echo "HARDENING_SKIPPED: $label" >> "$LOGFILE"
            fi
        fi
        echo ""
    }

    SSHD="/etc/ssh/sshd_config"
    sshd_set() { local k="$1" v="$2"
        grep -qiE "^#?${k}" "$SSHD" \
            && sed -i "s|^#\?${k}.*|${k} ${v}|I" "$SSHD" \
            || echo "${k} ${v}" >> "$SSHD"; }
    restart_ssh() {
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; }

    SYSCTL_FILE="/etc/sysctl.d/99-sysaudit-hardening.conf"
    apply_sysctl() { local k="$1" v="$2"
        [[ ! -f "$SYSCTL_FILE" ]] && \
            echo "# Applied by sysaudit.sh $(date)" > "$SYSCTL_FILE"
        grep -q "^${k}" "$SYSCTL_FILE" 2>/dev/null \
            && sed -i "s|^${k}.*|${k} = ${v}|" "$SYSCTL_FILE" \
            || echo "${k} = ${v}" >> "$SYSCTL_FILE"
        sysctl -w "${k}=${v}" &>/dev/null; }

    # ── SSH
    echo -e "${BOLD}── SSH ─────────────────────────────────────────────────${NC}"
    harden_ask "SSH: Disable password auth" \
        "grep -iE '^PasswordAuthentication no' $SSHD" \
        "sshd_set PasswordAuthentication no && restart_ssh" \
        "Forces key-based login — prevents brute-force password attacks"
    harden_ask "SSH: Disable root login" \
        "grep -iE '^PermitRootLogin (no|prohibit-password)' $SSHD" \
        "sshd_set PermitRootLogin no && restart_ssh" \
        "Prevents direct root SSH login"
    harden_ask "SSH: Disable X11 forwarding" \
        "grep -iE '^X11Forwarding no' $SSHD" \
        "sshd_set X11Forwarding no && restart_ssh" \
        "Prevents X11 forwarding — can be used for session hijacking"
    harden_ask "SSH: MaxAuthTries 3" \
        "grep -iE '^MaxAuthTries [1-3]$' $SSHD" \
        "sshd_set MaxAuthTries 3 && restart_ssh" \
        "Cuts connection after 3 failed auth attempts"
    harden_ask "SSH: Idle timeout 5 min" \
        "grep -iE '^ClientAliveInterval 300' $SSHD" \
        "sshd_set ClientAliveInterval 300 && sshd_set ClientAliveCountMax 2 && restart_ssh" \
        "Disconnects idle SSH sessions after 5 minutes"
    harden_ask "SSH: No empty passwords" \
        "grep -iE '^PermitEmptyPasswords no' $SSHD" \
        "sshd_set PermitEmptyPasswords no && restart_ssh" \
        "Blocks login to accounts with no password"

    # ── Firewall
    echo -e "${BOLD}── Firewall (UFW) ──────────────────────────────────────${NC}"
    harden_ask "UFW: Enable firewall" \
        "ufw status | grep -q 'Status: active'" \
        "ufw --force enable" \
        "Activates the firewall"
    harden_ask "UFW: Default deny incoming" \
        "ufw status verbose | grep -q 'Default: deny (incoming)'" \
        "ufw default deny incoming" \
        "Blocks all inbound unless explicitly allowed"
    harden_ask "UFW: Default allow outgoing" \
        "ufw status verbose | grep -q 'Default: allow (outgoing)'" \
        "ufw default allow outgoing" \
        "Allows all outbound by default"
    harden_ask "UFW: Allow SSH" \
        "ufw status | grep -qE '22.*ALLOW'" \
        "ufw allow ssh" \
        "Ensures SSH stays accessible after enabling firewall"

    # ── Sysctl
    echo -e "${BOLD}── Kernel / Sysctl ─────────────────────────────────────${NC}"
    harden_ask "Sysctl: SYN flood protection" \
        "[[ \$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null) == '1' ]]" \
        "apply_sysctl net.ipv4.tcp_syncookies 1" \
        "SYN cookies protect against SYN flood DoS attacks"
    harden_ask "Sysctl: Disable ICMP redirect acceptance" \
        "[[ \$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null) == '0' ]]" \
        "apply_sysctl net.ipv4.conf.all.accept_redirects 0
         apply_sysctl net.ipv4.conf.default.accept_redirects 0
         apply_sysctl net.ipv6.conf.all.accept_redirects 0" \
        "Prevents ICMP redirect attacks rerouting your traffic"
    harden_ask "Sysctl: Disable sending ICMP redirects" \
        "[[ \$(sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null) == '0' ]]" \
        "apply_sysctl net.ipv4.conf.all.send_redirects 0
         apply_sysctl net.ipv4.conf.default.send_redirects 0" \
        "Stops this host acting as a router sending redirects"
    harden_ask "Sysctl: Disable source routing" \
        "[[ \$(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null) == '0' ]]" \
        "apply_sysctl net.ipv4.conf.all.accept_source_route 0
         apply_sysctl net.ipv6.conf.all.accept_source_route 0" \
        "Rejects packets specifying their own route — used in spoofing"
    harden_ask "Sysctl: Log martian packets" \
        "[[ \$(sysctl -n net.ipv4.conf.all.log_martians 2>/dev/null) == '1' ]]" \
        "apply_sysctl net.ipv4.conf.all.log_martians 1
         apply_sysctl net.ipv4.conf.default.log_martians 1" \
        "Logs packets with impossible/spoofed source IPs"
    harden_ask "Sysctl: ASLR enabled (level 2)" \
        "[[ \$(sysctl -n kernel.randomize_va_space 2>/dev/null) == '2' ]]" \
        "apply_sysctl kernel.randomize_va_space 2" \
        "Randomises memory layout — makes exploitation much harder"
    harden_ask "Sysctl: No SUID core dumps" \
        "[[ \$(sysctl -n fs.suid_dumpable 2>/dev/null) == '0' ]]" \
        "apply_sysctl fs.suid_dumpable 0" \
        "Prevents SUID process memory dumps leaking sensitive data"
    harden_ask "Sysctl: kptr_restrict = 2" \
        "[[ \$(sysctl -n kernel.kptr_restrict 2>/dev/null) == '2' ]]" \
        "apply_sysctl kernel.kptr_restrict 2" \
        "Hides kernel symbol addresses — makes kernel exploits harder"
    harden_ask "Sysctl: dmesg restricted to root" \
        "[[ \$(sysctl -n kernel.dmesg_restrict 2>/dev/null) == '1' ]]" \
        "apply_sysctl kernel.dmesg_restrict 1" \
        "Prevents unprivileged users reading kernel messages"
    harden_ask "Sysctl: Disable Magic SysRq" \
        "[[ \$(sysctl -n kernel.sysrq 2>/dev/null) == '0' ]]" \
        "apply_sysctl kernel.sysrq 0" \
        "Disables keyboard shortcuts that can crash/reboot the system"
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        harden_ask "Sysctl: Disable IP forwarding" \
            "[[ \$(sysctl -n net.ipv4.ip_forward 2>/dev/null) == '0' ]]" \
            "apply_sysctl net.ipv4.ip_forward 0" \
            "Stops host forwarding packets — not a router"
    else
        info "Skipping IP forwarding — Docker requires it"
        echo ""
    fi
    [[ -f "$SYSCTL_FILE" ]] && sysctl -p "$SYSCTL_FILE" &>/dev/null \
        && ok "sysctl settings persisted to $SYSCTL_FILE"
    echo ""

    # ── fail2ban
    echo -e "${BOLD}── fail2ban ─────────────────────────────────────────────${NC}"
    if ! command -v fail2ban-client &>/dev/null; then
        warn "fail2ban not installed"
        read -rp "  Install and enable fail2ban (SSH brute-force protection)? [y/N]: " ans
        if [[ "${ans,,}" == "y" ]]; then
            apt-get install -y fail2ban &>/dev/null && {
                cat > /etc/fail2ban/jail.d/sysaudit-ssh.conf << 'EOF'
[sshd]
enabled  = true
port     = ssh
maxretry = 5
bantime  = 3600
findtime = 600
EOF
                systemctl enable --now fail2ban &>/dev/null
                ok "fail2ban installed — SSH jail: 5 retries / 1h ban"
                echo "HARDENING_APPLIED: fail2ban installed" >> "$LOGFILE"
            } || bad "fail2ban install failed"
        else
            info "Skipped"; echo "HARDENING_SKIPPED: fail2ban" >> "$LOGFILE"
        fi
    else
        systemctl is-active --quiet fail2ban \
            && { ok "fail2ban running"; fail2ban-client status 2>/dev/null; } \
            || { warn "fail2ban installed but not running"
                 read -rp "  Start and enable? [y/N]: " ans
                 [[ "${ans,,}" == "y" ]] && systemctl enable --now fail2ban \
                     && ok "fail2ban started"; }
    fi
    echo ""

    # ── auditd
    echo -e "${BOLD}── auditd ───────────────────────────────────────────────${NC}"
    harden_ask "auditd: Install and enable kernel audit daemon" \
        "systemctl is-active --quiet auditd" \
        "apt-get install -y auditd audispd-plugins &>/dev/null && systemctl enable --now auditd &>/dev/null" \
        "Records syscalls, file access, auth events — essential for forensics"

    # ── Unattended upgrades
    echo -e "${BOLD}── Automatic Security Updates ──────────────────────────${NC}"
    harden_ask "Unattended-upgrades: auto security patches" \
        "systemctl is-active --quiet unattended-upgrades" \
        "apt-get install -y unattended-upgrades &>/dev/null && dpkg-reconfigure -plow unattended-upgrades &>/dev/null && systemctl enable --now unattended-upgrades &>/dev/null" \
        "Auto-installs security updates — keeps you patched without manual effort"

    # ── Password policy
    echo -e "${BOLD}── Password Policy ─────────────────────────────────────${NC}"
    LOGIN_DEFS="/etc/login.defs"
    set_login_def() { local k="$1" v="$2"
        grep -qE "^${k}" "$LOGIN_DEFS" \
            && sed -i "s|^${k}.*|${k}\t${v}|" "$LOGIN_DEFS" \
            || echo -e "${k}\t${v}" >> "$LOGIN_DEFS"; }
    harden_ask "Password: Max age 90 days" \
        "grep -qE '^PASS_MAX_DAYS\s+90' $LOGIN_DEFS" \
        "set_login_def PASS_MAX_DAYS 90" \
        "Forces password rotation every 90 days"
    harden_ask "Password: Min age 1 day" \
        "grep -qE '^PASS_MIN_DAYS\s+1' $LOGIN_DEFS" \
        "set_login_def PASS_MIN_DAYS 1" \
        "Prevents immediately reverting to an old password"
    harden_ask "Password: 14-day expiry warning" \
        "grep -qE '^PASS_WARN_AGE\s+14' $LOGIN_DEFS" \
        "set_login_def PASS_WARN_AGE 14" \
        "Warns 14 days before password expires"
    harden_ask "Password: libpam-pwquality (complexity)" \
        "dpkg -l libpam-pwquality &>/dev/null" \
        "apt-get install -y libpam-pwquality &>/dev/null" \
        "Enforces 12-char minimum with mixed case, digits, symbols"

    # ── File permissions
    echo -e "${BOLD}── File Permissions ────────────────────────────────────${NC}"
    harden_ask "Permissions: /root chmod 700" \
        "[[ \$(stat -c '%a' /root) == '700' ]]" \
        "chmod 700 /root" \
        "Only root can access their home directory"
    harden_ask "Permissions: /etc/shadow chmod 640" \
        "[[ \$(stat -c '%a' /etc/shadow) == '640' ]]" \
        "chmod 640 /etc/shadow" \
        "Shadow file readable only by root and shadow group"
    harden_ask "Permissions: /etc/passwd chmod 644" \
        "[[ \$(stat -c '%a' /etc/passwd) == '644' ]]" \
        "chmod 644 /etc/passwd" \
        "Standard safe permissions on passwd file"
    harden_ask "Permissions: /etc/gshadow chmod 640" \
        "[[ \$(stat -c '%a' /etc/gshadow) == '640' ]]" \
        "chmod 640 /etc/gshadow" \
        "Group shadow file restricted to root and shadow group"

    TMP_OPTS=$(mount | grep ' /tmp ' | grep -o 'noexec')
    if [[ "$TMP_OPTS" == "noexec" ]]; then
        ok "/tmp is mounted noexec"
    else
        warn "/tmp is NOT mounted noexec"
        echo -e "  What this does: ${CYAN}Prevents executing binaries dropped into /tmp${NC}"
        read -rp "  Add noexec to /tmp? [y/N]: " ans
        if [[ "${ans,,}" == "y" ]]; then
            if grep -q ' /tmp ' /etc/fstab; then
                sed -i 's|\( /tmp .*defaults\)|\1,noexec,nosuid,nodev|' /etc/fstab
            else
                echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
            fi
            mount -o remount,noexec,nosuid,nodev /tmp 2>/dev/null \
                && ok "/tmp remounted noexec,nosuid,nodev" \
                || warn "fstab updated — takes effect on reboot"
            echo "HARDENING_APPLIED: /tmp noexec" >> "$LOGFILE"
        else
            info "Skipped"; echo "HARDENING_SKIPPED: /tmp noexec" >> "$LOGFILE"
        fi
    fi
    echo ""

    # ── Unnecessary services
    echo -e "${BOLD}── Unnecessary Services ────────────────────────────────${NC}"
    check_and_disable() { local svc="$1" reason="$2"
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            warn "$svc is running — $reason"
            read -rp "  Disable and stop $svc? [y/N]: " ans
            if [[ "${ans,,}" == "y" ]]; then
                systemctl stop "$svc" &>/dev/null
                systemctl disable "$svc" &>/dev/null
                ok "$svc disabled"
                echo "HARDENING_APPLIED: disabled $svc" >> "$LOGFILE"
            else
                info "Kept: $svc"; echo "HARDENING_SKIPPED: $svc" >> "$LOGFILE"
            fi
        else
            ok "$svc not running"
        fi
        echo ""
    }
    check_and_disable "avahi-daemon" \
        "mDNS service — exposes host info, unnecessary on most machines"
    check_and_disable "cups" \
        "Printing service — not needed if you don't print from this machine"
    check_and_disable "bluetooth" \
        "Bluetooth — eliminates BT attack surface if you don't use it"

    # Summary
    echo -e "\n${BOLD}── Hardening Summary ──${NC}"
    grep -E '^HARDENING_' "$LOGFILE" 2>/dev/null | sed 's/^/  /' || echo "  none recorded"
    ok "Hardening complete"
}

# ── [12] Findings Review ─────────────────────────────────────
run_findings_review() {
    section "Findings Review"
    if [[ ${#FINDINGS[@]} -eq 0 ]]; then
        ok "No findings accumulated — system looks clean."
        return
    fi

    bad "${#FINDINGS[@]} finding(s) accumulated this session:"
    echo ""
    for i in "${!FINDINGS[@]}"; do
        echo -e "  ${RED}[$((i+1))]${NC} ${FINDINGS[$i]}"
    done
    echo ""
    echo -e "${YELLOW}Actions: ${BOLD}i${NC}${YELLOW}=ignore  ${BOLD}n${NC}${YELLOW}=note  ${BOLD}r${NC}${YELLOW}=mark for removal${NC}"
    echo ""
    for i in "${!FINDINGS[@]}"; do
        echo -e "\n${BOLD}Finding $((i+1))/${#FINDINGS[@]}:${NC}"
        echo -e "  ${FINDINGS[$i]}"
        read -rp "  Action [i/n/r]: " action
        case "${action,,}" in
            r) echo "  → Marked for removal"
               echo "ACTION_REMOVE: ${FINDINGS[$i]}" >> "$LOGFILE" ;;
            n) echo "  → Noted"
               echo "ACTION_NOTE:   ${FINDINGS[$i]}" >> "$LOGFILE" ;;
            *) echo "  → Ignored"
               echo "ACTION_IGNORE: ${FINDINGS[$i]}" >> "$LOGFILE" ;;
        esac
    done
    FINDINGS=()   # clear after review
    ok "Review complete — findings cleared"
}

# ── [13] View Previous Logs ──────────────────────────────────
view_logs() {
    section "Previous Audit Logs"
    LOGS=$(ls -lt /var/log/sysaudit_*.log 2>/dev/null)
    if [[ -z "$LOGS" ]]; then
        info "No previous logs found in /var/log/"
        return
    fi
    echo "$LOGS"
    echo ""
    read -rp "  Enter log filename to view (or Enter to skip): " logname
    if [[ -n "$logname" && -f "$logname" ]]; then
        less "$logname"
    elif [[ -n "$logname" && -f "/var/log/$logname" ]]; then
        less "/var/log/$logname"
    fi
}

# ================================================================
#  FULL SCAN (runs all sections in order)
# ================================================================
run_full_scan() {
    section "Full Scan"
    echo -e "${YELLOW}Running all sections in sequence...${NC}"
    echo ""
    run_autoremove
    run_snapshot
    run_cron
    run_security
    run_network
    run_persistence
    run_users
    run_docker
    run_packages
    run_rootkit
    run_findings_review
    run_hardening
}

# ================================================================
#  MENU
# ================================================================
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║        VACCUM - Security Audit tool           ║"
    echo "  ╠═══════════════════════════════════════════════╣"
    echo -e "  ║  ${BLUE}SCANNING${CYAN}                                     ║"
    echo "  ║   [1]  System Snapshot                        ║"
    echo "  ║   [2]  Cron Audit                             ║"
    echo "  ║   [3]  Security Checks                        ║"
    echo "  ║   [4]  Network Checks                         ║"
    echo "  ║   [5]  Persistence Checks                     ║"
    echo "  ║   [6]  User & Auth Checks                     ║"
    echo "  ║   [7]  Docker Audit                           ║"
    echo "  ║   [8]  Package Integrity                      ║"
    echo "  ║   [9]  Rootkit Scans                          ║"
    echo "  ╠═══════════════════════════════════════════════╣"
    echo -e "  ║  ${MAGENTA}ACTIONS${CYAN}                                      ║"
    echo "  ║   [10] Auto-Remove Flagged Services           ║"
    echo "  ║   [11] System Hardening                       ║"
    echo "  ╠═══════════════════════════════════════════════╣"
    echo -e "  ║  ${GREEN}OTHER${CYAN}                                        ║"
    echo "  ║   [12] Full Scan (all sections + hardening)   ║"
    echo "  ║   [13] Review Accumulated Findings            ║"
    echo "  ║   [14] View Previous Logs                     ║"
    echo "  ╠═══════════════════════════════════════════════╣"
    echo -e "  ║  ${RED}[0]  Exit${CYAN}                                    ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Log: ${CYAN}${LOGFILE}${NC}"
    [[ ${#FINDINGS[@]} -gt 0 ]] && \
        echo -e "  ${YELLOW}Pending findings: ${#FINDINGS[@]}${NC}"
    echo ""
    echo -e "  Enter option(s) — single ${BOLD}[3]${NC} or multiple ${BOLD}[1 4 6]${NC}:"
    read -rp "  > " choices
}

# ================================================================
#  MAIN
# ================================================================
install_tools

while true; do
    show_menu

    # Handle empty input
    [[ -z "$choices" ]] && continue

    for choice in $choices; do
        case "$choice" in
            1)  run_snapshot;        pause ;;
            2)  run_cron;            pause ;;
            3)  run_security;        pause ;;
            4)  run_network;         pause ;;
            5)  run_persistence;     pause ;;
            6)  run_users;           pause ;;
            7)  run_docker;          pause ;;
            8)  run_packages;        pause ;;
            9)  run_rootkit;         pause ;;
            10) run_autoremove;      pause ;;
            11) run_hardening;       pause ;;
            12) run_full_scan;       pause ;;
            13) run_findings_review; pause ;;
            14) view_logs;           pause ;;
            0)
                section "Goodbye"
                echo -e "  Session log: ${CYAN}${LOGFILE}${NC}"
                echo -e "  Ended: $(date)"
                exit 0
                ;;
            *)
                warn "Unknown option: $choice"
                ;;
        esac
    done
done
