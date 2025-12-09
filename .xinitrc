#!/usr/bin/env sh

# Default WM if no argument is given
DEFAULT_WM="bspwm"

pgrep -f auto_network_switch.sh >/dev/null || auto_network_switch.sh &

# Parse the argument to startx
case "$1" in
bspwm)
    exec /usr/bin/bspwm
    ;;
i3)
    exec /usr/bin/i3
    ;;
awesome)
    exec /usr/bin/awesome
    ;;
dwm)
    exec ~/dotfiles/dwm/run.sh
    ;;
qtile)
    exec /usr/bin/qtile start
    ;;
*)
    echo "No valid X11 WM specified. Starting $DEFAULT_WM..."
    exec "$DEFAULT_WM"
    ;;
esac
