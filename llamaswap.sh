#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
CONFIG="$BASE_DIR/configs/llama-swap-config.yaml"
LLAMA_SWAP="/opt/homebrew/bin/llama-swap"
PID_FILE="/tmp/llamaswap.pid"

usage() {
    echo "Usage: $0 {start|stop|restart|status}"
    echo ""
    echo "  start    - Start llama-swap server"
    echo "  stop     - Stop llama-swap server"
    echo "  restart  - Restart llama-swap server"
    echo "  status   - Show llama-swap status"
    exit 1
}

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "llama-swap is already running (PID $(cat "$PID_FILE"))"
        exit 1
    fi

    echo "Starting llama-swap..."
    nohup "$LLAMA_SWAP" \
        --config "$CONFIG" \
        --listen 0.0.0.0:1235 \
        > /tmp/llamaswap.log \
        2> /tmp/llamaswap.error.log \
        < /dev/null &
    echo $! > "$PID_FILE"
    echo "llama-swap started (PID $!)"
}

stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "llama-swap is not running (no PID file)"
        exit 0
    fi

    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping llama-swap (PID $PID)..."
        kill "$PID"
        rm -f "$PID_FILE"
        echo "llama-swap stopped."
    else
        echo "llama-swap is not running (stale PID file)"
        rm -f "$PID_FILE"
    fi
}

restart() {
    stop
    sleep 1
    start
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "llama-swap is running (PID $(cat "$PID_FILE"))"
    else
        echo "llama-swap is not running"
        rm -f "$PID_FILE"
    fi
}

case "${1:-}" in
    start)   start   ;;
    stop)    stop    ;;
    restart) restart ;;
    status)  status  ;;
    *)       usage   ;;
esac
