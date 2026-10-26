#!/bin/bash
# GalactOS — build the live ISO from a prepared rootfs and copy it to the D: drive.
# Usage: ./make_iso.sh <version> [--no-gui] [--rootfs DIR] [--force]
#   ./make_iso.sh 26   ->  galactos-gui-v26.iso
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEST="/mnt/d/vbox-gui-iso"
ROOTFS="live-rootfs"
RUN_GUI=1
FORCE=0
VERSION=""

usage() {
    echo "Usage: $0 <version> [--no-gui] [--rootfs DIR] [--force]"
    echo "  e.g. $0 26  ->  galactos-gui-v26.iso copied to $DEST"
    exit 1
}
die() { echo "ERROR: $1" >&2; exit 1; }
step() { echo; echo "========== $1 =========="; }
trap 'echo "ERROR: make_iso.sh stopped at line $LINENO" >&2' ERR

while [ $# -gt 0 ]; do
    case "$1" in
        --no-gui) RUN_GUI=0 ;;
        --force) FORCE=1 ;;
        --rootfs) shift; [ $# -gt 0 ] || usage; ROOTFS="$1" ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) [ -z "$VERSION" ] || usage; VERSION="$1" ;;
    esac
    shift
done
[ -n "$VERSION" ] || usage
VERSION="${VERSION#v}"
[[ "$VERSION" =~ ^[0-9A-Za-z._-]+$ ]] || die "bad version '$VERSION'"
ISO="galactos-gui-v${VERSION}.iso"
START=$(date +%s)

step "PRE-FLIGHT CHECKS"
[ -d "$ROOTFS" ] || die "rootfs '$ROOTFS' not found"
ROOTFS_ABS="$(realpath "$ROOTFS")"
{ [ -d "$DEST" ] && [ -w "$DEST" ]; } || die "$DEST is missing or not writable"
if [ "$FORCE" -eq 0 ]; then
    [ ! -e "$ISO" ] || die "$ISO already exists here. Use a new version number (or --force)."
    [ ! -e "$DEST/$ISO" ] || die "$DEST/$ISO already exists. Use a new version number (or --force)."
fi
if findmnt -rn -o TARGET | grep -qF -- "$ROOTFS_ABS"; then
    findmnt -rn -o TARGET | grep -F -- "$ROOTFS_ABS" || true
    die "something is still mounted under $ROOTFS_ABS. Unmount it first (sudo umount ...), or mksquashfs would pack /dev and /proc."
fi
LOCAL_FREE=$(df -Pm . | awk 'NR==2{print $4}')
DEST_FREE=$(df -Pm "$DEST" | awk 'NR==2{print $4}')
[ "$LOCAL_FREE" -gt 4000 ] || die "only ${LOCAL_FREE} MB free here"
[ "$DEST_FREE" -gt 3000 ] || die "only ${DEST_FREE} MB free on $DEST"
if [ -n "$(git status --porcelain . 2>/dev/null || true)" ]; then
    echo "WARNING: uncommitted changes in iso/ (this ISO won't match a saved commit):"
    git status --short . | head -8
fi
[ -d /usr/lib/grub/x86_64-efi ] || die "host is missing grub-efi-amd64-bin (run: sudo apt install grub-efi-amd64-bin mtools); the ISO would not boot on UEFI"
sudo -v

if [ "$RUN_GUI" -eq 1 ]; then
    step "REFRESHING GUI IN ROOTFS (build-gui.sh)"
    sudo "$SCRIPT_DIR/build-gui.sh" "$ROOTFS"
    sudo "$SCRIPT_DIR/build-system.sh" "$ROOTFS"
else
    echo "Skipping build-gui.sh (--no-gui)"
fi

step "INSTALLING THE INSTALLER AND FIXING DNS"
[ -f installer/galactos-install ] || die "installer/galactos-install not found"
sudo cp installer/galactos-install "$ROOTFS/usr/local/bin/galactos-install"
sudo chmod +x "$ROOTFS/usr/local/bin/galactos-install"
echo "nameserver 8.8.8.8" | sudo tee "$ROOTFS/etc/resolv.conf" > /dev/null

step "CHECKING THE ROOTFS"
for f in usr/share/web-greeter/themes/galactos/index.html \
         etc/lightdm/lightdm.conf.d/60-web-greeter.conf \
         root/.config/openbox/rc.xml root/.config/openbox/menu.xml \
         root/.config/picom/picom.conf root/.config/polybar/config.ini \
         root/.config/tint2/tint2rc root/.config/alacritty/alacritty.toml; do
    sudo test -e "$ROOTFS/$f" || die "missing in rootfs: $f (run without --no-gui?)"
done
for f in usr/bin/orbit usr/local/bin/orbit-launch usr/share/applications/orbit.desktop; do
    sudo test -e "$ROOTFS/$f" || echo "WARNING: $f is not in the rootfs"
done
echo "rootfs looks complete"

step "BUILDING $ISO"
sudo ./build-iso.sh "$ROOTFS" iso "$ISO"
[ -s "$ISO" ] || die "build-iso.sh did not produce $ISO"

copy_and_verify() {
    rm -f "$DEST/$ISO"
    sync
    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
    cp "$ISO" "$DEST/$ISO" || echo "cp reported an error"
    sync
    local a b
    a=$(sha256sum "$ISO" | cut -d' ' -f1)
    b=$(sha256sum "$DEST/$ISO" 2>/dev/null | cut -d' ' -f1)
    echo "  local: $a"
    echo "  D:     $b"
    LAST_HASH="$a"
    [ -n "$b" ] && [ "$a" = "$b" ]
}

step "COPYING TO $DEST"
if ! copy_and_verify; then
    echo "Hashes differ. Retrying the copy once..."
    if ! copy_and_verify; then
        rm -f "$DEST/$ISO"
        WINPATH=$(wslpath -w "$SCRIPT_DIR" 2>/dev/null || echo "$SCRIPT_DIR")
        die "copy failed twice (bad file removed). Copy $ISO from $WINPATH to D:\\vbox-gui-iso by hand in File Explorer, then compare the hash."
    fi
fi

END=$(date +%s)
step "DONE"
echo "ISO:    $DEST/$ISO ($(du -h "$DEST/$ISO" | cut -f1))"
echo "sha256: $LAST_HASH"
echo "Time:   $(( (END - START) / 60 )) min"
echo
echo "Next: power the VM fully off, attach $(wslpath -w "$DEST/$ISO" 2>/dev/null || echo "$DEST/$ISO"), boot."
