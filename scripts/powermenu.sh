#!/bin/bash

# All supported choices
all=(shutdown reboot suspend logout lockscreen)

# By default, show all
show=("${all[@]}")

declare -A texts
texts[lockscreen]="lock screen"
texts[logout]="log out"
texts[suspend]="suspend"
texts[reboot]="reboot"
texts[shutdown]="shut down"

declare -A icons
icons[lockscreen]="󰌆 "
icons[logout]=" "
icons[suspend]=" "
icons[reboot]=" "
icons[shutdown]="󰍃 "
icons[cancel]="󰁮 "
icons[confirm]="󰇯 "

declare -A actions
actions[lockscreen]="screenlock.sh" # Assuming screenlock.sh exists
actions[logout]="loginctl kill-user $(whoami)"
actions[suspend]="systemctl suspend"
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
chosen=$(echo "$rofi_options" | rofi -dmenu -p " Power" -i)

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
      confirm_chosen=$(echo -e "${icons[$key]} Yes\n${icons[cancel]} No" | rofi -dmenu -p "󰇯 Are you sure?" -i)
      if [ "$confirm_chosen" = "${icons[$key]} Yes" ]; then
        ${actions[$selected_action]}
      fi
    else
      ${actions[$selected_action]}
    fi
  fi
fi
