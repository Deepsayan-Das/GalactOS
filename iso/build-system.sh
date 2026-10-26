#!/bin/bash
# GalactOS - system layer after build-gui.sh: extra packages, locale, shared assets, /etc/skel, live user.
# Usage: build-system.sh <rootfs-dir>
set -euo pipefail
ROOTFS="${1:-}"
[ -d "$ROOTFS" ] || { echo "Usage: $0 <rootfs-dir>"; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/gui/assets"
LIST="$SCRIPT_DIR/gui/packages-extra.txt"
die() { echo "ERROR: $1" >&2; exit 1; }
[ -f "$LIST" ] || die "$LIST missing"

echo "==========DNS FOR CHROOT=========="
sudo cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

sudo chroot "$ROOTFS" /bin/bash -c "dpkg -s grub-pc >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y grub-pc || true"
sudo rm -f "$ROOTFS/etc/apt/sources.list.d/debian.sources"
sudo cp "$ASSETS/sources.list" "$ROOTFS/etc/apt/sources.list"
echo "==========INSTALLING EXTRA PACKAGES=========="
mapfile -t PKGS < <(grep -v '^[[:space:]]*#' "$LIST" | grep -v '^[[:space:]]*$')
[ "${#PKGS[@]}" -gt 0 ] || die "no packages listed in $LIST"
sudo chroot "$ROOTFS" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt update && DEBIAN_FRONTEND=noninteractive apt install -y ${PKGS[*]}"
sudo chroot "$ROOTFS" /bin/bash -c "ln -sf /usr/bin/fdfind /usr/local/bin/fd; ln -sf /usr/bin/batcat /usr/local/bin/bat"

echo "==========LOCALE AND HOSTNAME=========="
sudo chroot "$ROOTFS" /bin/bash -c "sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen && update-locale LANG=en_US.UTF-8"
echo galactos | sudo tee "$ROOTFS/etc/hostname" > /dev/null
printf '127.0.0.1 localhost\n127.0.1.1 galactos\n' | sudo tee "$ROOTFS/etc/hosts" > /dev/null

echo "==========SHARED ASSETS (/usr/share/galactos)=========="
SH="$ROOTFS/usr/share/galactos"
sudo mkdir -p "$SH/rofi" "$SH/tint2" "$SH/picom"
sudo cp "$ASSETS"/rofi/*.rasi "$ASSETS/rofi/sidebar.sh" "$SH/rofi/"
sudo chmod +x "$SH/rofi/sidebar.sh"
sudo cp "$ASSETS/tint2/allapps.desktop" "$SH/tint2/"
sudo cp "$ASSETS/picom.conf" "$SH/picom/"

echo "==========CUSTOM ICONS=========="
sudo mkdir -p "$ROOTFS/usr/share/icons/hicolor/scalable/apps"
sudo cp "$ASSETS"/icons/*.svg "$ROOTFS/usr/share/icons/hicolor/scalable/apps/"
sudo chroot "$ROOTFS" /bin/bash -c "gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true"

echo "==========GSETTINGS DEFAULTS=========="
sudo cp "$ASSETS/90_galactos.gschema.override" "$ROOTFS/usr/share/glib-2.0/schemas/"
sudo chroot "$ROOTFS" glib-compile-schemas /usr/share/glib-2.0/schemas


echo "==========KEYBINDINGS=========="
sudo sh "$ASSETS/insert-keybinds.sh" "$ROOTFS/root/.config/openbox/rc.xml"

echo "==========/etc/skel (settings for every new user)=========="
sudo mkdir -p "$ROOTFS/etc/skel/.config" "$ROOTFS/etc/skel/.local/share"
sudo cp -a "$ROOTFS/root/.config/." "$ROOTFS/etc/skel/.config/"
sudo cp -a "$ROOTFS/root/.local/share/applications" "$ROOTFS/etc/skel/.local/share/"
if sudo grep -rIl "/root/" "$ROOTFS/etc/skel" | head -5 | grep .; then
    die "the files above still contain /root/ paths (fix them in gui/assets)"
fi

echo "==========LIVE USER (galactos / galactos)=========="
sudo chroot "$ROOTFS" /bin/bash -c "id galactos >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,audio,video galactos"
echo 'galactos:galactos' | sudo chroot "$ROOTFS" chpasswd
sudo rm -rf "$ROOTFS/home/galactos/.config" "$ROOTFS/home/galactos/.local/share/applications"
sudo mkdir -p "$ROOTFS/home/galactos/.local/share"
sudo cp -a "$ROOTFS/etc/skel/.config" "$ROOTFS/home/galactos/.config"
sudo cp -a "$ROOTFS/etc/skel/.local/share/applications" "$ROOTFS/home/galactos/.local/share/applications"
sudo chroot "$ROOTFS" chown -R galactos:galactos /home/galactos

echo "==========CLEANING APT CACHE=========="
sudo chroot "$ROOTFS" /bin/bash -c "apt clean && rm -rf /var/lib/apt/lists/*"

echo "nameserver 8.8.8.8" | sudo tee "$ROOTFS/etc/resolv.conf" > /dev/null
echo "SUCCESS: system layer installed in $ROOTFS"
