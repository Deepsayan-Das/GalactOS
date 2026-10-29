# GalactOS Installer Architecture & Reference

This document explains the technical architecture, partitioning scheme, system transfer mechanism, and bootloader configuration implemented by `iso/installer/galactos-install`.

The GalactOS installer is a dedicated shell script (`#!/bin/bash`) designed to run within the GalactOS Live environment. It deploys the running live environment onto a physical or virtual hard drive for persistent whole-disk installation.

---

## 1. Prerequisites and Invocation

The installer must be run with elevated privileges from an active live session:

```bash
sudo galactos-install
```

### Pre-flight Safety Checks
1. **Live Environment Detection**: Checks for `/run/live/medium`. If this directory does not exist, the script terminates immediately (`"run this from the GalactOS live ISO"`).
2. **Tooling Verification**: Checks for all required system binaries:
   - `sgdisk`: GPT partition management
   - `mkfs.fat` & `mkfs.ext4`: Filesystem formatting
   - `rsync`: Synchronizing live root filesystem to the target disk
   - `wipefs`: Erasing filesystem signatures
   - `lsblk` & `blkid`: Block device discovery and UUID queries
   - `grub-install`: Bootloader installation for BIOS and UEFI
3. **Firmware Detection**: Inspects `/sys/firmware/efi` to determine whether the host firmware is currently running in UEFI mode or legacy BIOS mode. Note that the installer installs bootloaders for **both** architectures regardless of current boot mode.

---

## 2. Disk Discovery, Validation, and Erasure

### Disk Filtering
The script enumerates block devices of type `disk` using `lsblk -dpno NAME,TYPE`.
- Ignores RAM-based devices (`/dev/zram*`).
- Identifies and excludes the boot drive currently mounted at `/run/live/medium` (`LIVE_DISK`), preventing the installer from overwriting its own boot media.

### Minimum Drive Size Check
- Requires a disk with at least **12,000,000,000 bytes** (~12 GB / 11.17 GiB), checked via:
  ```bash
  SIZE_B=$(blockdev --getsize64 "$TARGET")
  [ "$SIZE_B" -ge 12000000000 ] || die "$TARGET is too small (need at least 12 GB)"
  ```
- Verifies that no partitions on the target drive are currently mounted.

### What is Wiped
The installer performs a **destructive whole-disk wipe**:
1. `wipefs -af "$TARGET"`: Wipes all existing filesystem, RAID, and partition-table signatures from the drive.
2. `sgdisk --zap-all "$TARGET"`: Completely wipes MBR and GPT partition structures and backup tables.

> [!WARNING]
> All existing data, operating systems, and partitions on the selected drive are permanently erased. GalactOS currently does not support dual-booting or resizing existing partitions.

---

## 3. Partitioning Scheme (GPT)

The installer establishes a GUID Partition Table (GPT) layout with three dedicated partitions:

```
+-------------------------------------------------------------------------------+
| Partition 1 (1 MB)      | Partition 2 (512 MB)     | Partition 3 (Rest of disk)|
| Type: ef02 (BIOS Boot)  | Type: ef00 (EFI System)  | Type: 8300 (Linux ext4)  |
| Label: biosboot         | Label: EFI (FAT32)       | Label: galactos (ext4)   |
| No filesystem           | Mounted: /boot/efi       | Mounted: /               |
+-------------------------------------------------------------------------------+
```

### Partition Definitions
1. **Partition 1: BIOS Boot Partition (`biosboot`)**
   - **Size**: 1 MB (`+1M`)
   - **Type code**: `ef02`
   - **Purpose**: Provides raw unformatted disk space for GRUB core (`core.img`) when booting via legacy BIOS on a GPT-partitioned disk.
   - Command: `sgdisk -n1:0:+1M -t1:ef02 -c1:biosboot "$TARGET"`
2. **Partition 2: EFI System Partition (`EFI`)**
   - **Size**: 512 MB (`+512M`)
   - **Type code**: `ef00`
   - **Filesystem**: FAT32 (`mkfs.fat -F32 -n EFI`)
   - **Mount point**: `/boot/efi`
   - **Purpose**: Holds UEFI bootloaders, including the fallback boot binary (`BOOTX64.EFI`).
   - Command: `sgdisk -n2:0:+512M -t2:ef00 -c2:EFI "$TARGET"`
3. **Partition 3: Root Filesystem (`GalactOS`)**
   - **Size**: Remaining available space (`0:0`)
   - **Type code**: `8300`
   - **Filesystem**: ext4 (`mkfs.ext4 -F -q -L galactos`)
   - **Mount point**: `/`
   - **Purpose**: Root operating system, installed files, and user home directories.
   - Command: `sgdisk -n3:0:0 -t3:8300 -c3:GalactOS "$TARGET"`

---

## 4. System Transfer Mechanism

The target root filesystem is mounted at `/mnt/galactos-target`, and the EFI partition is mounted at `/mnt/galactos-target/boot/efi`.

The installer synchronizes the live system using `rsync` with preservation of attributes, ACLs, and extended attributes (`-aAX`):

```bash
rsync -aAX --info=progress2 --no-inc-recursive \
    --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' --exclude='/run/*' \
    --exclude='/tmp/*' --exclude='/mnt/*' --exclude='/lost+found' \
    --exclude='/home/galactos' --exclude='/etc/fstab' \
    / "$T/"
```

### Exclusions & Post-Copy Creation
- Pseudo and virtual filesystems (`/proc`, `/sys`, `/dev`, `/run`, `/tmp`, `/mnt`) are excluded and recreated with correct directory permissions (e.g. `chmod 1777 /tmp`).
- The live user home directory (`/home/galactos`) and live `/etc/fstab` are excluded.
- If `/boot/vmlinuz-*` is not present in the system root (as in older ISO layouts), the installer copies the active kernel and initrd directly from `/run/live/medium/boot/`.

---

## 5. Machine Identity Configuration

The installer provisions a unique identity for the new machine:
1. **`/etc/fstab` Generation**: Discovers partition UUIDs using `blkid` and configures persistent mounts:
   ```fstab
   UUID=<ROOT_UUID>  /          ext4  errors=remount-ro  0  1
   UUID=<ESP_UUID>   /boot/efi  vfat  umask=0077         0  2
   ```
2. **Hostname & Hosts**: Prompts for hostname (default `galactos`) and writes to `/etc/hostname` and `/etc/hosts` (`127.0.1.1 <hostname>`).
3. **Machine ID**: Truncates `/etc/machine-id` (`: > /etc/machine-id`) to force systemd to regenerate a unique machine ID on first boot.
4. **SSH Host Keys & Entropy**: Deletes existing host keys (`/etc/ssh/ssh_host_*`) and random seed (`/var/lib/systemd/random-seed`). Fresh SSH host keys are generated inside chroot via `ssh-keygen -A`.

---

## 6. User Account Creation

Inside the target chroot:
1. Deletes the temporary live account:
   ```bash
   userdel -rf galactos >/dev/null 2>&1 || true
   ```
2. Prompts interactively for the primary username and password.
3. Creates the user with a home directory and default `/bin/bash` shell, assigned to `sudo`, `audio`, and `video` groups:
   ```bash
   useradd -m -s /bin/bash -G sudo,audio,video "$NEWUSER"
   ```
4. Locks the root account (`passwd -l root`), enforcing user privilege escalation via `sudo`.

---

## 7. Dual Bootloader Installation

To ensure portability across any computer or VM, rather than relying on conflicting meta-packages (`grub-pc + grub-efi-amd64`), GalactOS implements the actual method: `grub-install` for `i386-pc` and for `x86_64-efi` with `--removable`, using the `grub-pc-bin` and `grub-efi-amd64-bin` packages, after rebuilding the initramfs:

1. **Purge live-boot**:
   Removes `live-boot` and `live-boot-initramfs-tools` so the system boots directly from rootfs rather than looking for a live squashfs medium. Rebuilds initramfs:
   ```bash
   apt-get remove --purge -y live-boot live-boot-initramfs-tools
   update-initramfs -u -k all
   ```
2. **Configure `/etc/default/grub`**:
   Sets `GRUB_DEFAULT=0`, `GRUB_TIMEOUT=3`, `GRUB_DISTRIBUTOR="GalactOS"`, and `GRUB_CMDLINE_LINUX_DEFAULT="quiet"`.
3. **BIOS Bootloader**:
   ```bash
   grub-install --target=i386-pc --recheck "$TARGET"
   ```
   Embeds GRUB core into the 1 MB BIOS boot partition (Partition 1).
4. **UEFI Bootloader**:
   ```bash
   grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
   ```
   Uses `--removable` to write the standard UEFI fallback binary:
   `/boot/efi/EFI/BOOT/BOOTX64.EFI`.
   This ensures bootability on UEFI systems even without firmware NVRAM boot entries.
5. **Generate Menu**:
   Executes `update-grub` and verifies that `vmlinuz` is referenced in `/boot/grub/grub.cfg` and `BOOTX64.EFI` exists.
