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
    lightdm"

echo "==========COPYING GUI ASSETS=========="
sudo mkdir -p "$ROOTFS_DIR/root/.config/picom"
sudo cp "$ASSETS_DIR/picom.conf" "$ROOTFS_DIR/root/.config/picom/picom.conf"

sudo mkdir -p "$ROOTFS_DIR/root/.config/openbox"
sudo cp "$ASSETS_DIR/autostart" "$ROOTFS_DIR/root/.config/openbox/autostart"

sudo mkdir -p "$ROOTFS_DIR/usr/share/backgrounds"
sudo cp "$ASSETS_DIR/galactos.jpg" "$ROOTFS_DIR/usr/share/backgrounds/galactos.jpg"

sudo mkdir -p "$ROOTFS_DIR/usr/share/themes/GalactOS-Dark/openbox-3"
sudo cp "$ASSETS_DIR/themerc" "$ROOTFS_DIR/usr/share/themes/GalactOS-Dark/openbox-3/themerc"

echo "==========CONFIGURING OPENBOX THEME=========="
sudo cp "$ROOTFS_DIR/etc/xdg/openbox/rc.xml" "$ROOTFS_DIR/root/.config/openbox/rc.xml"
sudo sed -i '/<theme>/{n;s|<name>[^<]*</name>|<name>GalactOS-Dark</name>|}' "$ROOTFS_DIR/root/.config/openbox/rc.xml"

if ! sudo grep -A2 "<theme>" "$ROOTFS_DIR/root/.config/openbox/rc.xml" | grep -q "GalactOS-Dark"; then
    echo "ERROR: GalactOS-Dark theme missing in $ROOTFS_DIR/root/.config/openbox/rc.xml" >&2
    exit 1
fi

echo "SUCCESS: GUI environment installed and configured at $ROOTFS_DIR"
