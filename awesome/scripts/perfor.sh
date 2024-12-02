cpu_val=$(grep -o "^[^ ]*" /proc/loadavg)
mem=$(free -h | awk '/^Mem/ { print $3 }' | sed s/i//g)
echo $mem"|"$cpu_val