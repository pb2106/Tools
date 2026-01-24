#!/bin/bash
# heartbeat.sh - terminal laptop heartbeat daemon

HEARTBEAT="$HOME/heartbeat.wav"      # path to your 190ms heartbeat
FLATLINE="$HOME/ecg_flatline.wav"    # ECG flatline
PID_FILE="/tmp/heartbeat.pid"

# Display help
function show_help() {
    echo "Usage: ./heartbeat.sh [start|stop|status|help]"
    echo
    echo "Commands:"
    echo "  start   Start the heartbeat daemon"
    echo "  stop    Stop the heartbeat daemon"
    echo "  status  Show if heartbeat is running"
    echo "  help    Show this help"
    exit 0
}

# Start heartbeat loop
function start_heartbeat() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "Heartbeat already running!"
        return
    fi

    (
        while true; do
            LEVEL=$(cat /sys/class/power_supply/BAT0/capacity)
            STATUS=$(cat /sys/class/power_supply/BAT0/status)

            # Determine BPM
            if [ "$STATUS" == "Charging" ]; then
                INTERVAL=0.857  # 70 BPM
            elif [ "$LEVEL" -ge 71 ]; then
                BPM=$(( RANDOM % 16 + 60 ))  # 60–75
                INTERVAL=$(echo "scale=3; 60 / $BPM" | bc)
            elif [ "$LEVEL" -ge 21 ]; then
                BPM=$(( RANDOM % 21 + 80 ))  # 80–100
                INTERVAL=$(echo "scale=3; 60 / $BPM" | bc)
            elif [ "$LEVEL" -ge 6 ]; then
                BPM=$(( RANDOM % 31 + 110 )) # 110–140
                INTERVAL=$(echo "scale=3; 60 / $BPM" | bc)
            else
                aplay "$FLATLINE"
                break
            fi

            # Play heartbeat asynchronously
            aplay "$HEARTBEAT" &

            # Sleep for interval minus heartbeat duration (0.19s)
            SLEEP_TIME=$(echo "$INTERVAL - 0.19" | bc)
            (( $(echo "$SLEEP_TIME < 0" | bc -l) )) && SLEEP_TIME=0
            sleep $SLEEP_TIME
        done
    ) &
    echo $! > "$PID_FILE"
    echo "Heartbeat started (PID $(cat $PID_FILE))"
}

# Stop heartbeat
function stop_heartbeat() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            kill $PID
            echo "Heartbeat stopped."
        else
            echo "No heartbeat running."
        fi
        rm -f "$PID_FILE"
    else
        echo "No heartbeat running."
    fi
}

# Show status
function status_heartbeat() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "Heartbeat is running (PID $(cat $PID_FILE))"
    else
        echo "Heartbeat is not running."
    fi
}

# Main command parsing
case "$1" in
    start) start_heartbeat ;;
    stop) stop_heartbeat ;;
    status) status_heartbeat ;;
    help|--help|-h) show_help ;;
    *) echo "Unknown command. Use ./heartbeat.sh help"; exit 1 ;;
esac
