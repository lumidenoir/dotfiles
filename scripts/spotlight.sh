#!/usr/bin/env bash
DIR=~/org
MOVIE_DIRS=("/mnt/storage/Movies" "/run/media/$USER/Seagate Backup Plus Drive/movie")
DOC_DIRS=("books" "college")
BOOKMARK_FILE="$HOME/.cache/.bookmarks"
EMOJI_FILE="$HOME/dotfiles/misc/emojis.txt"
ROFI_CMD="rofi -dmenu -i -theme ~/.config/rofi/spotlight.rasi"

touch "$BOOKMARK_FILE"
declare -A ASSET

load_assets() {
    local label="$1" search_dir="$2"
    [[ ! -d "$search_dir" ]] && return
    while IFS= read -r path; do
        ASSET["${label}$(basename "$path")"]="$path"
    done < <(find "$search_dir" -type f 2>/dev/null)
}

main() {
    # If an argument is passed (e.g., ./spotlight.sh clipboard), use it.
    # Otherwise, open the Rofi menu to select the mode.
    if [[ -n "$1" ]]; then
        stype="$1"
    else
        stype=$(echo -e "theme\nweb\nlibrary\nscreenshot\nmovie\nemoji\nclipboard" | $ROFI_CMD -p "Select search ")
    fi

    case "$stype" in
        screenshot)
            choice=$(echo -e "  Capture Region\n  Capture Screen in 3sec\n  Capture Active\n  Record Screen\n  Record Region\nStop recording" | $ROFI_CMD -p " ")
            case "$choice" in
                *'Region') screenshot.sh --sel ;;
                *'3sec')   screenshot.sh --in 3 ;;
                *'Active') screenshot.sh --active ;;
                *'Record'*) screenshot.sh --record${choice/*Region/-sel} ;;
                'Stop'*)   screenshot.sh --stop ;;
            esac ;;
        web)
            query=$($ROFI_CMD -p " " -input "$BOOKMARK_FILE" -lines 0)
            [[ -z "$query" ]] && exit
            [[ "$query" =~ ^(http|www) ]] && xdg-open "$query" || qutebrowser "https://duckduckgo.com/?q=$query" ;;
        library|movie)
            if [[ "$stype" == "library" ]]; then
                for sub in "${DOC_DIRS[@]}"; do load_assets "[$sub] " "$DIR/$sub"; done
                opener="xdg-open"
            else
                load_assets "" "${MOVIE_DIRS[0]}"
                load_assets "[EXT] " "${MOVIE_DIRS[1]}"
                opener="mpv"
            fi
            choice=$(printf "%s\n" "${!ASSET[@]}" | $ROFI_CMD -p " " -theme-str "window{width:35em;}")
            [[ -n "$choice" ]] && $opener "${ASSET[$choice]}" ;;
        theme) theme.sh ;;
        emoji)
            [[ ! -f "$EMOJI_FILE" ]] && curl -s https://raw.githubusercontent.com/Mange/rofi-emoji/master/all_emojis.txt -o "$EMOJI_FILE"
            CHOSEN=$(awk -F'\t' '{printf "%s\t%s\n", $1, $4}' "$EMOJI_FILE" | $ROFI_CMD -p "Emoji")
            
            if [[ -n "$CHOSEN" ]]; then
                EMOJI=$(echo "$CHOSEN" | awk '{print $1}' | tr -d '\n\r')
                if [[ -n "$WAYLAND_DISPLAY" ]]; then
                    echo -n "$EMOJI" | wl-copy
                else
                    echo -n "$EMOJI" | xclip -selection clipboard
                fi
                notify-send "Copied $EMOJI"
            fi ;;
        clipboard)
            if [[ -n "$WAYLAND_DISPLAY" ]]; then
                kitty --class clipse -e 'clipse'
            else
                rofi -modi "clipboard:greenclip print" -show clipboard \
                    -theme-str "window{width:45em;}" \
                    -theme ~/.config/rofi/spotlight.rasi
            fi ;;
    esac
}

# Pass all script arguments to the main function
main "$@"
