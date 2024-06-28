#!/usr/bin/env bash

# Path to the file where bookmarks will be stored
BOOKMARK_FILE="$HOME/.bookmarks"

# Check if the bookmark file exists, if not, create it
touch "$BOOKMARK_FILE"

# Function to add a bookmark
add_bookmark() {
    echo "$1" >> "$BOOKMARK_FILE"
}

# Function to display bookmarks
display_bookmarks() {
    if [ -s "$BOOKMARK_FILE" ]; then
        cat "$BOOKMARK_FILE" | rofi -dmenu -i -lines 5 -p "Bookmarks: " -location 0
    else
        echo "No bookmarks saved."
    fi
}

# Function to open a URL
open_url() {
    xdg-open "$1"
}

# Main function
main() {
    query=$( (echo ) | rofi -dmenu -i -lines 0 -matching fuzzy -location 0 -p " " -input "$BOOKMARK_FILE")

    if [[ -n "$query" ]]; then
        # If the query is a URL, open it directly
        if [[ "$query" == "http"* || "$query" == "www"* ]]; then
            open_url "$query"
        else
            # Construct DuckDuckGo search URL
            url="https://www.duckduckgo.com/?q=$query"
            # Open the URL
            open_url "$url"
        fi
    else
        # If query is empty, show bookmarks
        display_bookmarks
    fi
}

# Call the main function
main

exit 0
