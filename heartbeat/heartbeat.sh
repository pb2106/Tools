#!/bin/bash
# heartbeat.sh - terminal laptop heartbeat daemon with menu design

# -------- DEPENDENCY CHECK --------
for cmd in aplay bc; do
    if ! command -v $cmd &>/dev/null; then
        echo "Error: $cmd is not installed. Install it and try again."
        exit 1
    fi
done

# -------- CONFIG --------
HEARTBEAT="/home/naegleria/tools/heartbeat/heartbeat.wav"
HEARTBEAT_MID="/home/naegleria/tools/heartbeat/heartbeatmid.wav"
HEARTBEAT_LOUD="/home/naegleria/tools/heartbeat/heartbeatloud.wav"
NOHEARTBEAT="/home/naegleria/tools/heartbeat/noheartbeat.wav"
FLATLINE="/home/naegleria/tools/heartbeat/ecgsound_flatline.wav"
PID_FILE="/tmp/heartbeat.pid"
BEAT_LEN=0.19   # 190 ms heartbeat length

# -------- COLORS --------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# -------- UI --------
print_header() {
    echo -e "${MAGENTA}"
    echo "===================================="
    echo "     💓  LAPTOP HEARTBEAT  💓"
    echo "===================================="
    echo -e "${NC}"
}

show_help() {
    print_header
    echo -e "${CYAN}Usage: heartbeat [start|stop|status|test|help]${NC}\n"
    echo -e "${GREEN}Commands:${NC}"
    echo -e "  ${YELLOW}start${NC}   Start battery-driven heartbeat daemon"
    echo -e "  ${YELLOW}stop${NC}    Stop heartbeat daemon"
    echo -e "  ${YELLOW}status${NC}  Show daemon status"
    echo -e "  ${YELLOW}test${NC}    Play 3s demo of all heartbeat states"
    echo -e "  ${YELLOW}help${NC}    Show this menu\n"
}

# -------- HEARTBEAT LOOP --------
start_heartbeat() {
    print_header
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${RED}Heartbeat already running.${NC}"
        return
    fi

    (
        while true; do
            LEVEL=$(cat /sys/class/power_supply/BAT0/capacity)
            STATUS=$(cat /sys/class/power_supply/BAT0/status)

            if [ "$STATUS" = "Charging" ]; then
                BPM=55
                INTERVAL=$(echo "scale=3; 60/$BPM" | bc)
                SOUND="$HEARTBEAT"

            elif [ "$LEVEL" -ge 71 ]; then
                # CALM → slower
                BPM=$((RANDOM % 11 + 50))   # BPM
                INTERVAL=$(echo "scale=3; 60/$BPM" | bc)
                SOUND="$HEARTBEAT"

            elif [ "$LEVEL" -ge 21 ]; then
                # NORMAL → shifted to anxious
                BPM=$((RANDOM % 21 + 70))   # BPM
                INTERVAL=$(echo "scale=3; 60/$BPM" | bc)
                SOUND="$HEARTBEAT_MID"

            elif [ "$LEVEL" -ge 6 ]; then
                # ANXIOUS
                BPM=$((RANDOM % 31 + 100))  # BPM
                INTERVAL=$(echo "scale=3; 60/$BPM" | bc)
                SOUND="$HEARTBEAT_LOUD"

            else
                # CRITICAL - same speed as anxious, loudest
                BPM=$((RANDOM % 31 + 100))  # BPM
                INTERVAL=$(echo "scale=3; 60/$BPM" | bc)
                SOUND="$NOHEARTBEAT"
            fi

            aplay "$SOUND" &>/dev/null &
            SLEEP_TIME=$(echo "$INTERVAL - $BEAT_LEN" | bc)
            (( $(echo "$SLEEP_TIME < 0" | bc -l) )) && SLEEP_TIME=0
            sleep "$SLEEP_TIME"
        done
    ) &

    echo $! > "$PID_FILE"
    echo -e "${GREEN}Heartbeat started (PID $(cat $PID_FILE))${NC}"
}

# -------- TEST MODE --------
test_heartbeat() {
    print_header
    echo -e "${CYAN}Running heartbeat self-test…${NC}\n"

    play_state() {
        local NAME=$1
        local BPM=$2
        local SOUND_FILE=$3
        local INTERVAL=$(echo "scale=3; 60/$BPM" | bc)
        local END=$((SECONDS + 3))

        echo -e "${YELLOW}▶ $NAME ($BPM BPM)${NC}"
        while [ $SECONDS -lt $END ]; do
            aplay "$SOUND_FILE" &>/dev/null &
            SLEEP_TIME=$(echo "$INTERVAL - $BEAT_LEN" | bc)
            (( $(echo "$SLEEP_TIME < 0" | bc -l) )) && SLEEP_TIME=0
            sleep "$SLEEP_TIME"
        done
        echo
    }

    play_state "CALM" 55 "$HEARTBEAT"
    play_state "NORMAL" 80 "$HEARTBEAT_MID"
    play_state "ANXIOUS" 110 "$HEARTBEAT_LOUD"

    echo -e "${RED}▶ CRITICAL (loudest)${NC}"
    local BPM=110
    local INTERVAL=$(echo "scale=3; 60/$BPM" | bc)
    local END=$((SECONDS + 3))
    while [ $SECONDS -lt $END ]; do
        aplay "$NOHEARTBEAT" &>/dev/null &
        SLEEP_TIME=$(echo "$INTERVAL - $BEAT_LEN" | bc)
        (( $(echo "$SLEEP_TIME < 0" | bc -l) )) && SLEEP_TIME=0
        sleep "$SLEEP_TIME"
    done
    echo
    echo -e "\n${GREEN}Self-test complete.${NC}"
}

# -------- STOP / STATUS --------
stop_heartbeat() {
    print_header
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        kill "$(cat "$PID_FILE")"
        rm -f "$PID_FILE"
        echo -e "${RED}Heartbeat stopped.${NC}"
    else
        echo -e "${YELLOW}No heartbeat running.${NC}"
    fi
}

status_heartbeat() {
    print_header
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${GREEN}Heartbeat running (PID $(cat $PID_FILE))${NC}"
    else
        echo -e "${YELLOW}Heartbeat not running.${NC}"
    fi
}

# -------- MAIN --------
case "$1" in
    start) start_heartbeat ;;
    stop) stop_heartbeat ;;
    status) status_heartbeat ;;
    test) test_heartbeat ;;
    help|--help|-h) show_help ;;
    *) echo -e "${RED}Unknown command. Use 'heartbeat help'.${NC}" ;;
esac
