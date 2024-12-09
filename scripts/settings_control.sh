#!/usr/bin/env sh

# github https://github.com/Shringe/dunst-media-control
volume_step=5
mic_volume_step=5
brightness_step=5
max_volume=100
mic_max_volume=100
notification_timeout=3000 # in milliseconds

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
    elif [ "$volume" -lt 33 ]; then
        volume_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/volume-level-low.svg"
    elif [ "$volume" -lt 66 ]; then
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
    brightness=$(get_brightness)
    if [ "$brightness" -lt 33 ]; then
        brightness_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/brightness-low-symbolic.svg"
    elif [ "$brightness" -lt 66 ]; then
        brightness_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/brightness-medium-symbolic.svg"
    else
        brightness_icon="/usr/share/icons/Papirus-Dark/32x32@2x/panel/brightness-high-symbolic.svg"
    fi
}

# Displays a volume notification
show_volume_notif() {
    volume=$(get_volume)
    get_volume_icon
    notify-send -i $volume_icon -h int:value:"$volume" -t $notification_timeout "Settings Control" "Volume: $volume%"
}

# Displays mic notification
show_mic_notif() {
    volume=$(get_mic_volume)
    get_mic_icon
    notify-send -i $mic_icon -h int:value:"$volume" -t $notification_timeout "Settings Control" "Mic: $volume%"
}

# Displays a brightness notification
show_brightness_notif() {
    brightness=$(get_brightness)
    get_brightness_icon
    notify-send -i $brightness_icon -h int:value:"$brightness" -t $notification_timeout "Settings Control" "Brightness: $brightness%"
}

# Main function - Takes user input
case $1 in
volup)
    pactl set-sink-mute @DEFAULT_SINK@ 0
    volume=$(get_volume)

    if [ $((volume + volume_step)) -gt $max_volume ]; then
        pactl set-sink-volume @DEFAULT_SINK@ $max_volume%
    else
        pactl set-sink-volume @DEFAULT_SINK@ +$volume_step%
    fi

    show_volume_notif
    ;;

voldown)
    pactl set-sink-volume @DEFAULT_SINK@ -$volume_step%
    show_volume_notif
    ;;

volmute)
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    show_volume_notif
    ;;

briup)
    brightnessctl set +$brightness_step%
    show_brightness_notif
    ;;

bridown)
    brightnessctl set $brightness_step%-
    show_brightness_notif
    ;;

micup)
    pactl set-source-mute @DEFAULT_SOURCE@ 0
    mic_volume=$(get_mic_volume)

    if [ $((mic_volume + mic_volume_step)) -gt $mic_max_volume ]; then
        pactl set-source-volume @DEFAULT_SOURCE@ $mic_max_volume%
    else
        pactl set-source-volume @DEFAULT_SOURCE@ +$mic_volume_step%
    fi

    show_mic_notif
    ;;

micdown)
    pactl set-source-volume @DEFAULT_SOURCE@ -$mic_volume_step%
    show_mic_notif
    ;;

micmute)
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
    show_mic_notif
    ;;
esac
