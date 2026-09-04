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

echo "==========GETTING DEPENDENCIES=========="
sudo chroot rootfs /bin/bash -c "apt update && apt install -y vim"
echo "==========================================="

echo "==========CONFIGURING OS_RELEASE=========="
sudo sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="GalactOS Ignition (beta-v1.0)"/' rootfs/etc/os-release
sudo sed -i 's|^NAME=.*|NAME="GalactOS GNU/Linux"|' rootfs/etc/os-release
echo 'ID_LIKE=debian' | sudo tee -a rootfs/etc/os-release > /dev/null
echo "============================================="

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

echo "==========MOUNTING AND COPYING ROOTFS=========="
sudo mkdir -p /mnt/galactos
sudo mount ${LOOPDEV}p1 /mnt/galactos
sudo cp -a rootfs/. /mnt/galactos/

echo "==========INSTALLING KERNEL + BOOTLOADER=========="
sudo mount --bind /dev /mnt/galactos/dev
sudo mount --bind /proc /mnt/galactos/proc
sudo mount --bind /sys /mnt/galactos/sys
sudo chroot /mnt/galactos /bin/bash -c "apt update && apt install -y linux-image-amd64 grub-pc && ln -sf /lib/systemd/systemd /usr/sbin/init && grub-install ${LOOPDEV} && update-grub"

echo "==========CONFIGURING GRUB CONSOLE OUTPUT=========="
sudo chroot /mnt/galactos /bin/bash -c "
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/' /etc/default/grub
  sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=ttyS0,115200n8\"/' /etc/default/grub
  echo 'GRUB_TERMINAL=\"console serial\"' >> /etc/default/grub
  echo 'GRUB_SERIAL_COMMAND=\"serial --speed=115200 --unit=0\"' >> /etc/default/grub
  update-grub
"
echo "===================================================="

echo "==========CLEANUP=========="
sudo umount /mnt/galactos/dev
sudo umount /mnt/galactos/proc
sudo umount /mnt/galactos/sys
sudo umount /mnt/galactos
sudo losetup -d ${LOOPDEV}

echo "===================="
echo "|EXECUTION SUCCESSFUL|"
echo "===================="

