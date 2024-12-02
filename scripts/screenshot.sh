#!/usr/bin/env bash

# Set directories for screenshots and recordings
dir_img="$(xdg-user-dir PICTURES)"
dir="$(xdg-user-dir VIDEOS)"
[ -d "$dir_img" ] || mkdir -p "$dir_img"
[ -d "$dir" ] || mkdir -p "$dir"

# Temporary files to store timestamp and format type
timestamp_file="/tmp/screenshot_timestamp"
formattype_file="/tmp/recording_format"
filename_img="$dir_img/$(date +%Y_%m_%d_%H%M%S).png"

# Convert video to GIF using ffmpeg with palette for quality and smaller size
video_to_gif() {
    local video_file="$1"
    local gif_file="${video_file%.*}.gif"
    if [[ -f "$video_file" ]]; then
        ffmpeg -i "$video_file" -vf palettegen -f image2 -c:v png - |
            ffmpeg -i "$video_file" -i - -filter_complex paletteuse "$gif_file"
    fi
}

# Show notification for screenshot status
show_notification() {
    if [[ -e "$filename_img" ]]; then
        notify-send --replace-id=699 -i "$filename_img" "Screenshot" "Screenshot saved and copied to clipboard"
    else
        notify-send --replace-id=699 -i trash-bin "Screenshot" "Screenshot Canceled"
    fi
}

# Capture a screenshot
take_screenshot() {
    if [ "$WAYLAND_DISPLAY" ]; then
        grim "$@" "$filename_img" # Wayland
        wl-copy <"$filename_img"
    else
        maim -u "$@" "$filename_img" # X11
        xclip -selection clipboard -t image/png -i "$filename_img"
    fi
    show_notification
}

# Start a screen recording
start_screen_recording() {
    local start_timestamp=$(date +%Y_%m_%d_%H%M%S)
    echo "$start_timestamp" >"$timestamp_file"
    filename="$dir/${start_timestamp}.mkv"

    notify-send --replace-id=699 -t 1000 "Recording Started" "Screen recording started"
    sleep 1
    if [ "$WAYLAND_DISPLAY" ]; then
        wf-recorder -f "$filename" &
    else
        ffmpeg -video_size "$(xdpyinfo | grep dimensions | awk '{print $2}')" -framerate 25 -f x11grab -i "$DISPLAY" "$filename" &
    fi
}

# Start a region-specific recording
start_region_recording() {
    local start_timestamp=$(date +%Y_%m_%d_%H%M%S)
    echo "$start_timestamp" >"$timestamp_file"
    filename="$dir/${start_timestamp}.mkv"

    notify-send --replace-id=699 -t 1000 "Recording will start" "Please select area"
    sleep 1
    if [ "$WAYLAND_DISPLAY" ]; then
        wf-recorder -g "$(slurp)" -f "$filename" &
    else
        ffmpeg -f x11grab -framerate 25 -i "$DISPLAY" -vf "crop=$(slop -f '%w:%h:%x:%y')" "$filename" &
    fi
}

# Stop recording and optionally convert to GIF
stop_recording() {
    if [ "$WAYLAND_DISPLAY" ]; then
        pkill -SIGINT wf-recorder && wait $!
    else
        pkill -SIGINT ffmpeg && wait $!
    fi

    sleep 1
    format_type=$(cat "$formattype_file" 2>/dev/null || echo "")

    # Check if GIF conversion is requested
    if [[ "$format_type" == "gif" ]]; then
        if [[ -f "$timestamp_file" ]]; then
            start_timestamp=$(cat "$timestamp_file")
            filename="$dir/${start_timestamp}.mkv"
            rm "$timestamp_file" "$formattype_file" 2>/dev/null

            notify-send --replace-id=699 -i video-x-generic "Converting to GIF" "Starting GIF conversion"
            video_to_gif "$filename"
            notify-send --replace-id=699 -i video-x-generic "Converted to GIF" "GIF saved as $start_timestamp.gif"
        else
            notify-send --replace-id=699 -i error "Error" "Timestamp file not found. Conversion skipped."
        fi
    else
        notify-send --replace-id=699 -i video-x-generic "Recording Stopped" "Recording saved in Videos"
    fi
}

# Countdown for delayed screenshot
countdown() {
    for sec in $(seq "$1" -1 1); do
        notify-send -t 1000 --replace-id=699 -i gtkam-camera "Starting in: $sec"
        sleep 1
    done
    sleep 1
}

# Main case structure to handle different options
case $1 in
--now)
    take_screenshot
    ;;
--in)
    countdown "$2" && take_screenshot
    ;;
--sel)
    if [ "$WAYLAND_DISPLAY" ]; then
        take_screenshot -g "$(slurp)"
    else
        take_screenshot -s -o
    fi
    ;;
--active)
    if [ "$WAYLAND_DISPLAY" ]; then
        take_screenshot -g "$(swaymsg -t get_tree | jq '.. | select(.focused? == true).rect | "\(.x),\(.y) \(.width)x\(.height)"' | sed 's/\"//g')"
    else
        take_screenshot -i "$(xdotool getactivewindow)"
    fi
    ;;
--record)
    start_screen_recording
    ;;
--record-gif) # Very costly for full screen
    echo "gif" >"$formattype_file"
    start_screen_recording
    ;;
--record-sel)
    start_region_recording
    ;;
--record-sel-gif)
    echo "gif" >"$formattype_file"
    start_region_recording
    ;;
--stop)
    stop_recording
    ;;
*)
    take_screenshot
    ;;
esac
