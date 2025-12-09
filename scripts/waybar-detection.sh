#!/usr/bin/env bash

LUMINANCE_THRESHOLD=100
CROP_PERCENTAGE=5
COLOR_TEMPLATE="$HOME/.config/wallust/templates/hyprbar"
STYLE_FILE="$HOME/.config/waybar/hypr/style.css"

die() {
    echo "Error: $*" >&2
    exit 1
}

update_template_for_light() {
    sed -i \
        -e 's/@define-color background {{background}};/@define-color background {{foreground}};/' \
        -e 's/@define-color foreground {{foreground}};/@define-color foreground {{background}};/' \
        "$COLOR_TEMPLATE" || die "Failed to update color template"
}

update_style_for_light() {
    sed -i \
        -e 's/background: rgba(0, 0, 0, 0/background: rgba(255, 255, 255, 0/g' \
        "$STYLE_FILE" || die "Failed to update waybar style"
}

update_template_for_dark() {
    sed -i \
        -e 's/@define-color background {{foreground}};/@define-color background {{background}};/' \
        -e 's/@define-color foreground {{background}};/@define-color foreground {{foreground}};/' \
        "$COLOR_TEMPLATE" || die "Failed to update color template"
}

update_style_for_dark() {
    sed -i \
        -e 's/background: rgba(255, 255, 255, 0/background: rgba(0, 0, 0, 0/g' \
        "$STYLE_FILE" || die "Failed to update waybar style"
}

analyze_wallpaper() {
    local wp="$1"
    read -r w h <<<"$(magick identify -format "%w %h" "$wp" 2>/dev/null)" || die "Bad image"
    local crop_h=$((h * CROP_PERCENTAGE / 100))
    read -r r g b <<<"$(magick "$wp" -gravity north -crop "${w}x${crop_h}+0+0" +repage \
        -scale 1x1! -format "%[fx:int(255*r)] %[fx:int(255*g)] %[fx:int(255*b)]" info:- 2>/dev/null)"
    local lum=$(((r * 299 + g * 587 + b * 114) / 1000))
    echo "$r $g $b $lum"
}

main() {
    [[ $# -eq 1 ]] || die "Usage: $0 <wallpaper>"
    local wp="$1"
    [[ -f $wp ]] || die "Wallpaper not found"
    [[ -f $COLOR_TEMPLATE ]] || die "Template missing"
    [[ -f $STYLE_FILE ]] || die "Style file missing"

    echo "Analyzing: $wp"
    read -r r g b lum < <(analyze_wallpaper "$wp")
    echo "RGB: $r $g $b | Luminance: $lum"

    if ((lum > LUMINANCE_THRESHOLD)); then
        echo "Light background"
        update_template_for_light
        update_style_for_light
    else
        echo "Dark background"
        update_template_for_dark
        update_style_for_dark
    fi

    echo "Template adjusted"
}

main "$@"
