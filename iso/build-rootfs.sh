#!/bin/bash
# GalactOS — builds a branded, packaged rootfs, reused for both the
# installed disk image (build.sh) and the live ISO environment (iso/).
set -e

ROOTFS_DIR="$1"
if [ -z "$ROOTFS_DIR" ]; then
    echo "Usage: $0 <output-rootfs-dir>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==========SCAFFOLDING FILESYSTEM=========="
sudo debootstrap --variant=minbase stable "$ROOTFS_DIR" http://deb.debian.org/debian

echo "==========SETTING UP DNS FOR CHROOT NETWORK ACCESS=========="
sudo cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

echo "==========INSTALLING UNIVERSAL BASELINE PACKAGES=========="
sudo chroot "$ROOTFS_DIR" /bin/bash -c "apt update && apt install -y \
    git curl wget \
    vim nano \
    make build-essential \
    sudo \
    ssh \
    ca-certificates \
    fdisk \
    e2fsprogs \
    rsync"

echo "==========INSTALLING NOVA (via GalactOS apt repo)=========="
sudo chroot "$ROOTFS_DIR" /bin/bash -c "
  apt install -y curl gnupg
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deepsayan-das.github.io/nova/KEY.gpg | gpg --dearmor -o /etc/apt/keyrings/galactos.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/galactos.gpg] https://deepsayan-das.github.io/nova stable main' > /etc/apt/sources.list.d/galactos.list
  apt update && apt install -y nova
"

echo "==========CONFIGURING OS_RELEASE=========="
sudo sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="GalactOS Ignition (beta-v1.0)"/' "$ROOTFS_DIR/etc/os-release"
sudo sed -i 's|^NAME=.*|NAME="GalactOS GNU/Linux"|' "$ROOTFS_DIR/etc/os-release"
echo 'ID_LIKE=debian' | sudo tee -a "$ROOTFS_DIR/etc/os-release" > /dev/null

echo "==========SETTING LOGIN BANNER=========="
echo -e "GalactOS Ignition (beta-v1.0) \n \l" | sudo tee "$ROOTFS_DIR/etc/issue" > /dev/null

echo "==========INSTALLING KERNEL + LIVE-BOOT SUPPORT=========="
sudo chroot "$ROOTFS_DIR" /bin/bash -c "apt install -y linux-image-amd64 live-boot systemd-sysv grub-pc"

echo "==========INSTALLING DESKTOP GUI ENVIRONMENT=========="
"$SCRIPT_DIR/build-gui.sh" "$ROOTFS_DIR"

echo "==========SETTING ROOT PASSWORD=========="
read -sp "Enter root password for this GalactOS rootfs: " ROOTPASS
echo
sudo chroot "$ROOTFS_DIR" /bin/bash -c "echo 'root:${ROOTPASS}' | chpasswd"
unset ROOTPASS

echo "==========CLEANING APT CACHE=========="
sudo chroot "$ROOTFS_DIR" /bin/bash -c "apt clean && rm -rf /var/lib/apt/lists/*"

echo "SUCCESS: unified rootfs ready at $ROOTFS_DIR"