#!/usr/bin/env sh

DEFAULT_WM="dwm"

# Session identity
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP="$1"
export DESKTOP_SESSION="$1"

# Background helpers
pgrep -f auto_network_switch.sh >/dev/null || auto_network_switch.sh &
pgrep -f battery_notifier.sh >/dev/null || battery_notifier.sh &

# Start portals
/usr/lib/xdg-desktop-portal &
/usr/lib/xdg-desktop-portal-gtk &
/usr/lib/kf6/kiod6 &

case "$1" in
LG3D)
	exec dbus-run-session /usr/bin/bspwm
	;;
i3)
	exec dbus-run-session /usr/bin/i3
	;;
awesome)
	exec dbus-run-session /usr/bin/awesome
	;;
dwm)
	exec dbus-run-session ~/dotfiles/dwm/run.sh
	;;
qtile)
	exec dbus-run-session /usr/bin/qtile start
	;;
"")
	echo "No WM specified, starting $DEFAULT_WM"
	exec dbus-run-session ~/dotfiles/dwm/run.sh
	;;
*)
	echo "Invalid WM: $1"
	exit 1
	;;
esac
