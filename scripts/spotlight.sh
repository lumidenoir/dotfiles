#!/usr/bin/env bash

# --- config ---
DIR=~/org
MOVIE_DIRS=("/mnt/storage/Movies" "/run/media/$USER/7958-E812/movie")
DOC_DIRS=("books" "college")
BOOKMARK_FILE="$HOME/.cache/.bookmarks"
EMOJI_FILE="$HOME/dotfiles/misc/emojis.txt"
BROWSER="${BROWSER:-qutebrowser}"
ROFI_CMD=(rofi -dmenu -i -theme ~/.config/rofi/spotlight.rasi)

touch "$BOOKMARK_FILE"

# --- helpers ---
require() { command -v "$1" &>/dev/null || {
    notify-send "spotlight: missing '$1'"
    exit 1
}; }

load_assets() {
    local label="$1" search_dir="$2"
    [[ -d "$search_dir" ]] || return
    while IFS= read -r path; do
        ASSET["${label}$(basename "$path")"]="$path"
    done < <(find "$search_dir" -type f 2>/dev/null)
}

rofi_menu() { "${ROFI_CMD[@]}" "$@"; }

# --- modes ---
mode_screenshot() {
    local choice
    choice=$(printf '%s\n' \
        "Capture Region" \
        "Capture Screen in 3sec" \
        "Capture Active" \
        "Record Screen" \
        "Record Region" \
        "Stop recording" | rofi_menu -p " ")
    case "$choice" in
    *'Capture Region') screenshot.sh --sel ;;
    *'3sec') screenshot.sh --in 3 ;;
    *'Active') screenshot.sh --active ;;
    *'Record Screen') screenshot.sh --record ;;
    *'Record Region') screenshot.sh --record-sel ;;
    'Stop'*) screenshot.sh --stop ;;
    esac
}

mode_web() {
    local query
    query=$(rofi_menu -p " " -input "$BOOKMARK_FILE" -lines 0)
    [[ -z "$query" ]] && return
    if [[ "$query" =~ ^(http|www) ]]; then
        xdg-open "$query"
    else
        "$BROWSER" "https://duckduckgo.com/?q=$query"
    fi
}

mode_library() {
    declare -A ASSET
    for sub in "${DOC_DIRS[@]}"; do load_assets "[$sub] " "$DIR/$sub"; done
    local choice
    choice=$(printf '%s\n' "${!ASSET[@]}" | rofi_menu -p " " -theme-str "window{width:35em;}")
    [[ -n "$choice" ]] && xdg-open "${ASSET[$choice]}"
}

mode_movie() {
    declare -A ASSET
    load_assets "" "${MOVIE_DIRS[0]}"
    load_assets "[EXT] " "${MOVIE_DIRS[1]}"
    local choice
    choice=$(printf '%s\n' "${!ASSET[@]}" | rofi_menu -p " " -theme-str "window{width:35em;}")
    [[ -n "$choice" ]] && mpv "${ASSET[$choice]}"
}

mode_emoji() {
    [[ -f "$EMOJI_FILE" ]] ||
        curl -s https://raw.githubusercontent.com/Mange/rofi-emoji/master/all_emojis.txt -o "$EMOJI_FILE"
    # columns: emoji <tab> ... <tab> ... <tab> name
    local chosen emoji
    chosen=$(awk -F'\t' '{printf "%s\t%s\n", $1, $4}' "$EMOJI_FILE" | rofi_menu -p "Emoji")
    [[ -z "$chosen" ]] && return
    emoji=$(awk '{print $1}' <<<"$chosen" | tr -d '\n\r')
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        echo -n "$emoji" | wl-copy
    else
        echo -n "$emoji" | xclip -selection clipboard
    fi
    notify-send "Copied $emoji"
}

mode_clipboard() {
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        kitty --class clipse -e clipse
    else
        rofi -modi "clipboard:greenclip print" -show clipboard \
            -theme-str "window{width:45em;}" \
            -theme ~/.config/rofi/spotlight.rasi
    fi
}

# --- main ---
main() {
    local stype="${1:-}"
    if [[ -z "$stype" ]]; then
        stype=$(printf '%s\n' theme web library screenshot movie emoji clipboard ocr | rofi_menu -p "Select search ")
    fi
    [[ -z "$stype" ]] && exit 0

    case "$stype" in
    screenshot) mode_screenshot ;;
    web) mode_web ;;
    library) mode_library ;;
    movie) mode_movie ;;
    theme) theme.sh ;;
    emoji) mode_emoji ;;
    clipboard) mode_clipboard ;;
    ocr) screenshot.sh --ocr ;;
    *)
        notify-send "spotlight: unknown mode '$stype'"
        exit 1
        ;;
    esac
}

main "$@"
