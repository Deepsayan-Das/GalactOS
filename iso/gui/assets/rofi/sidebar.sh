#!/bin/sh
bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
st=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
vol=$(amixer sget Master 2>/dev/null | grep -o '[0-9]*%' | head -1)
rows="$(date '+%A, %d %B')
$(date '+%H:%M')
Battery  ${bat:-?}%  ${st}
Volume  ${vol:-n/a}
Terminal
Files
Browser
Restart
Shut down
Log out"
choice=$(printf '%s\n' "$rows" | rofi -dmenu -i -no-custom -p "" -theme /root/.config/rofi/sidebar.rasi)
case "$choice" in
  Terminal) alacritty & ;;
  Files) pcmanfm & ;;
  Browser) firefox-esr & ;;
  Restart) systemctl reboot ;;
  "Shut down") systemctl poweroff ;;
  "Log out") openbox --exit ;;
esac
