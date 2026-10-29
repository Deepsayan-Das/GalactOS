# Understanding the GalactOS Desktop GUI

This guide explains in plain language how the graphical user interface (GUI) of GalactOS is constructed, how its individual components work together, how to customize it, and current known gaps.

---

## 1. Core Architectural Concepts

Rather than shipping a heavy, monolithic desktop environment (like GNOME or KDE Plasma), GalactOS uses an ultra-lightweight, modular stack built around the **Openbox** window manager. 

This design choice provides:
- **Instant responsiveness**: Boot times and window operations use negligible CPU and RAM overhead.
- **Modularity**: Every component (login screen, window manager, compositor, status bar, dock, and app launcher) is an independent Unix tool that can be understood, modified, or replaced.
- **Developer focus**: Clear screen real estate, streamlined keyboard shortcuts, and full control over themes and configurations.

```
+-------------------------------------------------------------+
|                      Polybar (Top Bar)                      |
| Workspaces | Active Window Title | Clock | Volume | Battery |
+-------------------------------------------------------------+
|                                                             |
|                          Openbox                            |
|             (Window Management & Keybindings)               |
|                                                             |
|   +-----------------------------------------------------+   |
|   |         Alacritty / Firefox / PCManFM Window        |   |
|   |             (Composited with Picom)                 |   |
|   +-----------------------------------------------------+   |
|                                                             |
+-------------------------------------------------------------+
|               Tint2 (Bottom Dock / Taskbar)                 |
| Launcher Icon | Open Applications List | System Tray        |
+-------------------------------------------------------------+
```

---

## 2. Component Walkthrough

### 1. Display Manager: LightDM + Web-Greeter
When GalactOS boots, systemd starts **LightDM** (`lightdm`), which handles user authentication and session startup. Instead of the default GTK greeter, GalactOS configures **Web-Greeter 4.0.0** (`/etc/lightdm/lightdm.conf.d/60-web-greeter.conf`):
- **Web-Greeter** allows the login screen to be rendered using web technologies (HTML, CSS, JavaScript).
- The theme source is located in `iso/gui/greeter-theme/` and installed to `/usr/share/web-greeter/themes/galactos/`.
- It displays the GalactOS branding, user selection, and password authentication form.

### 2. Window Manager: Openbox
Once you log in, LightDM starts an X11 session running **Openbox**:
- Openbox manages window frames, borders, titlebars, window placement, virtual desktops, and keyboard/mouse shortcuts.
- **Theme**: GalactOS uses a custom theme called `GalactOS-Dark` (`/usr/share/themes/GalactOS-Dark/openbox-3/themerc`), with custom monochrome XBM window control buttons (close, minimize, maximize, shade) in `iso/gui/assets/xbm/`.
- **Fonts**: Configured to use `JetBrains Mono` for menu items and window titles.

### 3. Compositor: Picom
Openbox itself does not composite windows (it does not render transparency or drop shadows). GalactOS runs **Picom** in the background:
- Configured in `/usr/share/galactos/picom/picom.conf` (with user override support in `~/.config/picom/picom.conf`).
- Provides smooth window shadows, inactive window dimming, subtle fading transitions, and prevents screen tearing.

### 4. Top Status Bar: Polybar
- Running across the top of the screen (`/root/.config/polybar/config.ini`, copied to user profiles via `/etc/skel`).
- Displays workspace indicators, current window title, clock, and status monitors.

### 5. Bottom Taskbar: Tint2
- Running at the bottom of the screen (`/root/.config/tint2/tint2rc`).
- Provides a traditional taskbar listing all open windows with application icons and an application menu button (`allapps.desktop`).

### 6. Application Launchers: Rofi
GalactOS uses **Rofi** for two distinct purposes:
1. **Application Launcher** (`W-space` / Super+Space): Launches `rofi -show drun -theme /usr/share/galactos/rofi/launcher.rasi` for searching and launching installed desktop applications.
2. **Sidebar Control Center**: Runs `rofi/sidebar.sh` (`sidebar.rasi`) to display date, time, battery level, audio volume, and quick links to open the terminal, file manager, browser, Orbit AI assistant, or power controls (reboot/shutdown/logout).

### 7. Terminal Emulator: Alacritty
- Fast, GPU-accelerated terminal emulator configured via `~/.config/alacritty/alacritty.toml`.
- Pre-configured with JetBrains Mono font, smooth padding, and GalactOS-matching color scheme.

---

## 3. Configuration & Autostart Lifecycle

When an Openbox session starts, it executes `~/.config/openbox/autostart`. In GalactOS, this file orchestrates session components in order:

```bash
# 1. Set desktop background wallpaper
feh --bg-fill /usr/share/backgrounds/galactos.jpg &

# 2. Launch compositor in background
picom --config /usr/share/galactos/picom/picom.conf -b

# 3. Launch top status bar
polybar main &

# 4. Launch bottom taskbar
tint2 &

# 5. Launch PolicyKit authentication agent (for GUI privilege prompts)
lxpolkit &

# 6. Launch notification daemon
dunst &
```

Every new user created by the installer inherits these configuration files automatically from `/etc/skel/`.

---

## 4. Examples & Everyday Usage

### Default Keyboard Shortcuts
Keybindings are configured in `~/.config/openbox/rc.xml` via `iso/gui/assets/insert-keybinds.sh`:

| Key Combination | Action | Command Executed |
| :--- | :--- | :--- |
| `Ctrl + Alt + T` | Open Terminal | `alacritty` |
| `Super + Space` | Application Launcher | `rofi -show drun -theme /usr/share/galactos/rofi/launcher.rasi` |
| `Super + E` | Open File Manager | `pcmanfm` |
| `Alt + F4` | Close Window | Standard Openbox Close action |
| `Alt + Tab` | Switch Windows | Standard Openbox NextWindow action |

### Example: Adding a Custom Keyboard Shortcut
To add a shortcut (e.g. `Super + B` to launch Firefox), edit `~/.config/openbox/rc.xml` inside the `<keyboard>` section:

```xml
<keybind key="W-b">
  <action name="Execute">
    <command>firefox-esr</command>
  </action>
</keybind>
```
Then reload Openbox settings without logging out:
```bash
openbox --reconfigure
```

---

## 5. Known Gaps

While lightweight and functional, the current desktop stack has several known limitations:

1. **Audio Routing in Virtual Machines**:
   - `pipewire`, `wireplumber`, and `alsa-utils` packages are installed, but virtual sound card emulation in VirtualBox/QEMU may fail to route audio to the host without manual configuration (`pavucontrol` is provided for troubleshooting).
2. **Display Resolution Settings**:
   - There is no pre-installed graphical display configuration applet (e.g., `arandr` or `lxrandr`). Resolution changes currently require running `xrandr` from the terminal.
3. **Multi-Monitor Setup**:
   - Polybar and Tint2 are configured for a single primary display. Multi-monitor setups require manual Polybar configuration adjustments per monitor.
4. **Power Management**:
   - A basic battery readout is scripted in `sidebar.sh`, but there is no background power management daemon (e.g., `xfce4-power-manager`) to handle automatic sleep or screen dimming on low battery.
5. **Screen Locking**:
   - The desktop does not automatically integrate a screen locker (e.g. `slock` or `light-locker`) with Web-Greeter when idling or pressing lock keys.
