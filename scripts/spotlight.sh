#!/usr/bin/env bash

# --- config ---
DIR=~/org
MOVIE_DIRS=("/mnt/storage/Movies" "/run/media/$USER/7958-E812/movie")
DOC_DIRS=("books" "college")
BOOKMARK_FILE="$HOME/.cache/.bookmarks"
EMOJI_FILE="$HOME/dotfiles/misc/emojis.txt"
BROWSER="${BROWSER:-qutebrowser}"
if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
	ROFI_CMD=(rofi -dmenu -i -theme ~/.config/rofi/mac-spotlight.rasi)
else
	ROFI_CMD=(rofi -dmenu -i -theme ~/dotfiles/rofi/dwm.rasi)
fi

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

rofi_menu() {
	local args=()
	local has_p=false
	local p_val=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-p)
			if [[ -n "${2:-}" ]]; then
				has_p=true
				p_val="$2"
				args+=("-p" "$2")
				shift 2
			else
				args+=("-p" "")
				shift 1
			fi
			;;
		*)
			args+=("$1")
			shift
			;;
		esac
	done

	if $has_p; then
		"${ROFI_CMD[@]}" "${args[@]}" -theme-str 'prompt{enabled:true;}'
	else
		"${ROFI_CMD[@]}" "${args[@]}" -theme-str 'prompt{enabled:false;}'
	fi
}

show_shortcuts() {
	rofi_menu -p "Shortcuts" -theme-str 'entry{placeholder:"Spotlight Search shortcuts...";}' <<EOF
!w <query>   - Web Search (Bookmarks & DuckDuckGo)
!l <query>   - Search Library files (filtered)
!m <query>   - Search Movies (filtered)
!e <query>   - Search Emojis (filtered)
!c           - Clipboard manager
!t           - Select theme / wallpaper
!ocr         - Screen OCR
!h or ?      - Show this help list
EOF
	exit 0
}

# --- modes ---
mode_screenshot() {
	local choice
	choice=$(printf '%s\n' \
		"󰆞   Capture Region" \
		"󰏫   Annotate Region" \
		"󱎫   Capture Screen (3s delay)" \
		"󰖯   Capture Active Window" \
		"󰕧   Record Screen" \
		"󰕨   Record Region" \
		"󰓛   Stop Recording" | rofi_menu -p "Screen" -theme-str 'entry{placeholder:"Select screenshot action...";}')
	case "$choice" in
	*'Capture Region') screenshot.sh --sel ;;
	*'Annotate Region') screenshot.sh --edit ;;
	*'3s delay'*) screenshot.sh --in 3 ;;
	*'Active Window') screenshot.sh --active ;;
	*'Record Screen') screenshot.sh --record ;;
	*'Record Region') screenshot.sh --record-sel ;;
	*'Stop Recording') screenshot.sh --stop ;;
	esac
}

mode_web() {
	local filter_arg=()
	[[ -n "$1" ]] && filter_arg=(-filter "$1")
	local query
	query=$(rofi_menu "${filter_arg[@]}" -p "Web Search" -theme-str 'entry{placeholder:"Search bookmarks or type URL...";}' -input "$BOOKMARK_FILE" -lines 6)
	[[ -z "$query" ]] && return
	if [[ "$query" =~ ^(http|www) ]]; then
		xdg-open "$query"
	else
		"$BROWSER" "https://duckduckgo.com/?q=$query"
	fi
}

mode_library() {
	local filter_arg=()
	[[ -n "$1" ]] && filter_arg=(-filter "$1")
	declare -A ASSET
	for sub in "${DOC_DIRS[@]}"; do
		local icon="📄   "
		[[ "$sub" == "books" ]] && icon="📖   "
		[[ "$sub" == "college" ]] && icon="🎓   "
		load_assets "$icon" "$DIR/$sub"
	done
	local choice
	choice=$(printf '%s\n' "${!ASSET[@]}" | rofi_menu "${filter_arg[@]}" -p "Library" -theme-str "window{width:35em;}" -theme-str 'entry{placeholder:"Search library books and files...";}')
	[[ -n "$choice" ]] && xdg-open "${ASSET[$choice]}"
}

mode_movie() {
	local filter_arg=()
	[[ -n "$1" ]] && filter_arg=(-filter "$1")
	declare -A ASSET
	load_assets "🎬   " "${MOVIE_DIRS[0]}"
	load_assets "󰋊   " "${MOVIE_DIRS[1]}"
	local choice
	choice=$(printf '%s\n' "${!ASSET[@]}" | rofi_menu "${filter_arg[@]}" -p "Movies" -theme-str "window{width:35em;}" -theme-str 'entry{placeholder:"Select movie to play...";}')
	[[ -n "$choice" ]] && mpv "${ASSET[$choice]}"
}

mode_emoji() {
	local filter_arg=()
	[[ -n "$1" ]] && filter_arg=(-filter "$1")
	[[ -f "$EMOJI_FILE" ]] ||
		curl -s https://raw.githubusercontent.com/Mange/rofi-emoji/master/all_emojis.txt -o "$EMOJI_FILE"

	local chosen emoji
	chosen=$(awk -F'\t' '{printf "%s\t%s\n", $1, $4}' "$EMOJI_FILE" | rofi_menu "${filter_arg[@]}" -p "Emoji" -theme-str 'entry{placeholder:"Search emojis to copy...";}')
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
			-theme ~/dotfiles/rofi/dwm.rasi
	fi
}

# --- main ---
main() {
	local stype="${1:-}"
	if [[ -z "$stype" ]]; then
		local choice
		choice=$( (
			printf '%s\n' \
				"󰖟   Web Search" \
				"󱉟   Library" \
				"󰄀   Screenshot" \
				"󰗚   Movie" \
				"   Emoji" \
				"󰅍   Clipboard" \
				"󰚢   OCR" \
				"   Theme"
			if [[ -f "$BOOKMARK_FILE" ]]; then
				awk '{print "🔖   " $0}' "$BOOKMARK_FILE"
			fi
		) | rofi_menu -p "Spotlight" -theme-str 'entry{placeholder:"Search files, web, and more...";}')

		[[ -z "$choice" ]] && exit 0

		# Route standard options
		case "$choice" in
		*"Web Search") stype="web" ;;
		*"Library") stype="library" ;;
		*"Screenshot") stype="screenshot" ;;
		*"Movie") stype="movie" ;;
		*"Emoji") stype="emoji" ;;
		*"Clipboard") stype="clipboard" ;;
		*"OCR") stype="ocr" ;;
		*"Theme") stype="theme" ;;
		"🔖  "*)
			# Direct Bookmark Launch
			local bookmark="${choice#🔖  }"
			if [[ "$bookmark" =~ ^(http|www) ]]; then
				xdg-open "$bookmark"
			else
				"$BROWSER" "https://duckduckgo.com/?q=$bookmark"
			fi
			exit 0
			;;
		*)
			# Fallbacks and routing for custom query inputs

			# Check for help command
			if [[ "$choice" == "?" ]] || [[ "$choice" == "!h" ]] || [[ "$choice" == "!help" ]]; then
				show_shortcuts
			fi

			# 1. Prefix query routing (e.g. "!w query", "!l text")
			case "$choice" in
			"!w "* | "!web "*)
				mode_web "${choice#* }"
				exit 0
				;;
			"!l "* | "!lib "*)
				mode_library "${choice#* }"
				exit 0
				;;
			"!m "* | "!movie "*)
				mode_movie "${choice#* }"
				exit 0
				;;
			"!e "* | "!emoji "*)
				mode_emoji "${choice#* }"
				exit 0
				;;
			"!c" | "!clip")
				mode_clipboard
				exit 0
				;;
			"!t" | "!theme")
				theme.sh
				exit 0
				;;
			"!ocr")
				screenshot.sh --ocr
				exit 0
				;;
			esac

			# 2. Math Calculator fallback (e.g., "120 * 8" or "2+2")
			# Permit digits, spaces, and standard math operators
			if [[ "$choice" =~ ^[0-9[:space:]+*/().^-]+$ ]] && [[ "$choice" =~ [0-9] ]]; then
				local result
				if command -v bc &>/dev/null; then
					result=$(echo "$choice" | bc -l 2>/dev/null | sed '/\./ s/\.\{0,1\}0\{1,\}$//')
				else
					result=$(python3 -c "print($choice)" 2>/dev/null)
				fi
				if [[ -n "$result" ]]; then
					if [[ -n "$WAYLAND_DISPLAY" ]]; then
						echo -n "$result" | wl-copy
					else
						echo -n "$result" | xclip -selection clipboard
					fi
					notify-send "Calculator" "$choice = $result (copied to clipboard)"
					exit 0
				fi
			fi

			# 3. Direct URL fallback (e.g., github.com/user, http://...)
			if [[ "$choice" =~ ^(http|www|https) ]] || [[ "$choice" =~ \.(com|net|org|io|gov|edu|me|dev|sh|xyz|info|co)$ ]]; then
				local url="$choice"
				[[ "$url" =~ ^www ]] && url="https://$url"
				[[ ! "$url" =~ ^https?:// ]] && url="https://$url"
				xdg-open "$url"
				exit 0
			fi

			# 4. Default to DuckDuckGo search
			"$BROWSER" "https://duckduckgo.com/?q=$choice"
			exit 0
			;;
		esac
	fi

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
