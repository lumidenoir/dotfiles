#!/usr/bin/env bash

cache_file=$HOME/.cache/$(whoami)/redshift_state

initial_hook() {
	if [ ! -d "$(dirname "$cache_file")" ]; then
		mkdir -p "$(dirname "$cache_file")"
	fi
	if [ ! -f "$cache_file" ]; then
		echo off >"$cache_file"
	fi
}

get_state() {
	# check if redshift is running
	cat "$cache_file"
}

disable_redshift() {
	redshift -x >/dev/null 2>&1
	# saving state
	echo off >"$cache_file"
}

enable_redshift() {
	redshift -x >/dev/null 2>&1
	redshift -O 4000 >/dev/null 2>&1
	# saving new state
	echo on >"$cache_file"
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
	*)
		toggle
		echo "usage: [--state][--toggle]";;
esac
