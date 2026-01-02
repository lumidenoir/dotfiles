#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
dir_img="$(xdg-user-dir PICTURES)/screenshots"
dir_vid="$(xdg-user-dir VIDEOS)/recordings"
mkdir -p "$dir_img" "$dir_vid"

timestamp_file="/tmp/screenshot_timestamp"
record_pid_file="/tmp/screenshot_record.pid"
notify_replace_id=699
countdown_timeout=4

# === Dependencies ===
need() { command -v "$1" &>/dev/null || {
    echo >&2 "$1 missing - please install"
    notify-send "Missing dependency" "$1 required"
    exit 1
}; }

need notify-send
need dunstify
need ffmpeg
need rofi
need jq || true

# === Helpers ===
make_img_name() { echo "$dir_img/$(date +%Y_%m_%d_%H%M%S).png"; }

play_sound() {
    command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i "$1" &>/dev/null &
}

video_to_gif() {
    local input="$1"
    local output="${input%.*}.gif"
    local palette
    palette="$(mktemp --suffix=.png)"
    ffmpeg -y -i "$input" -vf "fps=12,scale=800:-1:flags=lanczos,palettegen" "$palette"
    ffmpeg -y -i "$input" -i "$palette" -lavfi "fps=12,scale=800:-1:flags=lanczos,paletteuse" "$output"
    rm -f "$palette"
    notify-send --replace-id=$notify_replace_id "GIF Saved" "${output##*/}"
}

show_notification() {
    local file="$1"
    if [[ -n "$file" && -e "$file" ]]; then
        notify-send --replace-id=$notify_replace_id -i "$file" "Screenshot" "Saved & copied to clipboard"
    else
        notify-send --replace-id=$notify_replace_id -i "image-missing" "Screenshot" "Cancelled"
    fi
}

# === Screenshot ===
take_screenshot() {
    local img
    img="$(make_img_name)"

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        need grim
        grim "$@" "$img"
        command -v wl-copy >/dev/null && wl-copy <"$img"
    else
        need maim
        maim -u "$@" "$img"
        command -v xclip >/dev/null && xclip -selection clipboard -t image/png -i "$img"
    fi

    play_sound "camera-shutter"

    show_notification "$img"
}

# === Recording ===
start_recording() {
    local ts video pid
    ts=$(date +%Y_%m_%d_%H%M%S)
    echo "$ts" >"$timestamp_file"

    video="$dir_vid/${ts}.mkv"

    notify-send --replace-id=$notify_replace_id -t 1500 "Recording Starting..." "Get ready"
    sleep 1.5

    play_sound "service-login"

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        need wf-recorder
        wf-recorder -f "$video" &
    else
        need xdpyinfo
        screen_size="$(xdpyinfo | awk '/dimensions/ {print $2}')"
        ffmpeg -y -video_size "$screen_size" -framerate 25 -f x11grab -i "$DISPLAY" \
            -c:v libx264 -preset ultrafast -crf 18 "$video" &
    fi

    pid=$!
    echo "$pid" >"$record_pid_file"
}

start_region_recording() {
    local ts video sel pid screen_size
    ts=$(date +%Y_%m_%d_%H%M%S)
    echo "$ts" >"$timestamp_file"

    video="$dir_vid/${ts}.mkv"

    notify-send --replace-id=$notify_replace_id -t 1500 "Recording Starting..." "Select area"
    sleep 1.5

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        need slurp
        need wf-recorder
        sel="$(slurp)"
        play_sound "service-login"
        wf-recorder -g "$sel" -f "$video" &
    else
        need slop
        need xdpyinfo
        sel="$(slop -f '%w:%h:%x:%y')"
        play_sound "service-login"
        ffmpeg -y -f x11grab -framerate 25 -i "$DISPLAY" -vf "crop=$sel" \
            -c:v libx264 -preset ultrafast -crf 18 "$video" &
    fi

    pid=$!
    echo "$pid" >"$record_pid_file"
}

stop_recording() {
    local pid ts video_path
    pid="$(cat "$record_pid_file" 2>/dev/null || true)"
    [[ -z "$pid" ]] && notify-send --replace-id=$notify_replace_id "Error" "No recording PID found" && exit 1

    kill -SIGINT "$pid" 2>/dev/null || true

    for i in {1..4}; do
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        sleep 0.5
    done

    kill -0 "$pid" 2>/dev/null && kill -SIGTERM "$pid" 2>/dev/null || true

    wait "$pid" 2>/dev/null || true

    play_sound "service-logout"

    ts="$(cat "$timestamp_file" 2>/dev/null || true)"
    if [[ -f "$dir_vid/${ts}.mkv" ]]; then
        video_path="$dir_vid/${ts}.mkv"
    else
        video_path="$(ls -1t "$dir_vid"/*.mkv 2>/dev/null | head -n1 || true)"
    fi

    notify-send --replace-id=$notify_replace_id "Recording Stopped" "Saved: $(basename "$video_path")"

    post_convert "$video_path"

    rm -f "$record_pid_file" "$timestamp_file" 2>/dev/null || true
}

# === Post-conversion ===
post_convert() {
    local input="$1"
    local choice
    choice=$(printf "%s\n%s\n%s" "Keep MKV" "Convert to MP4" "Convert to GIF" | rofi -dmenu -p "After recording")

    case "$choice" in
    "Convert to MP4")
        {
            notify-send --replace-id=$notify_replace_id "Converting" "MP4 in progress..."
            ffmpeg -y -i "$input" -c:v libx264 -preset slow -crf 20 -c:a aac "${input%.mkv}.mp4"
            notify-send --replace-id=$notify_replace_id "Saved MP4" "${input%.mkv}.mp4"
        } &
        ;;
    "Convert to GIF")
        {
            notify-send --replace-id=$notify_replace_id "Converting" "GIF in progress..."
            video_to_gif "$input"
        } &
        ;;
    *)
        notify-send --replace-id=$notify_replace_id "Kept MKV" "$(basename "$input")"
        ;;
    esac
}

# === Countdown ===
countdown() {
    for sec in $(seq "$1" -1 1); do
        play_sound "bell"
        notify-send -t 800 --replace-id=$notify_replace_id "Starting in: $sec"
        sleep 1
    done
}

# === CLI ===
case "${1:-}" in
--now)
    take_screenshot
    ;;
--in)
    [[ "${2:-}" =~ ^[0-9]+$ ]] || exit 1
    countdown "$2"
    take_screenshot
    ;;
--sel)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        need slurp
        take_screenshot -g "$(slurp)"
    else
        take_screenshot -s -o
    fi
    ;;
-active)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        rect=""

        # --- Hyprland ---
        if [[ -z "$rect" && $(command -v hyprctl) ]]; then
            rect=$(hyprctl -j activewindow 2>/dev/null | jq -r \
                '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' || echo "")
        fi

        # --- Fallback to fullscreen if rect is empty ---
        if [[ -z "$rect" || "$rect" == "null,null nullxnull" ]]; then
            echo "No active window rectangle detected. Fullscreen fallback."
            take_screenshot
        else
            take_screenshot -g "$rect"
        fi
    else
        need xdotool
        win=$(xdotool getactivewindow)
        take_screenshot -i "$win"
    fi
    ;;
--record)
    start_recording
    ;;
--record-sel)
    start_region_recording
    ;;
--stop)
    stop_recording
    ;;
*)
    take_screenshot
    ;;
esac
