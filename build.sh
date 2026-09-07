#!/bin/bash
set -e

echo "==========UPDATING SYSTEM=========="
sudo apt update
echo "===================================="

echo "==========INSTALLING DEBOOTSTRAP=========="
sudo apt install -y debootstrap
echo "============================================"

echo "==========SCAFFOLDING FILESYSTEM=========="
sudo debootstrap --variant=minbase stable rootfs http://deb.debian.org/debian
echo "============================================"

echo "==========INSTALLING UNIVERSAL BASELINE PACKAGES=========="
# Single source of truth for what ships in every GalactOS image, regardless
# of stack. Anything stack-specific (python, node, go, etc.) belongs behind
# `nova install`, not here.
#
#   git, curl, wget   - ubiquitous dev commands; both curl+wget kept
#                        deliberately so muscle-memory commands never fail
#                        with "command not found"
#   vim, nano         - vim is the opinionated default editor (preference,
#                        not "necessity"); nano kept as the widely-known
#                        fallback for anyone who doesn't use vim
#   make              - paired with build-essential below, not useful alone
#   build-essential   - gcc, g++, libc6-dev, make, etc. — real C/C++ builds
#                        need headers, not just a bare compiler binary
#   sudo              - privilege escalation for any non-root user created
#                        later (see TODO at bottom of this script)
#   ssh               - Debian metapackage; pulls in openssh-client AND
#                        openssh-server. Installing openssh-server on top of
#                        this is redundant, so we don't.
#   ca-certificates   - required for TLS to work at all (https git clones,
#                        curl/wget over https, apt over https, etc.)
sudo chroot rootfs /bin/bash -c "apt update && apt install -y \
    git curl wget \
    vim nano \
    make build-essential \
    sudo \
    ssh \
    ca-certificates"
echo "==========================================="

echo "==========CONFIGURING OS_RELEASE=========="
sudo sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="GalactOS Ignition (beta-v1.0)"/' rootfs/etc/os-release
sudo sed -i 's|^NAME=.*|NAME="GalactOS GNU/Linux"|' rootfs/etc/os-release
echo 'ID_LIKE=debian' | sudo tee -a rootfs/etc/os-release > /dev/null
echo "============================================="

echo "==========SETTING LOGIN BANNER=========="
echo -e "GalactOS Ignition (beta-v1.0) \n \l" | sudo tee rootfs/etc/issue > /dev/null
echo "=========================================="

echo "==========CREATING DISK IMAGE=========="
qemu-img create -f raw galactos.img 2G

echo "==========PARTITIONING=========="
sudo fdisk galactos.img << EOF
n
p
1


a
w
EOF

echo "==========SETTING UP LOOP DEVICE=========="
sudo losetup -Pf galactos.img
LOOPDEV=$(losetup -j galactos.img | cut -d: -f1)

echo "==========FORMATTING PARTITION=========="
sudo mkfs.ext4 ${LOOPDEV}p1

echo "==========GENERATING FSTAB=========="
ROOT_UUID=$(sudo blkid -s UUID -o value ${LOOPDEV}p1)
echo "UUID=${ROOT_UUID}  /  ext4  errors=remount-ro  0  1" | sudo tee rootfs/etc/fstab > /dev/null
echo "====================================="

echo "==========MOUNTING AND COPYING ROOTFS=========="
sudo mkdir -p /mnt/galactos
sudo mount ${LOOPDEV}p1 /mnt/galactos
sudo cp -a rootfs/. /mnt/galactos/

echo "==========INSTALLING KERNEL + BOOTLOADER=========="
sudo mount --bind /dev /mnt/galactos/dev
sudo mount --bind /proc /mnt/galactos/proc
sudo mount --bind /sys /mnt/galactos/sys
sudo chroot /mnt/galactos /bin/bash -c "apt update && apt install -y linux-image-amd64 grub-pc && ln -sf /lib/systemd/systemd /usr/sbin/init && grub-install ${LOOPDEV} && update-grub"
echo "===================================="

echo "==========CONFIGURING SERVICES=========="
# Disables SSH on boot. The user can start/enable it later using systemctl.
# Note: In Debian, the ssh server service is named 'ssh', not 'sshd'.
sudo chroot /mnt/galactos /bin/bash -c "systemctl disable ssh"
echo "========================================"

echo "==========INSTALLING NOVA=========="
NOVA_BINARY_PATH="$HOME/dev/nova/nova"
if [ -f "$NOVA_BINARY_PATH" ]; then
    sudo cp "$NOVA_BINARY_PATH" /mnt/galactos/usr/local/bin/nova
    sudo chmod +x /mnt/galactos/usr/local/bin/nova
    echo "nova binary installed to /usr/local/bin/nova"
else
    echo "WARNING: nova binary not found at $NOVA_BINARY_PATH — skipping nova install"
    echo "Build it first with: cd ~/dev/nova && go build -o nova ."
fi
echo "===================================="

echo "==========SETTING ROOT PASSWORD=========="
read -sp "Enter root password for this GalactOS image: " ROOTPASS
echo
sudo chroot /mnt/galactos /bin/bash -c "echo 'root:${ROOTPASS}' | chpasswd"
unset ROOTPASS
echo "==========================================="

# TODO(next design decision): no non-root user is created yet, so `sudo`
# currently has nothing to do. Needs its own discussion: default username,
# password policy (prompt at build time vs. set on first boot), whether the
# user is added to the sudo group automatically, etc. Don't silently decide
# this in a script edit — it's a real security/UX call.

echo "==========CONFIGURING GRUB CONSOLE OUTPUT=========="
sudo chroot /mnt/galactos /bin/bash -c "
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/' /etc/default/grub
  sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=ttyS0,115200n8\"/' /etc/default/grub
  echo 'GRUB_TERMINAL=\"console serial\"' >> /etc/default/grub
  echo 'GRUB_SERIAL_COMMAND=\"serial --speed=115200 --unit=0\"' >> /etc/default/grub
  update-grub
"
echo "===================================================="

echo "==========CLEANING APT CACHE=========="
# Strips downloaded .deb archives and package index lists from the final
# image. This runs last (right before unmount) so it catches every apt
# install done above, in both chroot passes.
sudo chroot /mnt/galactos /bin/bash -c "apt clean && rm -rf /var/lib/apt/lists/*"
echo "========================================"

echo "==========CLEANUP=========="
sudo umount /mnt/galactos/dev
sudo umount /mnt/galactos/proc
sudo umount /mnt/galactos/sys
sudo umount /mnt/galactos
sudo losetup -d ${LOOPDEV}

echo "===================="
echo "|EXECUTION SUCCESSFUL|"
echo "===================="
