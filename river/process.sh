killall dunst
dunst &

killall waybar
waybar -c ~/.config/waybar/nord_red/config -s ~/.config/waybar/nord_red/style.css &

killall polkit-gnome-authentication-agent-1
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

killall nm-applet
nm-applet --indicator &

brightnessctl set 20%

# River will send the process group of the init executable SIGTERM on exit.
riverctl default-layout rivertile &
exec rivertile -main-ratio 0.55 -view-padding 2 -outer-padding 2 &
for pad in $(riverctl list-inputs | grep -i touchpad )
do
  riverctl input $pad events enabled
  riverctl input $pad tap enabled
done

killall swaybg
swaybg -i ~/Pictures/wallpaper/nord/nord.png
