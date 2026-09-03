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

echo "===================="
echo "|EXECUTION SUCCESSFUL|"
echo "===================="
