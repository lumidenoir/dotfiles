#!/bin/bash

# All supported choices
all=(shutdown reboot suspend hibernate logout lockscreen)

# By default, show all
show=("${all[@]}")

declare -A texts
texts[lockscreen]="lock screen"
texts[logout]="log out"
texts[suspend]="suspend"
texts[reboot]="reboot"
texts[shutdown]="shut down"
texts[hibernate]="hibernate"

declare -A icons
icons[lockscreen]="󰌆 "
icons[logout]=" "
icons[suspend]=" "
icons[hibernate]="󰋊 "
icons[reboot]=" "
icons[shutdown]="󰍃 "
icons[cancel]="󰅖 "

declare -A actions
actions[lockscreen]="screenlock.sh"
actions[logout]="loginctl terminate-session ${XDG_SESSION_ID-}"
actions[suspend]="systemctl suspend"
actions[hibernate]="systemctl hibernate"
actions[reboot]="systemctl reboot"
actions[shutdown]="systemctl poweroff"

# By default, ask for confirmation for irreversible actions
confirmations=(reboot shutdown logout)

# Prepare rofi input
rofi_options=""
for entry in "${show[@]}"; do
    rofi_options+="${icons[$entry]} ${texts[$entry]}\n"
done
rofi_options=$(echo -e "$rofi_options")

# Launch rofi and get the selection
chosen=$(echo "$rofi_options" | rofi -dmenu -p " Power" -i -theme ~/.config/rofi/spotlight.rasi)

if [ -n "$chosen" ]; then
    selected_action=""
    for key in "${!texts[@]}"; do
        if [ "$chosen" = "${icons[$key]} ${texts[$key]}" ]; then
            selected_action="$key"
            break
        fi
    done

    if [ -n "$selected_action" ]; then
        needs_confirmation=false
        for confirm_action in "${confirmations[@]}"; do
            if [ "$selected_action" = "$confirm_action" ]; then
                needs_confirmation=true
                break
            fi
        done

        if "$needs_confirmation"; then
            confirm_chosen=$(echo -e "${icons[$key]} $key\n${icons[cancel]} No" | rofi -dmenu -p "󰇯 Are you sure?" -i -theme ~/.config/rofi/spotlight.rasi)
            if [ "$confirm_chosen" = "${icons[$key]} $key" ]; then
                ${actions[$selected_action]}
            fi
        else
            ${actions[$selected_action]}
        fi
    fi
fi
