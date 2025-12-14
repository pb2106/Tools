#!/bin/bash
#
# minecraft-performance.sh
# Optimizes Kali Linux system for Minecraft Java Edition performance
# Compatible with Intel graphics and Legacy Minecraft Launcher
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Minecraft Performance Optimizer ===${NC}\n"

# ============================================================================
# SECTION 1: CPU Governor Configuration
# ============================================================================
echo -e "${YELLOW}[1/4] Configuring CPU governor to performance mode...${NC}"

if [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    echo -e "${RED}Warning: CPU frequency scaling not available${NC}"
else
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: CPU governor configuration requires root privileges${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
    echo -e "${GREEN}✓ CPU governor set to performance${NC}"
fi

# ============================================================================
# SECTION 2: Thermal Management
# ============================================================================
echo -e "\n${YELLOW}[2/4] Configuring thermal management...${NC}"

if ! command -v thermald &> /dev/null; then
    echo -e "${YELLOW}Warning: thermald not installed, skipping${NC}"
else
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: thermald configuration requires root privileges${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    systemctl enable thermald --now &> /dev/null
    echo -e "${GREEN}✓ thermald enabled and started${NC}"
fi

# ============================================================================
# SECTION 3: Stop Background Services
# ============================================================================
echo -e "\n${YELLOW}[3/4] Stopping unnecessary background services...${NC}"

SERVICES=("apache2" "postgresql" "tor")
STOPPED_SERVICES=()

for service in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${service}.service"; then
        if systemctl is-active --quiet "$service"; then
            if [ "$EUID" -ne 0 ]; then
                echo -e "${RED}Error: Stopping services requires root privileges${NC}"
                echo "Please run: sudo $0"
                exit 1
            fi
            
            systemctl stop "$service" &> /dev/null
            STOPPED_SERVICES+=("$service")
            echo -e "${GREEN}✓ Stopped $service${NC}"
        else
            echo -e "  $service already stopped"
        fi
    else
        echo -e "  $service not installed (skipping)"
    fi
done

# Save stopped services list for revert script
if [ ${#STOPPED_SERVICES[@]} -gt 0 ]; then
    echo "${STOPPED_SERVICES[@]}" > /tmp/minecraft_stopped_services.txt
fi

# ============================================================================
# SECTION 4: Launch Minecraft with Intel Mesa Optimizations
# ============================================================================
echo -e "\n${YELLOW}[4/4] Launching Minecraft with optimized settings...${NC}"

if ! command -v legacylauncher &> /dev/null; then
    echo -e "${RED}Error: legacylauncher command not found${NC}"
    echo "Please ensure Legacy Minecraft Launcher is installed and in PATH"
    exit 1
fi

# Set Intel Mesa overrides for OpenGL 4.6 compatibility
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLSL_VERSION_OVERRIDE=460

echo -e "${GREEN}✓ Mesa overrides applied:${NC}"
echo "  MESA_GL_VERSION_OVERRIDE=4.6"
echo "  MESA_GLSL_VERSION_OVERRIDE=460"
echo -e "\n${GREEN}Launching Legacy Minecraft Launcher...${NC}\n"

# Launch Minecraft with environment variables applied
sudo -u naegleria env \
  HOME=/home/naegleria \
  legacylauncher


echo -e "\n${GREEN}=== Minecraft session ended ===${NC}"
echo -e "${YELLOW}Run minecraft-revert.sh to restore normal system settings${NC}"
