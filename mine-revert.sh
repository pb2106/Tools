#!/bin/bash
#
# minecraft-revert.sh
# Reverts Kali Linux system optimizations back to normal laptop mode
# Restores CPU governor and optionally restarts services
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Minecraft Performance Revert ===${NC}\n"

# ============================================================================
# SECTION 1: Revert CPU Governor
# ============================================================================
echo -e "${YELLOW}[1/2] Reverting CPU governor to powersave mode...${NC}"

if [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    echo -e "${RED}Warning: CPU frequency scaling not available${NC}"
else
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: CPU governor configuration requires root privileges${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
    echo -e "${GREEN}✓ CPU governor restored to powersave${NC}"
fi

# ============================================================================
# SECTION 2: Restart Previously Stopped Services
# ============================================================================
echo -e "\n${YELLOW}[2/2] Restarting previously stopped services...${NC}"

if [ -f /tmp/minecraft_stopped_services.txt ]; then
    readarray -t SERVICES_TO_START < /tmp/minecraft_stopped_services.txt
    
    if [ ${#SERVICES_TO_START[@]} -gt 0 ]; then
        if [ "$EUID" -ne 0 ]; then
            echo -e "${RED}Error: Starting services requires root privileges${NC}"
            echo "Please run: sudo $0"
            exit 1
        fi
        
        for service in "${SERVICES_TO_START[@]}"; do
            if [ -n "$service" ]; then
                systemctl start "$service" &> /dev/null
                echo -e "${GREEN}✓ Restarted $service${NC}"
            fi
        done
        
        # Clean up temporary file
        rm /tmp/minecraft_stopped_services.txt
    else
        echo -e "  No services to restart"
    fi
else
    echo -e "  No record of stopped services found"
    echo -e "  ${YELLOW}Optionally restart services manually if needed:${NC}"
    echo "    sudo systemctl start apache2"
    echo "    sudo systemctl start postgresql"
    echo "    sudo systemctl start tor"
fi

# ============================================================================
# SECTION 3: Confirmation
# ============================================================================
echo -e "\n${GREEN}=== System reverted to normal laptop mode ===${NC}"
echo -e "${GREEN}✓ CPU governor: powersave${NC}"
echo -e "${GREEN}✓ Background services restored${NC}"
echo -e "${GREEN}✓ System ready for normal operation${NC}\n"
