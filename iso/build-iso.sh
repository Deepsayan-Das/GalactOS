#!/bin/bash
# GalactOS — builds the bootable live ISO from an already-built rootfs
# (see build-rootfs.sh). Run from the iso/ directory, or pass paths below.
set -e

ROOTFS_DIR="${1:-live-rootfs}"
ISO_STAGING_DIR="${2:-iso}"
OUTPUT_ISO="${3:-galactos-live.iso}"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "ERROR: rootfs directory '$ROOTFS_DIR' not found."
    echo "Build it first: ./build-rootfs.sh $ROOTFS_DIR"
    exit 1
fi

echo "==========PREPARING ISO STAGING DIRECTORY=========="
mkdir -p "$ISO_STAGING_DIR/boot/grub" "$ISO_STAGING_DIR/live"
cp grub/grub.cfg "$ISO_STAGING_DIR/boot/grub/grub.cfg"

echo "==========BUILDING SQUASHFS (clean rebuild, avoids silent append bug)=========="
rm -f "$ISO_STAGING_DIR/live/filesystem.squashfs"
sudo mksquashfs "$ROOTFS_DIR" "$ISO_STAGING_DIR/live/filesystem.squashfs" -e boot

echo "==========COPYING KERNEL + INITRD=========="
cp "$ROOTFS_DIR"/boot/vmlinuz-* "$ISO_STAGING_DIR/boot/vmlinuz"
cp "$ROOTFS_DIR"/boot/initrd.img-* "$ISO_STAGING_DIR/boot/initrd"

echo "==========BUILDING ISO=========="
grub-mkrescue -o "$OUTPUT_ISO" "$ISO_STAGING_DIR/"
ls -lh "$OUTPUT_ISO"

echo "SUCCESS: $OUTPUT_ISO ready."
echo "Copy it to your VirtualBox-accessible location and attach it as the optical drive."