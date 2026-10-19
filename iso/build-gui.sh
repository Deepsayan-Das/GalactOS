#!/bin/bash
# GalactOS — installs and configures the desktop GUI environment on a rootfs
set -e

ROOTFS_DIR="$1"
if [ -z "$ROOTFS_DIR" ]; then
    echo "Usage: $0 <rootfs-dir>"
    exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "ERROR: rootfs directory '$ROOTFS_DIR' not found."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/gui/assets"

echo "==========SETTING UP DNS FOR CHROOT NETWORK ACCESS=========="
sudo cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

echo "==========INSTALLING GUI PACKAGES=========="
sudo chroot "$ROOTFS_DIR" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt update && DEBIAN_FRONTEND=noninteractive apt install -y \
    xserver-xorg \
    xinit \
    openbox \
    xterm \
    python3-xdg \
    picom \
    feh \
    lightdm \
    libpython3.13 desktop-file-utils libnss3 libasound2t64 \
libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1 libxcb-xkb1 libxkbcommon-x11-0 \
network-manager \
pcmanfm \
firefox-esr \
tint2 \
plank \
arc-theme \
papirus-icon-theme \
polybar rofi alacritty fonts-jetbrains-mono fonts-font-awesome fonts-inter alsa-utils"


echo "==========COPYING GUI ASSETS=========="
sudo mkdir -p "$ROOTFS_DIR/root/.config/picom"
sudo cp "$ASSETS_DIR/picom.conf" "$ROOTFS_DIR/root/.config/picom/picom.conf"

sudo mkdir -p "$ROOTFS_DIR/root/.config/openbox"
sudo cp "$ASSETS_DIR/autostart" "$ROOTFS_DIR/root/.config/openbox/autostart"

sudo mkdir -p "$ROOTFS_DIR/usr/share/backgrounds"
sudo cp "$ASSETS_DIR/galactos.jpg" "$ROOTFS_DIR/usr/share/backgrounds/galactos.jpg"

sudo mkdir -p "$ROOTFS_DIR/usr/share/themes/GalactOS-Dark/openbox-3"
sudo cp "$ASSETS_DIR/themerc" "$ROOTFS_DIR/usr/share/themes/GalactOS-Dark/openbox-3/themerc"
sudo cp "$ASSETS_DIR/xbm/"*.xbm "$ROOTFS_DIR/usr/share/themes/GalactOS-Dark/openbox-3/"

sudo mkdir -p "$ROOTFS_DIR/etc/lightdm"
sudo cp "$ASSETS_DIR/lightdm-gtk-greeter.conf" "$ROOTFS_DIR/etc/lightdm/lightdm-gtk-greeter.conf"

sudo mkdir -p "$ROOTFS_DIR/root/.config/polybar"
sudo cp "$ASSETS_DIR/polybar/config.ini" "$ROOTFS_DIR/root/.config/polybar/config.ini"
sudo mkdir -p "$ROOTFS_DIR/root/.config/gtk-3.0"
sudo cp "$ASSETS_DIR/gtk-3.0/settings.ini" "$ROOTFS_DIR/root/.config/gtk-3.0/settings.ini"


sudo mkdir -p "$ROOTFS_DIR/root/.config/rofi" "$ROOTFS_DIR/root/.config/tint2" "$ROOTFS_DIR/root/.local/share/applications"
sudo cp "$ASSETS_DIR/rofi/config.rasi" "$ASSETS_DIR/rofi/galactos.rasi" "$ROOTFS_DIR/root/.config/rofi/"
sudo cp "$ASSETS_DIR/rofi/sidebar.sh" "$ASSETS_DIR/rofi/sidebar.rasi" "$ASSETS_DIR/rofi/launcher.rasi" "$ROOTFS_DIR/root/.config/rofi/"
sudo chmod +x "$ROOTFS_DIR/root/.config/rofi/sidebar.sh"
sudo cp "$ASSETS_DIR/tint2/tint2rc" "$ROOTFS_DIR/root/.config/tint2/tint2rc"
sudo cp "$ASSETS_DIR/applications/"*.desktop "$ROOTFS_DIR/root/.local/share/applications/"

sudo cp "$ASSETS_DIR/menu.xml" "$ROOTFS_DIR/root/.config/openbox/menu.xml"
sudo mkdir -p "$ROOTFS_DIR/root/.config/alacritty"
sudo cp "$ASSETS_DIR/alacritty/alacritty.toml" "$ROOTFS_DIR/root/.config/alacritty/alacritty.toml"

sudo mkdir -p "$ROOTFS_DIR/root/.config/autostart"
sudo cp "$ASSETS_DIR/autostart-override/picom.desktop" "$ROOTFS_DIR/root/.config/autostart/picom.desktop"

echo "==========INSTALLING WEB-GREETER=========="
DEB_NAME="web-greeter-4.0.0-debian.deb"
DEB_DIR="$SCRIPT_DIR/gui/debs"
mkdir -p "$DEB_DIR"
if [ ! -f "$DEB_DIR/$DEB_NAME" ]; then
    wget -P "$DEB_DIR" "https://github.com/JezerM/web-greeter/releases/download/4.0.0/$DEB_NAME"
fi
sudo cp "$DEB_DIR/$DEB_NAME" "$ROOTFS_DIR/root/$DEB_NAME"
sudo chroot "$ROOTFS_DIR" apt install -y "/root/$DEB_NAME"
sudo rm "$ROOTFS_DIR/root/$DEB_NAME"

echo "==========INSTALLING GREETER THEME=========="
THEME_SRC="$SCRIPT_DIR/gui/greeter-theme"
THEME_DST="$ROOTFS_DIR/usr/share/web-greeter/themes/galactos"
[ -f "$THEME_SRC/index.html" ] || { echo "ERROR: greeter theme missing in $THEME_SRC" >&2; exit 1; }
sudo rm -rf "$THEME_DST"
sudo mkdir -p "$THEME_DST"
sudo cp -r "$THEME_SRC/." "$THEME_DST/"
sudo chmod -R a+rX "$THEME_DST"
sudo sed -i 's/^theme = .*/theme = "galactos"/' "$ROOTFS_DIR/etc/lightdm/web-greeter.toml"

echo "==========ENABLING WEB-GREETER=========="
sudo mkdir -p "$ROOTFS_DIR/etc/lightdm/lightdm.conf.d"
printf '[Seat:*]\ngreeter-session=web-greeter\n' | sudo tee "$ROOTFS_DIR/etc/lightdm/lightdm.conf.d/60-web-greeter.conf" > /dev/null

echo "==========CONFIGURING OPENBOX THEME=========="
sudo cp "$ROOTFS_DIR/etc/xdg/openbox/rc.xml" "$ROOTFS_DIR/root/.config/openbox/rc.xml"
sudo sed -i '/<theme>/{n;s|<name>[^<]*</name>|<name>GalactOS-Dark</name>|}' "$ROOTFS_DIR/root/.config/openbox/rc.xml"
sudo sed -i '/<font place="MenuItem">/,/<\/font>/{s|<name>[^<]*</name>|<name>JetBrains Mono</name>|;s|<size>[^<]*</size>|<size>10</size>|}' "$ROOTFS_DIR/root/.config/openbox/rc.xml"

if ! sudo grep -A2 "<theme>" "$ROOTFS_DIR/root/.config/openbox/rc.xml" | grep -q "GalactOS-Dark"; then
    echo "ERROR: GalactOS-Dark theme missing in $ROOTFS_DIR/root/.config/openbox/rc.xml" >&2
    exit 1
fi
echo "nameserver 8.8.8.8" | sudo tee "$ROOTFS_DIR/etc/resolv.conf" > /dev/null
echo "SUCCESS: GUI environment installed and configured at $ROOTFS_DIR"
