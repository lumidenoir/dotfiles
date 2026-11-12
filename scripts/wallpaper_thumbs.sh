#!/bin/bash
CACHE_DIR="$HOME/.cache/wallpaper_thumbs"
mkdir -p "$CACHE_DIR"

# Find all wallpapers in the target folder
find "$HOME/Pictures/wallpaper/hyprland" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | while read -r img; do
    name=$(basename "$img")
    thumb="$CACHE_DIR/$name"
    
    # Generate thumbnail asynchronously if it doesn't exist
    if [ ! -f "$thumb" ]; then
        convert "$img" -thumbnail 300x169^ -gravity center -extent 300x169 "$thumb" >/dev/null 2>&1 &
    fi
    
    # Immediately output the original path to keep the list loading instantaneous
    echo "$img"
done
