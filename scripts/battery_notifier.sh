#!/bin/bash

if ! command -v acpi >/dev/null || ! command -v notify-send >/dev/null; then
    echo "Error: acpi or notify-send not found. Install them to run this script."
    exit 1
fi

declare -A WARHAMMER HELLDIVERS DOOM CYBER SYSADMIN GAMER

WARHAMMER[20]="Power reserves waning, Guardsman. The Emperor frowns upon negligence."
WARHAMMER[10]="Commissar’s watching. Plug in before you’re declared heretic."
WARHAMMER[5]="By the Emperor! Power failing! Connect the charger or face execution!"

HELLDIVERS[20]="Citizen, your energy reserves are low. Democracy demands recharging."
HELLDIVERS[10]="Battery below 10%. Freedom isn’t free - plug in to serve longer!"
HELLDIVERS[5]="Emergency! Power levels critical! Recharge now for managed democracy!"

DOOM[20]="Energy levels low... the demons can smell weakness."
DOOM[10]="You’re running out of juice, Slayer. Rip and plug."
DOOM[5]="ARGENT reserves critical! Charge or perish in hellfire!"

CYBER[20]="Battery below optimal levels. Efficiency compromised."
CYBER[10]="Warning: neural uplink destabilizing - connect to grid."
CYBER[5]="Power cell collapse imminent. Jack in or shut down."

SYSADMIN[20]="Oh sure, ignore the power warnings. What could go wrong?"
SYSADMIN[10]="Nice. You’ve officially joined the 'living dangerously' club."
SYSADMIN[5]="Bravo. Truly the pinnacle of power management skills."

GAMER[20]="Battery’s dropping - like your K/D ratio."
GAMER[10]="You’re one frame away from a shutdown, champ."
GAMER[5]="Game over. Plug in before the respawn timer hits zero."

themes=(WARHAMMER HELLDIVERS DOOM CYBER SYSADMIN GAMER)

while true; do
    BAT_INFO=$(acpi -b)
    STATUS=$(echo "$BAT_INFO" | grep -o "Discharging")
    CAPACITY=$(echo "$BAT_INFO" | grep -P -o '[0-9]+(?=%)')

    if [[ -z "$CAPACITY" ]]; then
        sleep 30
        continue
    fi

    # Only manage Wayland bars (Quickshell / Waybar) and notification daemon (dunst) if running in a Wayland session
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
        # Determine the current running panel
        if pgrep -x "quickshell" >/dev/null; then
            current="quickshell"
        elif pgrep -x "waybar" >/dev/null; then
            current="waybar"
        else
            current="none"
        fi

        # Determine the target panel based on battery status and capacity (with hysteresis)
        if [[ "$STATUS" == "Discharging" ]] && (( CAPACITY < 15 )); then
            target="waybar"
        elif (( CAPACITY > 25 )); then
            target="quickshell"
        else
            target="$current"
            if [[ "$target" == "none" ]]; then
                target="quickshell"  # Default fallback
            fi
        fi

        if [[ "$target" == "waybar" ]]; then
            if pgrep -x "quickshell" >/dev/null; then
                pkill quickshell
            fi
            if ! pgrep -x "waybar" >/dev/null; then
                waybar -c ~/.config/waybar/hypr/config.json -s ~/.config/waybar/hypr/style.css &
            fi
            if ! pgrep -x "dunst" >/dev/null; then
                dunst &
            fi
        else
            if pgrep -x "waybar" >/dev/null; then
                pkill waybar
            fi
            if pgrep -x "dunst" >/dev/null; then
                pkill dunst
            fi
            if ! pgrep -x "quickshell" >/dev/null; then
                quickshell -p "$HOME/dotfiles/quickshell" &
            fi
        fi
    fi

    if [[ "$STATUS" == "Discharging" ]]; then
        LEVEL=""
        urgency="normal"

        if (( CAPACITY <= 5 )); then
            LEVEL=5
            urgency="critical"
        elif (( CAPACITY <= 15 )); then
            LEVEL=10
            urgency="critical"
        elif (( CAPACITY <= 25 )); then
            LEVEL=20
            urgency="normal"
        fi

        if [[ -n "$LEVEL" ]]; then
            theme=${themes[RANDOM % ${#themes[@]}]}
            var_name="${theme}[$LEVEL]"
            msg="${!var_name}"
            notify-send -u "$urgency" "BATTERY CRITICAL: ${CAPACITY}%" "$msg"
        fi
    fi

    sleep 30
done
