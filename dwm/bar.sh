#!/bin/sh

# ^c$var^ = fg color
# ^b$var^ = bg color

interval=0

# load colors
. ~/.config/dwm/themes/onedark

cpu() {
  cpu_val=$(grep -o "^[^ ]*" /proc/loadavg)

  printf "^c$black^ ^b$green^ "
  printf "^c$green^ ^b$grey^ $cpu_val"
}

pkg_updates() {
  #updates=$({ timeout 20 doas xbps-install -un 2>/dev/null || true; } | wc -l) # void
  updates=$({ timeout 20 checkupdates 2>/dev/null || true; } | wc -l) # arch
  # updates=$({ timeout 20 aptitude search '~U' 2>/dev/null || true; } | wc -l)  # apt (ubuntu, debian etc)

    printf "  ^c$green^    $updates"
}

battery() {
  get_capacity="$(cat /sys/class/power_supply/BAT0/capacity)"
  printf "^c$blue^  $get_capacity"
}

brightness() {
  cur=$(cat /sys/class/backlight/*/brightness)
  max=192
  per=$((cur/max))
  percent="$per"
  printf "^c$red^  $percent"
}

mem() {
  printf "^c$black^^b$blue^  "
  printf "^c$blue^^b$grey^ $(free -h | awk '/^Mem/ { print $3 }' | sed s/i//g)"
}

wlan() {
	case "$(cat /sys/class/net/wl*/operstate 2>/dev/null)" in
	up) printf "^c$black^ ^b$red^ 󰤨 ^d^%s""^c$blue^^b$grey^ Connected" ;;
	down) printf "^c$black^ ^b$red^ 󰤭 ^d^%s""^c$blue^^b$grey^ Disconnected" ;;
	esac
}

clock() {
	printf "^c$black^ ^b$pink^ 󱑆 "
	printf "^c$black^^b$pink^ $(date '+%H:%M') "
}

vol(){
	volume="$(pactl list sinks | grep '^[[:space:]]Volume:' | head -n $(( $SINK + 1 )) | tail -n 1 | sed -e 's,.* \([0-9][0-9]*\)%.*,\1,')"
	printf "^c$pink^^b$black^ 奄 $volume"
}

while true; do

  [ $interval = 0 ] || [ $(($interval % 300)) = 0 ] && updates=$(pkg_updates)
  interval=$((interval + 1))

  sleep 1 && xsetroot -name "$updates $(battery) $(brightness) $(vol) $(cpu)  $(mem) $(wlan) $(clock)"
done
