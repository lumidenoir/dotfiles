#!/usr/bin/env bash
# Minimo Brain Suite - Daemon Launcher
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🧠 Starting Minimo Brain Suite on 0.0.0.0:8088..."
exec python3 server.py
