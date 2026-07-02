#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# screenshot.sh — Screenshot & screen recording utility
# Supports Wayland (grim/wf-recorder/slurp) and X11 (maim/ffmpeg/slop)
# =============================================================================

# === Configuration ===
dir_img="$(xdg-user-dir PICTURES)/screenshots"
dir_vid="$(xdg-user-dir VIDEOS)/recordings"
mkdir -p "$dir_img" "$dir_vid" "/tmp/ocr"

timestamp_file="/tmp/screenshot_timestamp"
record_pid_file="/tmp/screenshot_record.pid"
notify_replace_id=699
default_countdown=3

# =============================================================================
# === Dependencies ===
# =============================================================================

need() {
    command -v "$1" &>/dev/null || {
        echo >&2 "$1 missing - please install"
        notify-send "Missing dependency" "$1 required"
        exit 1
    }
}

need notify-send
need dunstify
need ffmpeg
need rofi

# =============================================================================
# === Helpers ===
# =============================================================================

make_timestamp() { date +%Y_%m_%d_%H%M%S; }
make_img_name()  { echo "$dir_img/$(make_timestamp).png"; }

safe_slurp() {
    echo "safe_slurp started. Args: $@" >> /tmp/safe_slurp.log
    local paused=false
    if command -v dunstctl &>/dev/null; then
        dunstctl set-paused true || true
        paused=true
    fi

    # --- Apply Screen Shader if in Hyprland ---
    local shader_applied=false
    local shader_path="$HOME/dotfiles/misc/screenshot_shader.glsl"
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && [[ -f "$shader_path" ]]; then
        hyprctl eval "hl.config({ decoration = { screen_shader = '$shader_path' } })" &>/dev/null || true
        shader_applied=true
    fi

    local geom
    set +e
    echo "running slurp" >> /tmp/safe_slurp.log
    geom=$(slurp -d -b 00000050 -c ffffffdd -s 00000000 -w 2 -F "Geist" "$@")
    local status=$?
    echo "slurp finished with status $status, geom='$geom'" >> /tmp/safe_slurp.log
    set -e

    # --- Restore Screen Shader ---
    if [[ "$shader_applied" == "true" ]]; then
        hyprctl eval "hl.config({ decoration = { screen_shader = '' } })" &>/dev/null || true
    fi

    if [[ "$paused" == "true" ]]; then
        dunstctl set-paused false || true
    fi

    if [[ $status -ne 0 || -z "$geom" ]]; then
        return 1
    fi

    echo "$geom"
    return 0
}

play_sound() {
    command -v canberra-gtk-play >/dev/null \
        && canberra-gtk-play -i "$1" &>/dev/null &
}

copy_to_clipboard() {
    local file="$1"
    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        command -v wl-copy >/dev/null && wl-copy < "$file"
    else
        command -v xclip >/dev/null \
            && xclip -selection clipboard -t image/png -i "$file"
    fi
}

show_notification() {
    local file="${1:-}"
    if [[ -n "$file" && -e "$file" ]]; then
        notify-send --replace-id="$notify_replace_id" \
            -i "$file" "Screenshot" "Saved & copied to clipboard"
    else
        notify-send --replace-id="$notify_replace_id" \
            -i "image-missing" "Screenshot" "Cancelled"
    fi
}

countdown() {
    local secs="${1:-$default_countdown}"
    for sec in $(seq "$secs" -1 1); do
        play_sound "bell"
        #notify-send -t 300 --replace-id="$notify_replace_id" "Starting in: $sec"
        sleep 1
    done
}

# =============================================================================
# === GIF conversion ===
# =============================================================================

video_to_gif() {
    local input="$1"
    local output="${input%.*}.gif"
    local palette
    palette="$(mktemp --suffix=.png)"
    trap 'rm -f "$palette"' RETURN

    ffmpeg -y -i "$input" \
        -vf "fps=12,scale=800:-1:flags=lanczos,palettegen" "$palette"
    ffmpeg -y -i "$input" -i "$palette" \
        -lavfi "fps=12,scale=800:-1:flags=lanczos,paletteuse" "$output"

    notify-send --replace-id="$notify_replace_id" \
        "GIF Saved" "${output##*/}"
}

# =============================================================================
# === Post-recording conversion (runs in background, non-blocking) ===
# =============================================================================

post_convert() {
    local input="$1"
    local choice
    choice=$(printf "%s\n%s\n%s" "Keep MKV" "Convert to MP4" "Convert to GIF" \
        | rofi -dmenu -p "After recording")

    case "$choice" in
        "Convert to MP4")
            notify-send --replace-id="$notify_replace_id" \
                "Converting" "MP4 in progress..."
            ffmpeg -y -i "$input" \
                -c:v libx264 -preset slow -crf 20 \
                -c:a aac "${input%.mkv}.mp4"
            notify-send --replace-id="$notify_replace_id" \
                "Saved MP4" "$(basename "${input%.mkv}.mp4")"
            ;;
        "Convert to GIF")
            notify-send --replace-id="$notify_replace_id" \
                "Converting" "GIF in progress..."
            video_to_gif "$input"
            ;;
        *)
            notify-send --replace-id="$notify_replace_id" \
                "Kept MKV" "$(basename "$input")"
            ;;
    esac
}

# =============================================================================
# === Screenshot ===
# =============================================================================
take_screenshot() {
    local img
    img="$(make_img_name)"

    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        need grim
        grim "$@" "$img"
    else
        need maim
        maim -u "$@" "$img"
    fi

    copy_to_clipboard "$img"
    play_sound "camera-shutter"
    show_notification "$img"
}

take_screenshot_edit() {
    local raw_img="/tmp/raw_screenshot_$(date +%s).png"
    local final_img
    final_img="$(make_img_name)"

    mkdir -p "$(dirname "$raw_img")" "$(dirname "$final_img")"

    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        need grim
        grim "$@" "$raw_img"
    else
        need maim
        maim -u "$@" "$raw_img"
    fi

    if command -v satty &>/dev/null; then
        satty --filename "$raw_img" --output-filename "$final_img" --early-exit
        
        if [[ -f "$final_img" ]]; then
            copy_to_clipboard "$final_img"
            play_sound "camera-shutter"
            show_notification "$final_img"
        else
            show_notification ""
        fi
    else
        mv "$raw_img" "$final_img"
        copy_to_clipboard "$final_img"
        play_sound "camera-shutter"
        show_notification "$final_img"
    fi

    rm -f "$raw_img"
}


take_screenshot_ocr() {
    local tmp_img="/tmp/ocr/ocr_snap.png"

    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        need grim
        local geom
        if ! geom=$(safe_slurp); then
            show_notification ""
            exit 0
        fi
        grim -g "$geom" "$tmp_img"   # interactive region select
    else
        need maim
        maim -u -s "$tmp_img"
    fi

    local text
    text=$(python3 ~/dotfiles/scripts/shot-helper.py --ocr "$tmp_img")

    if [[ -z "$text" ]]; then
        notify-send "OCR" "No text found"
        return
    fi

    # Copy to clipboard
    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        echo "$text" | wl-copy
    else
        echo "$text" | xclip -selection clipboard
    fi

    rm -f "$tmp_img"
    notify-send "OCR done" "${text:0:80}..."  # preview first 80 chars
}
# =============================================================================
# === Recording ===
# =============================================================================

start_recording() {
    local mode="${1:-}"
    local ts video

    ts=$(make_timestamp)
    echo "$ts" > "$timestamp_file"
    video="$dir_vid/${ts}.mkv"

    if [[ "$mode" == "sel" ]]; then
        notify-send --replace-id="$notify_replace_id" \
            -t 1500 "Recording Starting..." "Select area"
    else
        notify-send --replace-id="$notify_replace_id" \
            -t 1500 "Recording Starting..." "Get ready"
    fi
    sleep 1.5
    play_sound "service-login"

    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        need wf-recorder
        if [[ "$mode" == "sel" ]]; then
            need slurp
            local sel
            if ! sel=$(safe_slurp); then
                notify-send --replace-id="$notify_replace_id" -i "image-missing" "Recording" "Cancelled"
                exit 0
            fi
            wf-recorder -g "$sel" -f "$video" </dev/null >/dev/null 2>&1 &
            disown
        else
            wf-recorder -f "$video" </dev/null >/dev/null 2>&1 &
            disown
        fi
    else
        need xdpyinfo
        local screen_size
        screen_size="$(xdpyinfo | awk '/dimensions/ {print $2}')"

        if [[ "$mode" == "sel" ]]; then
            need slop
            local sel
            sel="$(slop -f '%w:%h:%x:%y')"
            ffmpeg -y -f x11grab -framerate 25 -i "$DISPLAY" \
                -vf "crop=${sel},scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" \
                -c:v libx264 -preset ultrafast -crf 18 -movflags +faststart \
                "$video" </dev/null >/dev/null 2>&1 &
            disown
        else
            ffmpeg -y -video_size "$screen_size" -framerate 25 \
                -f x11grab -i "$DISPLAY" \
                -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" \
                -c:v libx264 -preset veryfast -crf 18 -movflags +faststart \
                "$video" </dev/null >/dev/null 2>&1 &
            disown
        fi
    fi

    echo "$!" > "$record_pid_file"
    (quickshell -p "$HOME/dotfiles/quickshell" ipc call qsIpc startRecording || quickshell ipc call qsIpc startRecording) &>/dev/null &
}

stop_recording() {
    local pid ts video_path

    pid="$(cat "$record_pid_file" 2>/dev/null || true)"
    if [[ -z "$pid" ]]; then
        notify-send --replace-id="$notify_replace_id" \
            "Error" "No recording PID found"
        exit 1
    fi

    kill -SIGINT "$pid" 2>/dev/null || true

    for _ in {1..4}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.5
    done

    kill -0 "$pid" 2>/dev/null && kill -SIGTERM "$pid" 2>/dev/null || true

    wait "$pid" 2>/dev/null || true

    play_sound "service-logout"

    ts="$(cat "$timestamp_file" 2>/dev/null || true)"
    if [[ -n "$ts" && -f "$dir_vid/${ts}.mkv" ]]; then
        video_path="$dir_vid/${ts}.mkv"
    else
        video_path="$(ls -1t "$dir_vid"/*.mkv 2>/dev/null | head -n1 || true)"
    fi

    if [[ -z "$video_path" ]]; then
        notify-send --replace-id="$notify_replace_id" \
            "Error" "Could not locate recorded file"
        exit 1
    fi

    notify-send --replace-id="$notify_replace_id" \
        "Recording Stopped" "Saved: $(basename "$video_path")"

    rm -f "$record_pid_file" "$timestamp_file" 2>/dev/null || true
    (quickshell -p "$HOME/dotfiles/quickshell" ipc call qsIpc stopRecording || quickshell ipc call qsIpc stopRecording) &>/dev/null &

    # Run post-conversion menu in background so the launcher is not blocked
    post_convert "$video_path" &
}

# =============================================================================
# === Active-window screenshot (Wayland) ===
# =============================================================================

get_active_window_rect() {
    # Hyprland
    if command -v hyprctl &>/dev/null && command -v jq &>/dev/null; then
        local rect
        rect="$(hyprctl -j activewindow 2>/dev/null \
            | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null \
            || true)"
        if [[ -n "$rect" && "$rect" != "null,null nullxnull" ]]; then
            echo "$rect"
            return
        fi
    fi

    echo ""
}

# =============================================================================
# === CLI entry point ===
# =============================================================================

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  --now          Fullscreen screenshot immediately
  --in <secs>    Fullscreen screenshot after countdown
  --sel          Region/window selection screenshot
  --edit         Region selection with annotation
  --edit-screen  Fullscreen selection with annotation
  --active       Screenshot of the active window (countdown: ${default_countdown}s)
  --record       Start fullscreen recording
  --record-sel   Start region recording
  --stop         Stop current recording
EOF
}

case "${1:-}" in
    --now)
        take_screenshot
        ;;

    --in)
        [[ "${2:-}" =~ ^[0-9]+$ ]] || { usage; exit 1; }
        countdown "$2"
        take_screenshot
        ;;

    --sel)
        if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
            need slurp
            if ! geom=$(safe_slurp); then
                show_notification ""
                exit 0
            fi
            take_screenshot -g "$geom"
        else
            need maim
            take_screenshot -s
        fi
        ;;

    --edit)
        if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
            need slurp
            if ! geom=$(safe_slurp); then
                show_notification ""
                exit 0
            fi
            take_screenshot_edit -g "$geom"
        else
            need maim
            take_screenshot_edit -s
        fi
        ;;

    --edit-screen)
        take_screenshot_edit
        ;;

    --active)
        countdown "$default_countdown"
        if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
            rect="$(get_active_window_rect)"
            if [[ -z "$rect" ]]; then
                echo "No active window rectangle detected. Falling back to fullscreen."
                take_screenshot
            else
                take_screenshot -g "$rect"
            fi
        else
            need xdotool
            win="$(xdotool getactivewindow)"
            take_screenshot -i "$win"
        fi
        ;;

    --record)
        start_recording
        ;;

    --record-sel)
        start_recording sel
        ;;

    --stop)
        stop_recording
        ;;
    --ocr)
        take_screenshot_ocr
        ;;
    --help | -h)
        usage
        ;;

    *)
        take_screenshot
        ;;
esac
