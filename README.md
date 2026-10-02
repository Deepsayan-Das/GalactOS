# GalactOS

A developer-first, Debian-based Linux distribution, built from scratch via
a documented, reproducible pipeline — not a repack of an existing distro.

GalactOS ships [`nova`](https://github.com/Deepsayan-Das/nova), a custom
CLI for project/environment/container management, installed via a real,
GPG-signed apt repository rather than bundled as a binary.

## What's in this repo

```
build.sh              # Builds a complete, installed GalactOS disk image (.img)
iso/
  build-rootfs.sh       # Builds a branded, packaged rootfs (shared by build.sh's
                         # logic and the live ISO)
  build-iso.sh           # Packages a rootfs into a bootable live ISO
  grub/
    grub.cfg               # Live-boot GRUB configuration
  installer/
    galactos-install        # Installer script bundled into the live ISO;
                             # partitions a target disk and installs GalactOS onto it
```

## Option 1 — Build a disk image directly (`.img`)

For quick local testing in QEMU without a live/install flow:

```bash
chmod +x build.sh
./build.sh
```

Produces `galactos.img` — a complete, already-installed GalactOS disk,
bootable directly in QEMU:

```bash
qemu-system-x86_64 -hda galactos.img -m 2048
```

## Option 2 — Build a bootable live ISO + installer (VirtualBox)

This produces a real `.iso`: boot it, and it runs a temporary live
environment from which you can install GalactOS onto a real (virtual)
disk — the same two-stage flow real distro installers use.

### Prerequisites

```bash
sudo apt update
sudo apt install -y debootstrap xorriso squashfs-tools \
    grub-pc-bin grub-efi-amd64-bin mtools
```

### Build

```bash
cd iso

# 1. Build the rootfs (prompts for a root password near the end)
chmod +x build-rootfs.sh
./build-rootfs.sh live-rootfs

# 2. Add the installer script into the rootfs
sudo mkdir -p live-rootfs/usr/local/bin
sudo cp installer/galactos-install live-rootfs/usr/local/bin/galactos-install
sudo chmod +x live-rootfs/usr/local/bin/galactos-install

# 3. Build the ISO
chmod +x build-iso.sh
./build-iso.sh live-rootfs iso galactos-live.iso
```

This produces `iso/galactos-live.iso`.

### Boot and install (VirtualBox)

1. Create a VM: Linux, Debian 64-bit, **≥2048MB RAM**, a virtual hard disk
   (10-15GB is enough for a minimal install).
2. Attach `galactos-live.iso` as the optical drive.
3. Boot. At the GRUB menu, select **GalactOS Live**.
4. Log in as `root` with the password set during `build-rootfs.sh`.
5. **If the target disk has been used before** (e.g. a previous install
   attempt), wipe it first: `wipefs -a /dev/sda`.
6. Run the installer:
   ```bash
   galactos-install
   ```
   Follow the prompts — it will ask for the target disk name (e.g. `sda`,
   not `/dev/sda`) and a final `yes` confirmation before erasing it.
7. Once it prints "Install complete," power off the VM, **detach the ISO**
   from the optical drive, and boot again — GalactOS now boots directly
   from the virtual hard disk, independent of the ISO.

### Rebuilding after a change

If you edit `galactos-install`, you only need to re-copy it into the
rootfs and re-run `build-iso.sh` — no need to rebuild the whole rootfs
from scratch:

```bash
sudo cp installer/galactos-install live-rootfs/usr/local/bin/galactos-install
sudo chmod +x live-rootfs/usr/local/bin/galactos-install
./build-iso.sh live-rootfs iso galactos-live.iso
```

## Architecture notes

- **Universal baseline packages only** ship in the base image (git, curl,
  wget, vim, nano, build-essential, sudo, ssh, ca-certificates, fdisk,
  e2fsprogs, rsync, nova). Stack-specific tooling (Python, Node, Go, etc.)
  is intentionally left out — install via `nova install` instead.
- **`nova` is installed via a real apt repository**
  (`deepsayan-das.github.io/nova`), GPG-signed, the same way an end user
  installs it — not copied in as a special-cased binary.
- The live ISO's rootfs and the installed-image rootfs share the same
  `build-rootfs.sh`, so branding and package selection never drift between
  the two.
- Live-boot kernel/initrd are served from the ISO's own boot media
  (`/run/live/medium/boot/` at runtime) rather than baked into the
  compressed `filesystem.squashfs` — the installer explicitly copies them
  from there onto the target disk during install.

## Status

Live boot and VM-targeted install (VirtualBox) are working end-to-end.
Bare-metal installation support is a separate, not-yet-started effort —
this installer is scoped to VM disks only for now.