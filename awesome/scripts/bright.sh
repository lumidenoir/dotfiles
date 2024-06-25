cur=$(cat /sys/class/backlight/*/brightness)
max=192
per=$((cur/max))
percent="$per"
echo $percent