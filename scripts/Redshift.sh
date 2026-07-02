#!/usr/bin/env bash

cache_file=$HOME/.cache/$(whoami)/redshift_state

# Detect session type (Wayland/Hyprland vs X11)
if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
	SESSION="wayland"
else
	SESSION="x11"
fi

initial_hook() {
	if [ ! -d "$(dirname "$cache_file")" ]; then
		mkdir -p "$(dirname "$cache_file")"
	fi
	if [ ! -f "$cache_file" ]; then
		echo off >"$cache_file"
	fi
}

get_state() {
	cat "$cache_file"
}

kill_redshift() {
	if [ "$SESSION" = "wayland" ]; then
		pkill -x hyprsunset >/dev/null 2>&1
	else
		pkill -x redshift >/dev/null 2>&1
		redshift -x >/dev/null 2>&1
	fi
}

start_redshift() {
	local temp=$1
	kill_redshift
	sleep 0.05
	if [ "$SESSION" = "wayland" ]; then
		hyprsunset -t "$temp" >/dev/null 2>&1 &
	else
		redshift -O "$temp" >/dev/null 2>&1
	fi
}

disable_redshift() {
	kill_redshift
	echo off >"$cache_file"
}

enable_redshift() {
	start_redshift 4000
	echo on >"$cache_file"
}

enable_auto() {
	# Determine day vs. night using current hour
	local hour
	hour=$(date +%-H)

	# Night hours: 19:00 (7pm) to 06:00 (6am)
	if [ "$hour" -ge 19 ] || [ "$hour" -lt 6 ]; then
		start_redshift 4000
		echo on >"$cache_file"
	else
		kill_redshift
		echo off >"$cache_file"
	fi
}

toggle() {
	local state=$(get_state)
	if [[ $state == "on" ]]; then
		disable_redshift
	else
		enable_redshift
	fi
}

initial_hook

case "$1" in
	--state)
		get_state;;
	--toggle)
		toggle;;
	--auto)
		enable_auto;;
	*)
		toggle
		echo "usage: [--state][--toggle][--auto]";;
esac
