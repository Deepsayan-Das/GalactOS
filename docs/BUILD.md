# Building GalactOS

This guide covers building GalactOS from source. GalactOS provides two build paths:
1. **The Live ISO pipeline (`iso/`)**: Builds a bootable hybrid ISO (`galactos-gui-v<version>.iso`) containing the full desktop GUI, developer toolchain, and the interactive installer.
2. **The Direct Disk Image script (`build.sh`)**: A legacy/standalone script that directly creates a 2 GB raw virtual disk image (`galactos.img`) for quick headless QEMU testing.

> [!IMPORTANT]
> `build.sh` and `iso/build-rootfs.sh` are separate implementations. `build.sh` does not call or share `iso/build-rootfs.sh`; it performs its own independent `debootstrap` pass to construct a minimal disk image.

---

## 1. System Requirements & Host Dependencies

Building GalactOS requires a Debian or Ubuntu 64-bit host (or WSL2 with Ubuntu).

### Hardware Requirements
- **Disk Space**:
  - At least **4 GB free space** in the build directory (`make_iso.sh` enforces `LOCAL_FREE > 4000 MB`).
  - At least **3 GB free space** in the destination directory (`make_iso.sh` enforces `DEST_FREE > 3000 MB`).
- **RAM**: At least 4 GB RAM recommended for SquashFS compression.
- **Privileges**: Passwordless or active `sudo` access (the build pipeline mounts filesystems and invokes `debootstrap` and `chroot`).

### Required Host Packages
Install the required tools with `apt`:

```bash
sudo apt update
sudo apt install -y \
    debootstrap \
    xorriso \
    squashfs-tools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    curl \
    wget \
    rsync \
    git
```

> [!NOTE]
> `make_iso.sh` explicitly verifies the presence of `/usr/lib/grub/x86_64-efi` on the host to ensure the resulting ISO can boot on UEFI firmware.

---

## 2. Building the Live ISO Pipeline (`iso/`)

The ISO build pipeline is structured in modular layers inside `iso/`:

```
iso/
├── build-rootfs.sh      # Base rootfs creation: debootstrap, baseline tools, Nova & Orbit repo, kernel
├── build-gui.sh         # GUI stack: Xorg, Openbox, Web-Greeter, Polybar, Alacritty, Picom, themes
├── build-system.sh      # System stack: packages-extra.txt, locales, /etc/skel, live user
├── build-iso.sh         # ISO packaging: mksquashfs, GRUB bootloader, grub-mkrescue
├── make_iso.sh          # Orchestrator: pre-flight checks, layer refresh, verification, copy
├── grub/grub.cfg        # Live ISO boot menu
├── gui/
│   ├── assets/          # Config files, themes, icons, keybindings
│   ├── greeter-theme/   # HTML/CSS/JS theme for web-greeter
│   └── packages-extra.txt # Extended package list
└── installer/
    └── galactos-install # Live system-to-disk installer script
```

### Full Automated Build with `make_iso.sh`

The primary tool for building release ISOs is `iso/make_iso.sh`:

```bash
cd iso
./make_iso.sh <version> [--no-gui] [--rootfs DIR] [--force]
```

#### Arguments, Flags, and Environment Variables
- `<version>`: Version identifier (e.g. `26` or `1.0.0`), used to name the output ISO: `galactos-gui-v<version>.iso`.
- `--no-gui`: Skips `build-gui.sh` and `build-system.sh` during the run.
- `--rootfs <DIR>`: Specifies an alternative rootfs directory (defaults to `live-rootfs`).
- `--force`: Overwrites existing ISOs in the current directory and the destination path.
- `ISO_DEST`: Environment variable to override the destination directory where the final ISO is copied and verified (defaults to `/mnt/d/vbox-gui-iso`). Example:
  ```bash
  ISO_DEST=/path/to/custom-dir ./make_iso.sh 26
  ```

#### What `make_iso.sh` Executes Step-by-Step
1. **Pre-flight checks**:
   - Confirms that `$ROOTFS` exists.
   - Checks that the destination directory exists and is writable (defaults to `/mnt/d/vbox-gui-iso` for WSL/VirtualBox setups, or the path configured via `ISO_DEST`).
   - Verifies that no child mounts exist under the rootfs (`findmnt`).
   - Verifies disk space limits (>4 GB local, >3 GB destination).
   - Verifies host UEFI GRUB binaries (`/usr/lib/grub/x86_64-efi`).
2. **Layer refresh**:
   - Invokes `sudo ./build-gui.sh "$ROOTFS"`.
   - Invokes `sudo ./build-system.sh "$ROOTFS"`.
3. **Installer and DNS installation**:
   - Copies `installer/galactos-install` to `$ROOTFS/usr/local/bin/galactos-install` with executable permissions (`0755`).
   - Configures `$ROOTFS/etc/resolv.conf` with `nameserver 8.8.8.8`.
4. **Integrity checks**:
   - Verifies the presence of key files in the rootfs:
     - `usr/share/web-greeter/themes/galactos/index.html`
     - `etc/lightdm/lightdm.conf.d/60-web-greeter.conf`
     - `root/.config/openbox/rc.xml`
     - `root/.config/openbox/menu.xml`
     - `root/.config/picom/picom.conf`
     - `root/.config/polybar/config.ini`
     - `root/.config/tint2/tint2rc`
     - `root/.config/alacritty/alacritty.toml`
     - `usr/bin/orbit`, `usr/local/bin/orbit-launch`, `usr/share/applications/orbit.desktop`
5. **ISO generation**:
   - Calls `sudo ./build-iso.sh "$ROOTFS" iso "$ISO"`.
   - Compresses the rootfs into `iso/live/filesystem.squashfs` with `mksquashfs`.
   - Copies `vmlinuz-*` and `initrd.img-*` to `iso/boot/`.
   - Invokes `grub-mkrescue` to build the hybrid BIOS/UEFI bootable ISO.
6. **Checksum verification and copy**:
   - Copies `$ISO` to the destination directory.
   - Computes and compares SHA256 hashes between source and target to confirm data integrity.

---

### Step-by-Step Manual Build

If you are developing a specific component, you can run the build stages individually:

#### 1. Bootstrap the Root Filesystem
```bash
cd iso
sudo ./build-rootfs.sh live-rootfs
```
This runs `debootstrap --variant=minbase stable`, installs core packages (`git`, `curl`, `wget`, `vim`, `make`, `build-essential`, `sudo`, `ssh`, `ca-certificates`, `fdisk`, `e2fsprogs`, `rsync`), adds the GalactOS APT repository (`https://deepsayan-das.github.io/nova`), installs `nova` and `orbit`, installs the Debian Linux kernel (`linux-image-amd64`) and `live-boot`, runs `build-gui.sh` and `build-system.sh`, and sets the initial root password.

#### 2. Refresh the GUI Stack
```bash
sudo ./build-gui.sh live-rootfs
```
Installs Xorg, Openbox, Web-Greeter 4.0.0, Papirus-Dark icons, Arc-Dark theme, Polybar, Tint2, Alacritty, Picom, and copies all configs from `iso/gui/assets/` and the greeter theme from `iso/gui/greeter-theme/`.

#### 3. Refresh the System Configuration Layer
```bash
sudo ./build-system.sh live-rootfs
```
Installs additional packages listed in `iso/gui/packages-extra.txt`, generates `en_US.UTF-8` locale, sets hostname to `galactos`, copies shared assets to `/usr/share/galactos/`, inserts Openbox keybindings into `rc.xml`, populates `/etc/skel/`, creates the live user `galactos:galactos` (member of `sudo`, `audio`, `video`), and disables SSH daemon startup.

#### 4. Bundle Installer & Produce ISO
```bash
# Add installer script
sudo cp installer/galactos-install live-rootfs/usr/local/bin/galactos-install
sudo chmod +x live-rootfs/usr/local/bin/galactos-install

# Package the ISO
sudo ./build-iso.sh live-rootfs iso galactos-live.iso
```

---

## 3. Building the Standalone QEMU Disk Image (`build.sh`)

For local headless testing in QEMU without live ISO booting:

```bash
chmod +x build.sh
./build.sh
```

### What `build.sh` does:
1. Installs `debootstrap` on the host.
2. Bootstraps Debian stable into `./rootfs`.
3. Installs baseline packages (`git`, `curl`, `wget`, `vim`, `nano`, `make`, `build-essential`, `sudo`, `ssh`, `ca-certificates`).
4. Sets OS identity to `GalactOS 1.0 (Ignition)` in `/etc/os-release` and `/etc/issue`.
5. Creates a 2 GB raw image file: `galactos.img`.
6. Partitions the image with MBR (single bootable ext4 partition).
7. Sets up loopback device (`losetup`), formats ext4, mounts at `/mnt/galactos`.
8. Copies `./rootfs` into `/mnt/galactos`.
9. Chroots into the image to install Linux kernel (`linux-image-amd64`), systemd, GRUB (`grub-pc`), and prompts for a root password.
10. Configures serial console output in `/etc/default/grub` (`console=ttyS0,115200n8`) and updates GRUB.
11. Cleans APT caches and unmounts loop devices.

Run the resulting image with QEMU:
```bash
qemu-system-x86_64 -hda galactos.img -m 2048 -nographic
```

---

## 4. Orbit Packaging (`iso/packaging/orbit/`)

Orbit is packaged as a Debian package (`.deb`) using `iso/packaging/orbit/build-orbit-deb.sh`.

- Requires an existing Debian chroot (defaults to `/var/chroot/trixie-build`).
- Syncs Orbit source tree, runs Python unit tests inside the chroot, scans for secret patterns, and bundles `orbit` and `orbit-configure` into `/usr/bin/` with metadata defined in `iso/packaging/orbit/control`.
