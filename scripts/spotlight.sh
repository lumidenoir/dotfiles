#!/usr/bin/env bash
DIR=~/org
MOVIE_DIR=/mnt/shared/movie
BOOKMARK_FILE="$HOME/.cache/.bookmarks"
EMOJI_FILE="$HOME/dotfiles/emojis.txt"

touch "$BOOKMARK_FILE"

# Function to prompt user for the folder choice
choose_search() {
    echo -e "theme\nweb\nbooks\ncollege\nscreenshot\nmovie\nemoji" | rofi -dmenu -i -matching normal -no-custom -location 0 -p "Select search " -theme ~/.config/rofi/spotlight.rasi
}

# Associative array for storing assets
declare -A ASSET

# Add elements to ASSET array
get_assets() {
    local label="$1"
    readarray -t F_ARRAY <<<"$(find "$ASSET_DIR" -type f)"

    if [[ -n ${F_ARRAY[*]} ]]; then
        for i in "${!F_ARRAY[@]}"; do
            path="${F_ARRAY[$i]}"
            file=$(basename "$path")
            if [[ -n "$label" ]]; then
                ASSET["$label $file"]="$path"
            else
                ASSET["$file"]="$path"
            fi
        done
    else
        echo "$ASSET_DIR is empty!"
        exit
    fi
}

# List for rofi
gen_list() {
    for i in "${!ASSET[@]}"; do
        echo "$i"
    done
}

#List for screenshot
get_options() {
    echo "  Capture Region"
    echo "  Capture Screen in 3sec"
    echo "  Capture Active"
    echo "  Record Screen"
    echo "  Record Region"
    echo "Stop recording"
}

main() {
    stype=$(choose_search)
    if [[ "$stype" == "screenshot" ]]; then
        choice=$( (get_options) | rofi -dmenu -i -fuzzy -p " " -theme ~/.config/rofi/spotlight.rasi)
        case $choice in
        '  Capture Region')
            screenshot.sh --sel
            ;;
        '  Capture Screen in 3sec')
            screenshot.sh --in 3
            ;;
        '  Capture Active')
            screenshot.sh --active
            ;;
        '  Record Region')
            screenshot.sh --record-sel
            ;;
        '  Record Screen')
            screenshot.sh --record
            ;;
        'Stop recording')
            screenshot.sh --stop
            ;;
        esac
    elif [[ "$stype" == "web" ]]; then
        query=$( (echo) | rofi -dmenu -i -lines 0 -matching fuzzy -location 0 -p " " -input "$BOOKMARK_FILE" -theme ~/.config/rofi/spotlight.rasi)
        if [[ -n "$query" ]]; then
            # If the query is a URL, open it directly
            if [[ "$query" == "http"* || "$query" == "www"* ]]; then
                xdg-open "$query"
            else
                # Construct DuckDuckGo search URL
                url="https://www.duckduckgo.com/?q=$query"
                # Open the URL using qutebrowser
                qutebrowser "$url"
            fi
        else
            echo "no url"
        fi
    elif [[ "$stype" == "books" || "$stype" == "college" ]]; then
        ASSET_DIR="$DIR/$stype"
        get_assets
        asset=$( (gen_list) | rofi -dmenu -i -matching normal -no-custom -location 0 -p " " -theme ~/.config/rofi/spotlight.rasi)
        if [ -n "$asset" ]; then
            xdg-open "${ASSET[$asset]}"
        fi
    elif [[ "$stype" == "movie" ]]; then
        MOVIE_DIRS=("$MOVIE_DIR")
        EXT_MOVIE_DIR="/run/media/krishna/Seagate Backup Plus Drive/movie"

        ASSET=()

        # main movies
        ASSET_DIR="$MOVIE_DIR"
        get_assets

        # external drive movies
        if [[ -d "$EXT_MOVIE_DIR" ]]; then
            ASSET_DIR="$EXT_MOVIE_DIR"
            get_assets "[EXT]"
        fi

        asset=$( (gen_list) | rofi -dmenu -i -matching normal -no-custom -location 0 -p " " -theme ~/.config/rofi/spotlight.rasi)
        if [ -n "$asset" ]; then
            mpv "${ASSET[$asset]}"
        fi
    elif [[ "$stype" == "theme" ]]; then
        theme.sh
    elif [[ "$stype" == "emoji" ]]; then
        if command -v wl-copy &>/dev/null; then
            CLIP="wl-copy"
        else
            CLIP="xclip -selection clipboard"
        fi
        [[ ! -f "$EMOJI_FILE" ]] && {
            echo "Emoji file not found: $EMOJI_FILE" >&2
            curl https://raw.githubusercontent.com/Mange/rofi-emoji/refs/heads/master/all_emojis.txt -o $EMOJI_FILE
            exit 1
        }
        CHOSEN=$(awk -F'\t' '{printf "%s\t%s\n", $1, $4}' "$EMOJI_FILE" | rofi -dmenu -i -p "Select emoji" -format s -theme ~/.config/rofi/spotlight.rasi)

        [[ -n "$CHOSEN" ]] && {
            EMOJI=$(echo "$CHOSEN" | cut -f1)
            echo -n "$EMOJI" | eval "$CLIP"
            notify-send "Copied: $EMOJI"
        }
    else
        echo "none selected"
    fi
}

main

exit 0
