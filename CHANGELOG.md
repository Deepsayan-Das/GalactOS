# Changelog

All notable changes to the GalactOS project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-27

### Added
- **Base Distribution & Scaffolding**:
  - Debian stable (`minbase`) scaffolding via `debootstrap` with official Debian repositories (`deb.debian.org`).
  - Branded OS release identification (`GalactOS 1.0 (Ignition)` / `GalactOS GNU/Linux`) in `/etc/os-release` and `/etc/issue`.
  - Linux amd64 kernel (`linux-image-amd64`) and `systemd-sysv` init system.
- **Developer Tooling & Baseline Packages**:
  - Out-of-the-box installation of the `nova` CLI and `orbit` AI coding assistant via dedicated GPG-signed APT repository (`https://deepsayan-das.github.io/nova`).
  - Essential baseline development tools: `git`, `curl`, `wget`, `vim`, `make`, `build-essential`, `sudo`, `ssh`, `ca-certificates`, `fdisk`, `e2fsprogs`, and `rsync`.
  - Modern terminal and CLI stack (`packages-extra.txt`): `fish`, `tmux`, `fzf`, `ripgrep`, `fd-find` (symlinked as `fd`), `bat` (symlinked as `bat`), `jq`, `htop`, `btop`, `tree`, `bash-completion`.
  - Developer environments and runtime utilities: `python3-pip`, `python3-venv`, `pipx`, `cmake`, `gdb`, `shellcheck`, `sqlite3`, `gh`, `git-lfs`, `nodejs`, `npm`, `golang-go`, `podman`, `podman-compose`.
- **Desktop Graphical User Interface**:
  - Lightweight X11 desktop environment based on Openbox window manager.
  - Custom `GalactOS-Dark` Openbox theme with monochrome XBM window control buttons.
  - LightDM display manager integrated with Web-Greeter 4.0.0 and custom HTML/CSS/JavaScript `galactos` theme.
  - `picom` compositor configuration for smooth shadows, fading transitions, and tear-free display.
  - `polybar` top status bar and `tint2` bottom taskbar dock.
  - `rofi` dual integration: application menu launcher (`launcher.rasi`) and sidebar system control center (`sidebar.sh` / `sidebar.rasi`).
  - Default terminal emulator: `alacritty` with JetBrains Mono font.
  - Pre-installed productivity and desktop apps: `firefox-esr`, `pcmanfm`, `gedit`, `libreoffice` (writer, calc, impress), `atril`, `ristretto`, `xarchiver`, `galculator`, `mpv`, `dunst`, and `lxpolkit`.
  - Curated desktop keybindings: `Ctrl+Alt+T` for terminal, `Super+Space` for application launcher, `Super+E` for file manager.
  - User session defaults populated via `/etc/skel/`.
- **Live ISO Pipeline & Build System**:
  - Modular ISO build scripts in `iso/`: `build-rootfs.sh`, `build-gui.sh`, `build-system.sh`, and `build-iso.sh`.
  - Automated build orchestrator `iso/make_iso.sh` supporting versioning (`./make_iso.sh <version>`), pre-flight checks, layer refresh, and SHA256 integrity verification.
  - Standalone QEMU raw disk image builder script (`build.sh`) producing `galactos.img`.
- **System Installer (`galactos-install`)**:
  - Live system-to-disk installer script supporting both BIOS and UEFI boot firmware.
  - Whole-disk GPT partitioning (1 MB BIOS boot partition, 512 MB EFI System Partition, and ext4 root partition).
  - Live filesystem transfer using `rsync -aAX`.
  - Machine identity generation (`/etc/fstab` UUID mapping, hostname, machine ID reset, fresh SSH host keys).
  - Interactive user account creation and root password locking.
  - Dual bootloader installation: `grub-install` for `i386-pc` and for `x86_64-efi` with `--removable`, using the `grub-pc-bin` and `grub-efi-amd64-bin` packages, after rebuilding the initramfs.
- **Continuous Integration (CI)**:
  - GitHub Actions CI workflow (`.github/workflows/ci.yml`) targeting Ubuntu 24.04 runners.
  - Three automated validation jobs: shell script syntax verification (`bash -n` and `shellcheck --severity=error`), repository hygiene enforcement (blocking binary artifacts, oversized files >5 MB, and API key patterns), and Debian packaging checks (`sh -n` and `control` file validation).

### Download

- The release ISO is distributed as three 7-Zip split parts attached to the [GitHub Release page](https://github.com/Deepsayan-Das/GalactOS/releases/tag/v1.0.0):
  - `galactos-1.0.0-amd64.iso.7z.001` (~1 GB)
  - `galactos-1.0.0-amd64.iso.7z.002` (~1 GB)
  - `galactos-1.0.0-amd64.iso.7z.003` (~1 GB)
  - `SHA256SUMS.txt` — SHA-256 checksums for the three archive parts.
- **Upload in progress**: parts are not yet attached to the release; until complete, build from source with `./iso/make_iso.sh`.
- To verify the parts on Windows: `Get-FileHash <file> -Algorithm SHA256`; on Linux: `sha256sum -c SHA256SUMS.txt`.
- To extract on Windows, open `galactos-1.0.0-amd64.iso.7z.001` with 7-Zip; on Linux: `7z x galactos-1.0.0-amd64.iso.7z.001` (package `p7zip-full`).
- SHA-256 of the extracted ISO: `942af2aac67a379ad363fd684c4a668739b503a1bc9c21f61b90129731fd87eb`.
