#!/bin/sh
B=http://10.0.2.2:8000
get() { curl -sf "$B/$1" -o "$2" || echo "FAILED: $1"; }
mkdir -p ~/.config/rofi ~/.config/polybar ~/.config/openbox
for f in config.rasi galactos.rasi sidebar.rasi launcher.rasi sidebar.sh; do get rofi/$f ~/.config/rofi/$f; done
chmod +x ~/.config/rofi/sidebar.sh
get menu.xml ~/.config/openbox/menu.xml
get polybar/config.ini ~/.config/polybar/config.ini
get themerc /usr/share/themes/GalactOS-Dark/openbox-3/themerc
openbox --reconfigure
pkill -x polybar; polybar main >/dev/null 2>&1 &
