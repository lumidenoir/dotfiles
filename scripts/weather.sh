#!/usr/bin/env sh

check_if_empty() {
    [[ -z "$1" ]] && echo "0" || echo "$1"
}

CITY="Kanpur"
# Fetch from Open-Meteo for IIT Kanpur coordinates (26.5123, 80.2329)
WEATHER=$(curl -sf "https://api.open-meteo.com/v1/forecast?latitude=26.5123&longitude=80.2329&current=temperature_2m,apparent_temperature,weather_code&timezone=auto")

if [ -z "$WEATHER" ]; then
    WEATHER_TEMP="0"
    WEATHER_FEELS_LIKE="0"
    WEATHER_CODE="0"
else
    # Parse and round temperature and feels like values
    WEATHER_TEMP=$(echo "$WEATHER" | jq -r ".current.temperature_2m" | awk '{print int($1+0.5)}')
    WEATHER_FEELS_LIKE=$(echo "$WEATHER" | jq -r ".current.apparent_temperature" | awk '{print int($1+0.5)}')
    WEATHER_CODE=$(echo "$WEATHER" | jq -r ".current.weather_code")
fi

WEATHER_ICON=""
WEATHER_NERD_ICON="󰖙"
WEATHER_HEX="#ffd86b"
WEATHER_DESC="Clear"

case $WEATHER_CODE in
0)
    WEATHER_ICON=""
    WEATHER_NERD_ICON="󰖙"
    WEATHER_HEX="#ffd86b"
    WEATHER_DESC="Clear"
    ;;
1|2|3)
    WEATHER_ICON=""
    WEATHER_NERD_ICON="󰖕"
    WEATHER_HEX="#adadff"
    WEATHER_DESC="Partly Cloudy"
    ;;
45|48)
    WEATHER_ICON=""
    WEATHER_NERD_ICON=""
    WEATHER_HEX="#84afdb"
    WEATHER_DESC="Foggy"
    ;;
51|53|55)
    WEATHER_ICON=""
    WEATHER_NERD_ICON="󰖗"
    WEATHER_HEX="#6b95ff"
    WEATHER_DESC="Drizzle"
    ;;
61|63|65)
    WEATHER_ICON=""
    WEATHER_NERD_ICON="󰖖"
    WEATHER_HEX="#6b95ff"
    WEATHER_DESC="Rainy"
    ;;
71|73|75|77)
    WEATHER_ICON=""
    WEATHER_NERD_ICON=""
    WEATHER_HEX="#e3e6fc"
    WEATHER_DESC="Snowy"
    ;;
80|81|82)
    WEATHER_ICON=""
    WEATHER_NERD_ICON="󰖗"
    WEATHER_HEX="#6b95ff"
    WEATHER_DESC="Showers"
    ;;
85|86)
    WEATHER_ICON=""
    WEATHER_NERD_ICON=""
    WEATHER_HEX="#e3e6fc"
    WEATHER_DESC="Snow Showers"
    ;;
95|96|99)
    WEATHER_ICON=""
    WEATHER_NERD_ICON="󰖓"
    WEATHER_HEX="#ffeb57"
    WEATHER_DESC="Thunderstorm"
    ;;
*)
    WEATHER_ICON=""
    WEATHER_NERD_ICON="󰖐"
    WEATHER_HEX="#adadff"
    WEATHER_DESC="Cloudy"
    ;;
esac

case $1 in
"current_temp")
    check_if_empty "$WEATHER_TEMP"°
    ;;
"current_temp_fahrenheit")
    WEATHER_TEMP=$((WEATHER_TEMP * 9 / 5 + 32))
    check_if_empty "$WEATHER_TEMP"
    ;;
"feels_like")
    check_if_empty "$WEATHER_FEELS_LIKE"
    ;;
"weather_desc")
    [[ -z $WEATHER_DESC ]] && echo "Not Available." || echo "$WEATHER_DESC"
    ;;
"icon")
    echo $WEATHER_ICON
    ;;
"nicon")
    echo $WEATHER_NERD_ICON
    ;;
"hex")
    echo $WEATHER_HEX
    ;;
"full")
    echo "$WEATHER"
    ;;
"city")
    echo "$CITY"
    ;;
"wmodule")
    echo $WEATHER_ICON "$WEATHER_TEMP"°
    ;;
"wnmodule")
    echo $WEATHER_NERD_ICON "$WEATHER_TEMP"°
    ;;
esac
