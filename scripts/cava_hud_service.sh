#!/usr/bin/env bash
FIFO_PATH="/tmp/cava.fifo"

# Recreate clean FIFO
[ -p "$FIFO_PATH" ] || mkfifo "$FIFO_PATH"

# Kill any existing stale instances
pkill -f "cava -p.*quickshell_config" 2>/dev/null

# Launch headless background instance
exec cava -p "$HOME/.config/cava/quickshell_config" > /dev/null 2>&1
