#!/usr/bin/env bash
# Minimo Neural Text-to-Speech Engine (Piper TTS + PulseAudio/PipeWire)
# Fast, 100% offline local neural voice synthesis with zero GPU overhead.

VOICE_DIR="/usr/share/piper-voices/en/en_US"
DEFAULT_VOICE="$VOICE_DIR/ryan/high/en_US-ryan-high.onnx"
FALLBACK_VOICE="$VOICE_DIR/lessac/medium/en_US-lessac-medium.onnx"
OUTPUT_WAV="/tmp/minimo_speech.wav"
LOCK_PID="/tmp/minimo_tts.pid"

# Stop ongoing speech
stop_speech() {
    if [ -f "$LOCK_PID" ]; then
        PID=$(cat "$LOCK_PID" 2>/dev/null)
        if [ -n "$PID" ]; then
            kill -9 "$PID" 2>/dev/null
        fi
        rm -f "$LOCK_PID"
    fi
    pkill -u "$USER" -x paplay 2>/dev/null
}

if [ "$1" == "--stop" ]; then
    stop_speech
    exit 0
fi

if [ "$1" == "--list-voices" ]; then
    echo "Available Piper Neural Voices:"
    find "$VOICE_DIR" -name "*.onnx" -exec basename {} .onnx \; | sort
    exit 0
fi

# Pick model
VOICE_MODEL="$DEFAULT_VOICE"
if [ ! -f "$VOICE_MODEL" ]; then
    VOICE_MODEL="$FALLBACK_VOICE"
fi

TEXT=""
if [ "$1" == "--speak" ]; then
    shift
    TEXT="$*"
else
    TEXT="$*"
fi

if [ -z "$TEXT" ]; then
    # Read from stdin
    TEXT=$(cat)
fi

# Strip markdown formatting, code blocks, URLs, and asterisks for clean speech
CLEAN_TEXT=$(echo "$TEXT" | sed -E \
    -e 's/```[^`]*```//g' \
    -e 's/`[^`]*`//g' \
    -e 's/https?:\/\/[^ ]+//g' \
    -e 's/[#*_~>]//g' \
    -e 's/\[([^]]+)\]\([^)]+\)/\1/g' \
    -e 's/^[ \t]*-[ \t]+//g' \
    -e 's/\n+/ /g' \
    | tr -s ' ' | head -c 1200)

if [ -z "$CLEAN_TEXT" ]; then
    exit 0
fi

# Stop any previous speech
stop_speech

# Synthesize audio with piper-tts
echo "$CLEAN_TEXT" | piper-tts --model "$VOICE_MODEL" --output_file "$OUTPUT_WAV" >/dev/null 2>&1

if [ -f "$OUTPUT_WAV" ]; then
    paplay "$OUTPUT_WAV" &
    echo $! > "$LOCK_PID"
fi
