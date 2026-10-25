#!/bin/sh
# Adds GalactOS keybindings to an Openbox rc.xml (idempotent). Usage: insert-keybinds.sh <rc.xml>
RC="$1"
[ -f "$RC" ] || { echo "no such file: $RC"; exit 1; }
grep -q 'galactos-keys' "$RC" && exit 0
sed -i '/<\/keyboard>/i\
    <!-- galactos-keys -->\
    <keybind key="C-A-t"><action name="Execute"><command>alacritty</command></action></keybind>\
    <keybind key="W-space"><action name="Execute"><command>rofi -show drun -theme /usr/share/galactos/rofi/launcher.rasi</command></action></keybind>\
    <keybind key="W-e"><action name="Execute"><command>pcmanfm</command></action></keybind>' "$RC"
