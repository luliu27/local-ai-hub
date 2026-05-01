#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
CONFIG="$BASE_DIR/configs/llama-swap-config.yaml"
LLAMA_SWAP="/opt/homebrew/bin/llama-swap"
PID_FILE="$BASE_DIR/.llamaswap.pid"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/llamaswap.log"
ERROR_LOG_FILE="$LOG_DIR/llamaswap.error.log"
MAX_LOG_SIZE=10485760  # 10MB
STOP_TIMEOUT=10        # seconds to wait before SIGKILL

usage() {
    echo "Usage: $0 {start|stop|restart|status|logs}"
    echo ""
    echo "  start    - Start llama-swap server"
    echo "  stop     - Stop llama-swap server"
    echo "  restart  - Restart llama-swap server"
    echo "  status   - Show llama-swap status"
    echo "  logs     - Tail the log file"
    exit 1
}

# Rotate log if it exceeds MAX_LOG_SIZE
rotate_log() {
    local logfile="$1"
    if [ -f "$logfile" ] && [ "$(stat -f%z "$logfile" 2>/dev/null || echo 0)" -gt "$MAX_LOG_SIZE" ]; then
        mv "$logfile" "${logfile}.1"
        # Remove old rotated log
        rm -f "${logfile}.2"
    fi
}

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "llama-swap is already running (PID $(cat "$PID_FILE"))"
        exit 0
    fi

    # Clean up stale PID file
    rm -f "$PID_FILE"

    # Ensure log directory exists and rotate if needed
    mkdir -p "$LOG_DIR"
    rotate_log "$LOG_FILE"
    rotate_log "$ERROR_LOG_FILE"

    # Check dependencies
    if ! command -v "$LLAMA_SWAP" &>/dev/null; then
        echo "Error: llama-swap binary not found at $LLAMA_SWAP"
        exit 1
    fi

    if [ ! -f "$CONFIG" ]; then
        echo "Error: config file not found at $CONFIG"
        exit 1
    fi

    echo "Starting llama-swap..."
    nohup "$LLAMA_SWAP" \
        --config "$CONFIG" \
        --listen 0.0.0.0:1235 \
        >> "$LOG_FILE" \
        2>> "$ERROR_LOG_FILE" \
        < /dev/null &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    # Health check: wait up to 5 seconds for the process to stabilize
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        echo "llama-swap started successfully (PID $pid)"
        echo "Logs: $LOG_FILE"
        echo "Errors: $ERROR_LOG_FILE"
    else
        echo "Error: llama-swap failed to start. Check $ERROR_LOG_FILE for details."
        rm -f "$PID_FILE"
        exit 1
    fi
}

stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "llama-swap is not running (no PID file)"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "llama-swap is not running (stale PID file)"
        rm -f "$PID_FILE"
        return 0
    fi

    echo "Stopping llama-swap (PID $pid)..."
    kill "$pid" 2>/dev/null || true

    # Wait for graceful shutdown with timeout
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null && [ "$elapsed" -lt "$STOP_TIMEOUT" ]; do
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        echo "Force killing llama-swap (PID $pid)..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi

    rm -f "$PID_FILE"
    echo "llama-swap stopped."
}

restart() {
    stop || true
    sleep 1
    start
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid
        pid=$(cat "$PID_FILE")
        local uptime
        uptime=$(ps -o elapsed= -p "$pid" 2>/dev/null || echo "unknown")
        echo "llama-swap is running (PID $pid, uptime: $uptime)"
        echo "Config: $CONFIG"
        echo "Logs:   $LOG_FILE"
        echo "Errors: $ERROR_LOG_FILE"
    else
        echo "llama-swap is not running"
        rm -f "$PID_FILE"
    fi
}

logs() {
    if [ ! -f "$LOG_FILE" ] && [ ! -f "$ERROR_LOG_FILE" ]; then
        echo "No log files found. Start llama-swap first."
        return 1
    fi
    tail -f "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null
}

case "${1:-}" in
    start)   start   ;;
    stop)    stop    ;;
    restart) restart ;;
    status)  status  ;;
    logs)    logs    ;;
    *)       usage   ;;
esac
