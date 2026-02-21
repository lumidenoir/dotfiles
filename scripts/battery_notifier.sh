#!/bin/bash

while true; do
    read -r STATUS CAPACITY <<<"$(acpi -b | awk -F'[,:% ]+' '{print $3, $4}')"
    [[ "$STATUS" != "Discharging" ]] && sleep 60 && continue
    [[ -z "$CAPACITY" ]] && sleep 60 && continue

    # prevent repeat spam
    STATE_FILE="/tmp/battery_notifier_level"

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
    theme=${themes[RANDOM % ${#themes[@]}]}

    LEVEL=""
    if ((CAPACITY <= 5)); then
        LEVEL=5
        urgency=critical
    elif ((CAPACITY <= 10)); then
        LEVEL=10
        urgency=critical
    elif ((CAPACITY <= 20)); then
        LEVEL=20
        urgency=normal
    fi

    if [[ -n "$LEVEL" ]]; then
        LAST_LEVEL=$(cat "$STATE_FILE" 2>/dev/null)

        if [[ "$LAST_LEVEL" != "$LEVEL" ]]; then
            msg=$(eval "echo \${${theme}[$LEVEL]}")
            notify-send -u "$urgency" "Battery ${CAPACITY}%" "$msg"
            echo "$LEVEL" > "$STATE_FILE"
        fi
    else
        rm -f "$STATE_FILE"
    fi

    sleep 60
done
