#!/usr/bin/env sh

# github https://github.com/Shringe/dunst-media-control

# Configuration variables
readonly VOLUME_STEP=5
readonly BRIGHTNESS_STEP=5
readonly MAX_VOLUME=100
readonly NOTIFICATION_TIMEOUT=1500
readonly DOWNLOAD_ALBUM_ART=false
readonly SHOW_ALBUM_ART=true

# Icons
ICON_PATH="/home/krishna/dotfiles/svgs"
readonly VOLUME_MUTE_ICON="volume-xmark.svg"
readonly VOLUME_LOW_ICON="volume-low.svg"
readonly VOLUME_HIGH_ICON="volume-high.svg"
readonly MIC_MUTE_ICON="microphone-slash.svg"
readonly MIC_UNMUTE_ICON="microphone.svg"
readonly BRIGHTNESS_LOW_ICON="moon.svg"
readonly BRIGHTNESS_MED_ICON="circle-half-stroke.svg"
readonly BRIGHTNESS_HIGH_ICON="sun.svg"

get_volume() {
    pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
}

get_mute_status() {
    pactl get-sink-mute @DEFAULT_SINK@ | grep -Po '(?<=Mute: )(yes|no)'
}

get_volume_icon() {
    local -r volume=$1
    local -r mute_status=$2

    if [[ "$mute_status" == "yes" || "$volume" -eq 0 ]]; then
        echo "$ICON_PATH/$VOLUME_MUTE_ICON"
    elif (( volume < 50 )); then
        echo "$ICON_PATH/$VOLUME_LOW_ICON"
    else
        echo "$ICON_PATH/$VOLUME_HIGH_ICON"
    fi
}

show_volume_notification() {
    local -r volume=$(get_volume)
    local -r mute_status=$(get_mute_status)
    local -r volume_icon=$(get_volume_icon "$volume" "$mute_status")

    local body_text progress_value
    if [[ "$mute_status" == "yes" || "$volume" -eq 0 ]]; then
        body_text="Muted"
        progress_value=0
    else
        body_text="$volume%"
        progress_value=$volume
    fi

    notify-send -i $volume_icon -h int:value:"$progress_value" -t "$NOTIFICATION_TIMEOUT" \
        "Settings Control" "Volume: $body_text"
}

get_mic_mute_status() {
    pactl get-source-mute @DEFAULT_SOURCE@ | grep -Po '(?<=Mute: )(yes|no)'
}

get_mic_icon() {
    local -r mute_status=$1
    if [[ "$mute_status" == "yes" ]]; then
        echo "$ICON_PATH/$MIC_MUTE_ICON"
    else
        echo "$ICON_PATH/$MIC_UNMUTE_ICON"
    fi
}

show_mic_notification() {
    local -r mute_status=$(get_mic_mute_status)
    local -r mic_icon=$(get_mic_icon "$mute_status")
    local status_text

    if [[ "$mute_status" == "yes" ]]; then
        status_text="Muted"
    else
        status_text="Unmuted"
    fi

    notify-send -i $mic_icon -t "$NOTIFICATION_TIMEOUT" "Settings Control" "Mic: $status_text"
}

get_brightness() {
    local current max
    current=$(brightnessctl g)
    max=$(brightnessctl m)
    echo $((current * 100 / max))
}

get_brightness_icon() {
    local -r brightness=$1
    if ((brightness < 33)); then
        echo "$ICON_PATH/$BRIGHTNESS_LOW_ICON"
    elif ((brightness < 66)); then
        echo "$ICON_PATH/$BRIGHTNESS_MED_ICON"
    else
        echo "$ICON_PATH/$BRIGHTNESS_HIGH_ICON"
    fi
}

show_brightness_notification() {
    local -r brightness=$(get_brightness)
    local -r brightness_icon=$(get_brightness_icon "$brightness")

    notify-send -i $brightness_icon -h int:value:"$brightness" -t "$NOTIFICATION_TIMEOUT" \
        "Settings Control" "Brightness: $brightness%"
}

# --- Music Functions ---
get_album_art() {
    local art_url
    art_url=$(playerctl -f "{{mpris:artUrl}}" metadata 2>/dev/null) || return

    if [[ "$art_url" == file://* ]]; then
        echo "${art_url#file://}"
    else
        echo "/usr/share/icons/default_album.png"  # fallback path
    fi
}

show_music_notification() {
    local title artist album
    title=$(playerctl -f "{{title}}" metadata 2>/dev/null || echo "")
    artist=$(playerctl -f "{{artist}}" metadata 2>/dev/null || echo "")
    album=$(playerctl -f "{{album}}" metadata 2>/dev/null || echo "")
    
    [[ -z "$title" && -z "$artist" ]] && return
    
    local summary="󰎆  $title"
    local body="󰠃  $artist"
    [[ -n "$album" ]] && body="$body - $album"
    
    album_art=""
[[ "$SHOW_ALBUM_ART" == "true" ]] && album_art=$(get_album_art)
    
    notify-send \
        --app-name="Music Player" \
        --expire-time="$NOTIFICATION_TIMEOUT" \
        --transient \
        --hint="string:x-dunst-stack-tag:music_notif" \
        --icon="$album_art" \
        "$summary" "$body"
}

volume_up() {
    pactl set-sink-mute @DEFAULT_SINK@ 0
    local current_volume
    current_volume=$(get_volume)
    
    if (( current_volume + VOLUME_STEP > MAX_VOLUME )); then
        pactl set-sink-volume @DEFAULT_SINK@ "${MAX_VOLUME}%"
    else
        pactl set-sink-volume @DEFAULT_SINK@ "+${VOLUME_STEP}%"
    fi
    show_volume_notification
}

volume_down() {
    pactl set-sink-volume @DEFAULT_SINK@ "-${VOLUME_STEP}%"
    show_volume_notification
}

volume_mute() {
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    show_volume_notification
}

mic_mute() {
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
    show_mic_notification
}

brightness_up() {
    brightnessctl set "${BRIGHTNESS_STEP}%+"
    show_brightness_notification
}

brightness_down() {
    brightnessctl set "${BRIGHTNESS_STEP}%-"
    show_brightness_notification
}

play_next() {
    playerctl next
    sleep 0.2
    show_music_notification
}

play_prev() {
    playerctl previous
    sleep 0.2
    show_music_notification
}

play_pause() {
    playerctl play-pause
    sleep 0.1
    show_music_notification
}

main() {
    local -r action="${1:-}"
    
    case "$action" in
        volume_up) volume_up ;;
        volume_down) volume_down ;;
        volume_mute) volume_mute ;;
        mic_mute) mic_mute ;;
        brightness_up) brightness_up ;;
        brightness_down) brightness_down ;;
        play_next) play_next ;;
        play_prev) play_prev ;;
        play_pause) play_pause ;;
        *)
            echo "Usage: $0 {volume_up|volume_down|volume_mute|mic_mute|brightness_up|brightness_down|play_next|play_prev|play_pause}"
            exit 1
            ;;
    esac
}

# --- Script Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
