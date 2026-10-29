# Understanding the GalactOS Installer

This guide explains in plain language how the GalactOS installer works under the hood, how a live operating system transfers itself onto a physical hard drive, concrete configuration examples, and current known architectural gaps.

---

## 1. Core Concepts: From Live Media to Real Disk

### How the Live ISO Works
When you boot the GalactOS ISO:
1. The kernel and initramfs load from the boot medium into computer memory (RAM).
2. The initramfs mounts the compressed filesystem (`filesystem.squashfs`) from the ISO as a read-only block device.
3. Using an **overlay filesystem** (`overlayfs`), the kernel creates a writable RAM disk on top of the read-only SquashFS.
4. Any changes you make during the live session (creating files, changing passwords) exist only in volatile RAM and vanish upon power off.

```
+----------------------------------------------------+
|               Writable RAM Overlay                 |  <-- Temporary changes live here
+----------------------------------------------------+
|          Read-Only Compressed SquashFS             |  <-- Compressed base system from ISO
+----------------------------------------------------+
```

### Why a Shell Script Installer?
Many Linux distributions ship large graphical installers (such as Calamares or Ubiquity) that require heavy Python/Qt dependencies, background D-Bus daemons, and complex state machines.

GalactOS deliberately uses a straightforward Bash script (`iso/installer/galactos-install`):
- **Transparency**: Every step (partitioning, formatting, file copying, bootloader setup) is readable plain bash with zero hidden abstractions.
- **Reliability**: Uses battle-tested standard Linux CLI tools (`sgdisk`, `mkfs.ext4`, `rsync`, `grub-install`).
- **Low Footprint**: Does not require hundreds of megabytes of Python/Qt graphical frameworks just to copy files to a drive.

### Why Whole-Disk GPT and Hybrid Boot?
Older PCs use **legacy BIOS** (which historically required MBR partition tables). Modern PCs use **UEFI** (which requires GPT partition tables and an EFI System Partition).

GalactOS implements a hybrid GPT scheme:
- A 1 MB **BIOS Boot Partition** (`ef02`) allows legacy BIOS machines to boot from GPT disks without MBR restrictions.
- A 512 MB **EFI System Partition** (`ef00`) allows UEFI machines to boot standard 64-bit EFI binaries.
- The same installed disk will boot regardless of whether the computer's motherboard is set to Legacy BIOS or UEFI.

---

## 2. Under the Hood: Step-by-Step Installation Lifecycle

```
[1. Pre-flight Checks] ──> [2. Select & Wipe Disk] ──> [3. Create GPT Layout]
                                                              │
[6. Configure Identity] <── [5. Rsync System Files] <─── [4. Format Partitions]
         │
[7. Create User Account] ──> [8. Dual GRUB Install] ──> [9. Finish & Reboot]
```

### Step 1: Safety & Environment Checks
The installer ensures it is running inside the live ISO (`/run/live/medium`), checks for root privileges, and verifies that all essential disk tools (`sgdisk`, `mkfs.ext4`, `rsync`, `wipefs`, etc.) exist.

### Step 2: Drive Selection & Safe Exclusion
The script lists all connected disks and their capacities. Crucially, it finds the block device hosting `/run/live/medium` and excludes it from the list so you cannot accidentally overwrite the USB stick or virtual CD drive you are running from. It also refuses drives smaller than 12 GB (`12000000000` bytes).

### Step 3: Complete Disk Erasure
Once you confirm the disk name, `wipefs -af` erases all filesystem headers, and `sgdisk --zap-all` clears the GPT and MBR tables.

### Step 4: Partitioning & Formatting
Three partitions are created:
1. `TARGET1`: 1 MB unformatted raw BIOS boot partition.
2. `TARGET2`: 512 MB formatted as FAT32 (`mkfs.fat -F32 -n EFI`).
3. `TARGET3`: Remaining disk space formatted as ext4 (`mkfs.ext4 -L galactos`).

### Step 5: System Transfer (`rsync`)
The ext4 partition is mounted to `/mnt/galactos-target`. The installer then runs `rsync -aAX` to copy the live root filesystem `/` directly into `/mnt/galactos-target`. It explicitly excludes ephemeral mounts (`/proc`, `/sys`, `/dev`, `/run`, `/tmp`, `/mnt`), the temporary live user's home folder (`/home/galactos`), and live-specific fstab.

### Step 6: Machine Identity Generation
Every computer needs unique identity strings. The installer:
- Discovers partition UUIDs and generates a clean `/etc/fstab`.
- Writes your chosen hostname to `/etc/hostname` and `/etc/hosts`.
- Resets `/etc/machine-id` so systemd assigns a fresh machine ID on first boot.
- Purges existing SSH host keys and generates new ones with `ssh-keygen -A`.

### Step 7: User Provisioning
The temporary live account `galactos` is removed (`userdel -rf galactos`). Your chosen personal account is created with `useradd` and added to `sudo`, `audio`, and `video` groups. The root password is locked (`passwd -l root`), so all administrative tasks must be performed via `sudo`.

### Step 8: Bootloader Installation
The `live-boot` package is purged from the target disk and `update-initramfs` is called so the initrd does not look for an ISO on startup. Then GRUB is installed twice:
- `grub-install --target=i386-pc` writes to the 1 MB BIOS boot partition.
- `grub-install --target=x86_64-efi --removable` writes `BOOTX64.EFI` to the EFI partition.

---

## 3. Concrete Examples

### Installed `/etc/fstab` Example
On an installed system, `/etc/fstab` maps disk partitions by UUID rather than device names (`/dev/sda`), ensuring reliable mounting even if drive letters change:

```fstab
UUID=e7c84b12-92f1-4b71-b841-f8e2197d10a2  /          ext4  errors=remount-ro  0  1
UUID=4A1F-8C3D                              /boot/efi  vfat  umask=0077         0  2
```

### GRUB Dual Boot Configuration
During boot, the machine's hardware determines which path is used:
- **On a legacy BIOS PC**: The BIOS reads the Master Boot Record (MBR) and executes the GRUB core located in Partition 1 (`biosboot`).
- **On a UEFI PC**: The UEFI firmware scans the FAT32 EFI partition (Partition 2) for `/EFI/BOOT/BOOTX64.EFI` and executes it directly.

Both paths read `/boot/grub/grub.cfg` on the ext4 partition to launch the Linux kernel (`/vmlinuz`) with the root filesystem UUID.

---

## 4. Known Gaps

The installer is focused and minimalist, which introduces several current limitations:

1. **Whole-Disk Installation Only**:
   - The installer does not support manual partitioning, resizing existing partitions, or dual-booting side-by-side with Windows or another Linux distro. It formats the entire selected drive.
2. **No Swap Space**:
   - The installer creates only EFI and ext4 root partitions. It does not create a swap partition or a swapfile (`/swapfile`). Systems needing swap for hibernation or memory pressure must configure a swapfile post-install.
3. **No Full Disk Encryption (LUKS)**:
   - Partition 3 is formatted as plain ext4. There is no LUKS / dm-crypt container option for disk encryption.
4. **Timezone & Locale Hardcoded Defaults**:
   - The installer does not prompt for your timezone or keyboard layout. It defaults to UTC timezone and `en_US.UTF-8` locale (can be changed post-install with `timedatectl` and `dpkg-reconfigure locales`).
5. **CLI Only**:
   - The installer runs exclusively inside a terminal emulator; there is no graphical wizard.
