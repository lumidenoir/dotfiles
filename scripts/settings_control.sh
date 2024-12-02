#!/usr/bin/env sh

# github https://github.com/Shringe/dunst-media-control
volume_step=5
mic_volume_step=5
brightness_step=5
max_volume=100
mic_max_volume=100
notification_timeout=3000  # in milliseconds
download_album_art=true
show_album_art=true
show_music_in_volume_indicator=false

# Uses regex to get volume from pactl
get_volume() {
    pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
}

# Uses regex to get mute status from pactl
get_mute() {
    pactl get-sink-mute @DEFAULT_SINK@ | grep -Po '(?<=Mute: )(yes|no)'
}

# Uses regex to get mic volume from pactl
get_mic_volume() {
    pactl get-source-volume @DEFAULT_SOURCE@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
}

# Gets mic mute status
get_mic_mute() {
    pactl get-source-mute @DEFAULT_SOURCE@ | grep -Po '(?<=Mute: )(yes|no)'
}

# Uses regex to get brightness from brightnessctl
get_brightness() {
    brightnessctl | grep -Po '[0-9]{1,3}(?=%)' | head -n 1
}

# Returns a mute icon, a volume-low icon, or a volume-high icon, depending on the volume
get_volume_icon() {
     volume=$(get_volume)
     mute=$(get_mute)

    if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ]; then
        volume_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/volume-level-muted.svg"
    elif [ "$volume" -lt 50 ]; then
        volume_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/volume-level-medium.svg"
    else
        volume_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/volume-level-high.svg"
    fi
}

# Returns mute or unmute mic icon depending on mute status
get_mic_icon() {
     mute=$(get_mic_mute)

    if [ "$mute" == "yes" ]; then
        mic_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/mic-off.svg"
    else
        mic_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/mic-on.svg"
    fi
}

# Always returns the same icon - I couldn't get the brightness-low icon to work with fontawesome
get_brightness_icon() {
    brightness_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/brightness-high-symbolic.svg"
}

get_album_art() {
     url=$(playerctl -f "{{mpris:artUrl}}" metadata)

    if [[ $url == "file://"* ]]; then
        album_art="${url/file:\/\//}"
    elif [[ $url == "http://"* ]] && [[ $download_album_art == "true" ]]; then
         filename="$(echo $url | sed 's/.*\///')"

        if [ ! -f "/tmp/$filename" ]; then
            wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
    elif [[ $url == "https://"* ]] && [[ $download_album_art == "true" ]]; then
         filename="$(echo $url | sed 's/.*\///')"

        if [ ! -f "/tmp/$filename" ]; then
            wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
    else
        album_art=""
    fi
}

# Displays a volume notification
show_volume_notif() {
     volume=$(get_volume)
    get_volume_icon

    if [[ $show_music_in_volume_indicator == "true" ]]; then
         current_song=$(playerctl -f "{{title}} - {{artist}}" metadata)

        if [[ $show_album_art == "true" ]]; then
            get_album_art
        fi

        notify-send -t $notification_timeout -h string:x-dunst-stack-tag:volume_notif -h int:value:$volume -i "$album_art" "$volume_icon $volume%" "$current_song"
    else
        notify-send -i $volume_icon -t $notification_timeout "Settings Control" "Volume: $volume%"
    fi
}

# Displays a music notification
show_music_notif() {
     song_title=$(playerctl -f "{{title}}" metadata)
     song_artist=$(playerctl -f "{{artist}}" metadata)
     song_album=$(playerctl -f "{{album}}" metadata)

    if [[ $show_album_art == "true" ]]; then
        get_album_art
    fi

    notify-send -t $notification_timeout -h string:x-dunst-stack-tag:music_notif -i "$album_art" "$song_title" "$song_artist - $song_album"
}

# Displays mic notification
show_mic_notif() {
     volume=$(get_mic_volume)
    get_mic_icon
    notify-send -i $mic_icon -t $notification_timeout "Settings Control" "Mic: $volume%"
}

# Displays a brightness notification
show_brightness_notif() {
     brightness=$(get_brightness)
    get_brightness_icon
    notify-send -i $brightness_icon -t $notification_timeout "Settings Control" "Brightness: $brightness%"
}

# Main function - Takes user input
case $1 in
    volume_up)
        pactl set-sink-mute @DEFAULT_SINK@ 0
        volume=$(get_volume)

        if [ $((volume + volume_step)) -gt $max_volume ]; then
            pactl set-sink-volume @DEFAULT_SINK@ $max_volume%
        else
            pactl set-sink-volume @DEFAULT_SINK@ +$volume_step%
        fi

        show_volume_notif
        ;;

    volume_down)
        pactl set-sink-volume @DEFAULT_SINK@ -$volume_step%
        show_volume_notif
        ;;

    volume_mute)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        show_volume_notif
        ;;

    brightness_up)
        brightnessctl set +$brightness_step%
        show_brightness_notif
        ;;

    brightness_down)
        brightnessctl set $brightness_step%-
        show_brightness_notif
        ;;

    next)
        playerctl next
        sleep 0.5 && show_music_notif
        ;;

    prev)
        playerctl previous
        sleep 0.5 && show_music_notif
        ;;

    play_pause)
        playerctl play-pause
        show_music_notif
        ;;

    mic_up)
        pactl set-source-mute @DEFAULT_SOURCE@ 0
        mic_volume=$(get_mic_volume)

        if [ $((mic_volume + mic_volume_step)) -gt $mic_max_volume ]; then
            pactl set-source-volume @DEFAULT_SOURCE@ $mic_max_volume%
        else
            pactl set-source-volume @DEFAULT_SOURCE@ +$mic_volume_step%
        fi

        show_mic_notif
        ;;

    mic_down)
        pactl set-source-volume @DEFAULT_SOURCE@ -$mic_volume_step%
        show_mic_notif
        ;;

    mic_mute)
        pactl set-source-mute @DEFAULT_SOURCE@ toggle
        show_mic_notif
        ;;
esac
