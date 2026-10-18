#!/bin/sh
B=http://10.0.2.2:8000
T=/usr/share/themes/GalactOS-Dark/openbox-3
curl -s $B/themerc -o $T/themerc
for f in $(curl -s $B/xbm/ | grep -o '[a-z_]*\.xbm' | sort -u); do curl -s $B/xbm/$f -o $T/$f; done
openbox --reconfigure
