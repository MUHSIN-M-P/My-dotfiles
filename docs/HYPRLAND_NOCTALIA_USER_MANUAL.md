# Hyprland + Noctalia User Manual

A practical, beginner-friendly guide for the Hyprland + Noctalia desktop on Fedora 43, built from this machine's actual configuration. Use the table of contents to jump to topics — each section is self-contained.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Quick Cheat Sheet](#2-quick-cheat-sheet)
3. [Daily Workflow](#3-daily-workflow)
4. [Hyprland Keybindings — Full Reference](#4-hyprland-keybindings--full-reference)
5. [Window Management](#5-window-management)
6. [Workspaces](#6-workspaces)
7. [The Noctalia Shell](#7-the-noctalia-shell)
8. [Application Launcher](#8-application-launcher)
9. [Terminal: kitty + bash + atuin + ble.sh](#9-terminal-kitty--bash--atuin--blesh)
10. [Files & File Manager](#10-files--file-manager)
11. [Browser (Brave)](#11-browser-brave)
12. [Wallpapers (Wallcards Plugin)](#12-wallpapers-wallcards-plugin)
13. [Screenshots & Screen Recording](#13-screenshots--screen-recording)
14. [Workspace Overview (Super+A)](#14-workspace-overview-supera)
15. [Lock Screen, Idle, Lid](#15-lock-screen-idle-lid)
16. [Sound, Audio, Media Keys](#16-sound-audio-media-keys)
17. [Display, Scaling, Fonts](#17-display-scaling-fonts)
18. [Power Management](#18-power-management)
19. [Battery Charge Limit (80%)](#19-battery-charge-limit-80)
20. [Settings UIs You Can Use](#20-settings-uis-you-can-use)
21. [Package Management — RPM, DNF, Flatpak](#21-package-management--rpm-dnf-flatpak)
22. [Updating the System](#22-updating-the-system)
23. [The fastfetch Splash](#23-the-fastfetch-splash)
24. [Profile Manager (Snapshots & Backup)](#24-profile-manager-snapshots--backup)
25. [Customizing — Adding Keybinds, Window Rules, Autostarts](#25-customizing--adding-keybinds-window-rules-autostarts)
26. [Troubleshooting](#26-troubleshooting)
27. [File & Path Reference](#27-file--path-reference)
28. [Glossary](#28-glossary)
29. [Useful Links & Where to Learn More](#29-useful-links--where-to-learn-more)
30. [Bluetooth](#30-bluetooth)
31. [Login Speed Tuning](#31-login-speed-tuning)
32. [Scroll Sensitivity & Natural Scroll](#32-scroll-sensitivity--natural-scroll)
33. [Caps Lock & Keyboard Options](#33-caps-lock--keyboard-options)
34. [Dotfiles Repo & sync.sh](#34-dotfiles-repo--syncsh)
35. [Professional SDDM Login Screen (Noctalia-Aligned)](#35-professional-sddm-login-screen-noctalia-aligned)
36. [Universal Package Manager Bridge (sysupdate & sysfind)](#36-universal-package-manager-bridge-sysupdate--sysfind)
37. [Wayland Clipboard Persistence Service (wl-clip-persist)](#37-wayland-clipboard-persistence-service-wl-clip-persist)
38. [Dedicated GPU Launcher Wrapper (nvrun)](#38-dedicated-gpu-launcher-wrapper-nvrun)
39. [Elan Match-on-Chip Fingerprint Setup](#39-elan-match-on-chip-fingerprint-setup)

---

## 1. System Overview

| Layer | Component | Where it lives |
|---|---|---|
| OS | Fedora 43 Workstation | — |
| Kernel | Linux 6.19.x | — |
| Display server | Wayland | — |
| Compositor (window manager) | **Hyprland** 0.54.x | `~/.config/hypr/` |
| Desktop shell (top bar, launcher, lock, tray) | **Noctalia** (`qs -c noctalia-shell`) | `/etc/xdg/quickshell/noctalia-shell/`, user overrides in `~/.config/noctalia/` |
| Workspace overview tool | `quickshell -c overview` | `~/.config/quickshell/overview/` |
| Screenshot tool | `quickshell -c HyprQuickFrame` | `~/.config/quickshell/HyprQuickFrame/` |
| Default terminal | **kitty** | `~/.config/kitty/` |
| Default shell | **bash** with `ble.sh` + `atuin` | `~/.bashrc`, `~/.blerc`, `~/.config/atuin/` |
| Browser | **Brave** | system; user-level desktop entry at `~/.local/share/applications/brave-browser.desktop` |
| File manager | **Nautilus / Files** (GNOME) | system |
| Audio backend | PipeWire | system |
| Audio post-processor | EasyEffects | autostarted |

**Mental model:** Hyprland is the engine that draws windows. Noctalia is the GUI on top — top bar, launcher, lock screen, settings panel. They are separate processes; if the bar disappears, Noctalia died (Hyprland is still fine).

---

## 2. Quick Cheat Sheet

The 30 things you'll use most. **`Super`** is the Windows / Command key.

| Action | Key |
|---|---|
| Open app launcher | `Super+Space` (or `Alt+Space`) |
| Open terminal | `Super+Return` |
| Open browser | `Super+Z` |
| Open file manager | `Super+E` |
| Close focused window | `Super+Q` |
| Force-kill stuck window | `Super+Shift+Q` |
| Toggle floating ↔ tiled | `Super+W` |
| Fullscreen | `Super+F` |
| Move floating window | hold `Super` + left-click and drag |
| Resize floating window | hold `Super` + right-click and drag |
| Switch focus (arrow keys) | `Super+←/→/↑/↓` (or `h/j/k/l`) |
| Move window | `Super+Shift+←/→/↑/↓` |
| Resize tiled window | `Super+Alt+←/→/↑/↓` |
| Switch workspace | `Super+1` … `Super+9`, `Super+0` |
| Move window to workspace | `Super+Shift+1` … `Super+Shift+0` |
| **Workspace overview (grid view)** | `Super+A` |
| Toggle scratchpad (special workspace) | `Super+\`` |
| **Lock screen** | `Super+O` |
| Session menu (logout / reboot / shutdown) | `Alt+F4` |
| Hide / show top bar | `Super+Shift+W` |
| Color picker | `Super+C` |
| Toggle wallpaper picker | `Super+Y` |
| Take a screenshot | `PrintScreen` |
| Annotate after screenshot | `Shift+PrintScreen` |
| Extract text (OCR) | `Ctrl+PrintScreen` (or `Super+Shift+S`) |
| Clipboard history | `Super+V` |
| Wipe clipboard | `Super+Shift+V` |
| Emoji picker | `Super+.` |
| Volume up / down / mute | `XF86AudioRaise/Lower/Mute` |
| Brightness up / down | `XF86MonBrightnessUp/Down` |

---

## 3. Daily Workflow

A worked example for a typical session:

1. **Login** → Hyprland starts, Noctalia paints the bar/wallpaper, Brave opens silently on workspace 1, a kitty drops into the special workspace, EasyEffects starts in the tray. fastfetch runs in any new kitty.
2. **Open the launcher** with `Super+Space`. Type to filter, Enter to launch. Click an icon directly with the mouse.
3. **Switch between apps** with `Super+1`…`9` (workspaces) or use `Super+A` for a grid overview where you can click any window thumbnail.
4. **Multi-task on one workspace** — open two apps, they tile side-by-side. Press `Super+W` to make one float. Drag with `Super+leftclick` to position.
5. **Lock & walk away** — `Super+O`. Or close the lid: it locks automatically and turns the screen off.
6. **End of day** — `Alt+F4` opens the session menu (logout / restart / shutdown).

---

## 4. Hyprland Keybindings — Full Reference

All keybinds are in `~/.config/hypr/configs/keybinds.conf` (system) and `~/.config/hypr/configs/user-overrides.conf` (yours). To add or change one, edit the file and run `hyprctl reload`.

### 4.1 Hyprland (compositor) actions

| Key | Action |
|---|---|
| `Super+Q` | Close active window |
| `Super+Shift+Q` | Force-kill (sends SIGKILL) |
| `Super+W` | Toggle floating |
| `Super+P` | Pseudotile mode |
| `Super+I` | Toggle split direction |
| `Super+F` | Maximize (fill-monitor) |
| `Super+Shift+F` | Real fullscreen (covers bar) |
| `Super+\`` | Toggle special (scratchpad) workspace |
| `Super+Shift+\`` | Move active window to special workspace |
| `Super+F1` | Toggle animations on/off |
| `Super+Shift+P` | Pin window (visible on every workspace) |

### 4.2 Window groups (tabbed window grouping)

| Key | Action |
|---|---|
| `Super+G` | Group / ungroup focused window |
| `Super+Shift+G` | Lock active group |
| `Super+Tab` | Next window in group |
| `Super+Shift+Tab` | Previous window in group |
| `Super+Ctrl+H/J/K/L` | Move window into group on left/down/up/right |
| `Super+D` | Move window out of its group |

### 4.3 Launchers

| Key | Action |
|---|---|
| `Super+Return` | Terminal (kitty) |
| `Super+E` | File manager (Nautilus) |
| `Alt+Space` / `Super+Space` | Application launcher |
| `Super+R` | Alt launcher (rofi `drun`) |
| `Super+Z` | Browser (Brave) |
| `Super+O` | Lock screen |

### 4.4 Tools

| Key | Action |
|---|---|
| `Super+C` | Color picker (Hyprpicker) — copies hex to clipboard |
| `Super+Y` | Wallpaper picker (Wallcards) |
| `PrintScreen` | Region screenshot (HyprQuickFrame) |
| `Shift+PrintScreen` | Annotate the just-captured screenshot |
| `Ctrl+PrintScreen` / `Super+Shift+S` | Region screenshot & OCR (copies text to clipboard) |
| `Super+V` | Clipboard history (Noctalia) |
| `Super+Shift+V` | Wipe clipboard |
| `Super+.` | Emoji picker |
| `Alt+F4` | Session menu (lock/sleep/shutdown/logout/reboot) |
| `Super+Shift+W` | Toggle Noctalia bar visibility |
| `Super+A` | Workspace overview grid |

### 4.5 Window focus & movement

| Key | Action |
|---|---|
| `Super+←/→/↑/↓` or `Super+H/J/K/L` | Move focus |
| `Super+Shift+←/→/↑/↓` or `Super+Shift+H/J/K/L` | Move window |
| `Super+Alt+←/→/↑/↓` or `Super+Alt+H/J/K/L` | Resize tiled window (70 px steps) |

### 4.6 Workspaces

| Key | Action |
|---|---|
| `Super+1` … `Super+9`, `Super+0` | Switch to workspace 1–10 |
| `Super+Shift+1` … `Super+Shift+0` | Move active window to workspace |
| `Super+Ctrl+1` … `Super+Ctrl+0` | Move window to workspace silently (no auto-switch) |

### 4.7 Lid switch (laptop)

| Action | Behavior |
|---|---|
| Close lid | Lock screen + display off |
| Open lid | Display on (lock screen still showing) |

---

## 5. Window Management

Hyprland is a **tiling** compositor. New windows automatically slot in next to the existing one, splitting the available space. You can opt windows out with floating mode.

### 5.1 Tiled mode (default)

- Windows split the screen automatically.
- `Super+I` toggles whether the next split is horizontal or vertical.
- `Super+Alt+arrow` resizes the focused tile by 70 px.

### 5.2 Floating mode

- Press `Super+W` to lift the focused window out of the tile grid.
- Hold `Super` and **left-click-drag** to move it.
- Hold `Super` and **right-click-drag** to resize.
- `Super+W` again to put it back into the tile grid.

### 5.3 Make a specific app always float

Add to `~/.config/hypr/configs/user-overrides.conf`:

```hyprland
windowrulev2 = float, class:^(kitty)$
windowrulev2 = size 900 600, class:^(kitty)$
windowrulev2 = center, class:^(kitty)$
```

Find the class name with `hyprctl clients` while the app is open — look for the `class:` field.

### 5.4 Group multiple windows into a tab stack

`Super+G` turns the focused window into a "group". Drop more windows into the group with `Super+Ctrl+H/J/K/L`. Switch tabs with `Super+Tab` / `Super+Shift+Tab`.

### 5.5 Pin a window across workspaces

`Super+Shift+P` keeps a floating window visible on every workspace.

### 5.6 Visuals (Gaps & Rounding)

To achieve a clean, sharp look, tiled windows have no rounding and reduced screen edge gaps, while floating windows retain their rounded corners. This is handled in `~/.config/hypr/configs/user-overrides.conf` using Hyprland window rules to disable rounding for tiled windows and `gaps_in` / `gaps_out` under the `general` block to tighten the layout.

---

## 6. Workspaces

You have 10 numbered workspaces (1–10) plus a special "scratchpad" workspace.

- `Super+N` switches to workspace N.
- `Super+Shift+N` moves the focused window to N.
- `Super+\`` toggles the scratchpad — a hidden workspace that floats over whatever you're doing. Great for a persistent notepad or terminal.
- `Super+A` opens the **overview** — a clickable 3×3 grid of all workspaces with live thumbnails. Drag a window from one cell to another to relocate it.

Initial autostart layout (configured in `~/.config/hypr/configs/user-overrides.conf`):

- Workspace 1: Brave (silently launched at login)
- Special workspace: kitty (silently launched at login)

---

## 7. The Noctalia Shell

Noctalia is the desktop shell — top bar, launcher, control center, lock screen, notifications, OSD, plugin host. It's the QML-based UI you see *around* the windows.

### 7.1 The top bar

- Click the icons to open Noctalia panels (calendar, weather, clipboard, etc.).
- The cookie-clock plugin (top-right) is a Noctalia plugin.
- Hide/show with `Super+Shift+W`.

### 7.2 Control Center (settings panel)

Open it via the gear icon in the bar. From there you can configure:

- Bar layout (modules, position, density, transparency)
- Plugins (enable / disable / configure)
- Themes (color scheme)
- Wallpaper (rotation, slot, monitor mapping)
- Keybindings (map shell-internal actions to keys)

### 7.3 If Noctalia crashes

You'll lose the bar and wallpaper. Restart with:

```bash
systemctl --user reset-failed noctalia-shell
systemd-run --user --unit=noctalia-shell --property=Restart=on-failure qs -c noctalia-shell
```

This wraps Noctalia in a systemd user unit so it auto-restarts on failure.

To kill it manually:

```bash
systemctl --user stop noctalia-shell
# or
pkill -x qs
```

### 7.4 Plugins enabled here

| Plugin | Purpose | Bound to |
|---|---|---|
| `wallcards` | Animated wallpaper picker | `Super+Y` |
| `cookie-clock` | Pixel-art clock widget | top-right of bar |
| `screen-toolkit` | Screenshot annotation | `Shift+PrintScreen` |

Plugins live at `~/.config/noctalia/plugins/` and `/usr/share/noctalia-plugins/`.

### 7.5 UI Contrast Tweaks

Because Noctalia automatically regenerates its theme from wallpapers or predefined settings (`colors.json` gets overwritten), we applied permanent system-wide QML patches to improve the visibility of panels and the top bar:

1. **Popup Menu Contrast:** The core `NBox.qml` widget and the nested Network Panel sections were patched to calculate a lighter background (`1.51` multiplier) relative to the active theme's surface color.
2. **Top Bar Icon Background:** The right-side top bar icons were configured to use a custom hardcoded background pill color (`#252629`).

The exact commands used to apply these patches (useful if reinstalling):
```bash
# Lighten popup menus
sudo sed -i 's/property color color: Color.mSurfaceVariant/property color color: Qt.lighter(Color.mSurfaceVariant, 1.51)/g' /etc/xdg/quickshell/noctalia-shell/Widgets/NBox.qml
sudo sed -i 's/color: showOnlyLists ? Color.mSurfaceVariant : "transparent"/color: showOnlyLists ? Qt.lighter(Color.mSurfaceVariant, 1.51) : "transparent"/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml
sudo sed -i 's/color: addHiddenMouseArea.containsMouse ? Color.mSurfaceVariant : Color.mSurface/color: addHiddenMouseArea.containsMouse ? Qt.lighter(Color.mSurfaceVariant, 1.51) : Color.mSurface/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml
sudo sed -i 's/colorBg: Color.mSurfaceVariant/colorBg: Qt.lighter(Color.mSurfaceVariant, 1.51)/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Network/NetworkPanel.qml
sudo sed -i 's/color: Color.mSurfaceVariant/color: Qt.lighter(Color.mSurfaceVariant, 1.51)/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Network/NetworkPanel.qml

# Set top bar icons pill background to #252629
sudo sed -i 's/: Color.mSurfaceVariant, Settings.data.bar.capsuleOpacity)/: "#252629", Settings.data.bar.capsuleOpacity)/g' /etc/xdg/quickshell/noctalia-shell/Commons/Style.qml
```
*(Requires a shell restart to take effect).*

### 7.6 Custom Capsule Color Shade

You can customize the color shade of the bar capsules. By default, capsules use colors from the active theme or color scheme keys. If you set the capsule color key to `none`, you can choose a custom color shade (useful if you prefer a subtle grey, dark, or accent shade).

- **Settings UI**: Open the Noctalia Control Center (gear icon in the bar) -> **Bar** -> **Show capsule** must be enabled -> Set **Capsule color** selection to the first choice (none) -> A **Custom capsule color** picker row will appear below it, allowing you to select your preferred shade.
- **Config file**: The setting is saved in `~/.config/noctalia/settings.json` under:
  ```json
  "bar": {
    "capsuleColorKey": "none",
    "customCapsuleColor": "#252629"
  }
  ```

---

## 8. Application Launcher

Press `Super+Space` (or `Alt+Space`).

- **Type** to fuzzy-filter installed apps.
- **Up/Down** to navigate, **Enter** to launch.
- **Esc** to close.
- The list is built from `.desktop` files in `/usr/share/applications/` and `~/.local/share/applications/`.

To make an app appear in the launcher, drop a `foo.desktop` file into `~/.local/share/applications/`. The launcher picks it up next time you open it.

To **hide** a stock app from the launcher, copy its system desktop file to `~/.local/share/applications/` and add `NoDisplay=true`.

To **change a launcher entry's command** (e.g., to add CLI flags), copy its `.desktop` from `/usr/share/applications/` to `~/.local/share/applications/` and edit the `Exec=` lines. The user copy overrides the system one. We did this for Brave to remove a force-scale flag.

---

## 9. Terminal: kitty + bash + atuin + ble.sh

### 9.1 kitty itself

- Launch with `Super+Return`.
- Font: JetBrainsMono Nerd Font 12pt — change in `~/.config/kitty/kitty.conf`.
- `Ctrl+Plus` / `Ctrl+Minus` / `Ctrl+0` resize font on the fly.
- `PageUp` / `PageDown` to scroll.
- 80% transparency by default (`background_opacity 0.8`).

### 9.2 bash + ble.sh (line editor with autosuggestions)

ble.sh adds:

- **Inline autosuggestion (ghost text):** as you type, the most likely command from your history appears in grey after the cursor. Press `→` (right arrow) or `End` to accept it.
- **Syntax highlighting** while typing.
- Tab still does stock-bash completion (lists matches first press, cycles second press) — we deliberately kept that classic feel.

Config is at `~/.blerc`. Toggle features by editing `bleopt complete_auto_complete=...` lines.

### 9.3 atuin (history search)

atuin replaces the dumb stock bash history with a searchable database. You'll see it via:

- **`Ctrl+R`** → small dropdown at the bottom of the screen with fuzzy history search. Type to filter, arrows to navigate, Enter to run.
- Up arrow on the prompt is **not** atuin — that's stock bash previous-history. Atuin only fires on `Ctrl+R`.

First-time setup (do this once):

```bash
atuin import bash    # imports your existing ~/.bash_history
atuin stats          # shows your most-used commands
```

If you want history to sync between machines (optional), `atuin register` creates a free sync account. Local-only is the default — totally fine.

Atuin config: `~/.config/atuin/config.toml`. We use `style = "compact"` for the small dropdown look.

### 9.4 fastfetch

Runs automatically in every new kitty. Shows the Fedora ASCII logo, OS info, kernel, package count, kitty/Hyprland version, and uptime. Config: `~/.config/fastfetch/config.jsonc`.

To skip it for one-off shells: `bash --norc` or set `FASTFETCH_SKIP=1` (would need a small bashrc tweak to honor it).

To remove the splash entirely: edit `~/.bashrc` and remove the `fastfetch` line near the bottom.

---

## 10. Files & File Manager

**Nautilus** is the default. Open with `Super+E`.

Key features used here:

- KDE theme (Inter font, dark, macOS cursor) via `~/.config/kdeglobals`, `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`.
- Built-in tabs, split view (`F3`), preview pane (`F11`), terminal embedded (`F4`).

Other terminal-based file tools you have:

- `ranger` (if installed) — vim-style, three-pane file navigator
- `cd`, `ls`, `tree` — basics

---

## 11. Browser (Brave)

Brave is the default browser, launched on workspace 1 at login (autostart) and bound to `Super+Z`.

- **Wayland scaling**: Brave runs through XWayland and the compositor handles 1.25× scaling automatically — no `--force-device-scale-factor` flag needed (we removed it).
- User-level launcher entry: `~/.local/share/applications/brave-browser.desktop` overrides the system file. Add command-line flags to the `Exec=` lines if you need to.
- Profile data: `~/.config/BraveSoftware/Brave-Browser/`.
- Handy CLI: `brave-browser --new-window <url>` or `brave-browser --incognito`.

---

## 12. Wallpapers (Wallcards Plugin)

Open with `Super+Y`.

- Wallpapers live in `~/Pictures/Wallpapers/` (set in Noctalia → Settings → Wallpaper → Directory).
- Three filter tabs: **All**, **Images**, **Videos**.
- Card carousel — hover with mouse, scroll wheel, or arrow keys to cycle.
- Click the centered card to apply.
- Random shuffle button (`R`) reshuffles the deck.
- Live-preview button (`P`) applies as you hover (heavier on CPU).

### 12.1 Adding wallpapers

**Images** — drop `.png / .jpg / .jpeg` files into `~/Pictures/Wallpapers/`. They'll appear in the Images and All tabs the next time you open Wallcards.

**Videos** — drop `.mp4 / .mkv / .webm / .mov / .avi` files into the same folder. Same drill: open Wallcards (`Super+Y`), click the Videos tab, click any video card to apply.

### 12.2 Video wallpapers (custom feature)

The upstream wallcards plugin had video applying as a TODO. We patched it. Click a video card → it plays as your wallpaper via `mpvpaper`. The video resumes after reboot via `exec-once = ~/.local/bin/wallcards-video restore` in `~/.config/hypr/configs/user-overrides.conf`.

To stop a video and revert to a static image: just click any image card. To check / control manually:

```bash
~/.local/bin/wallcards-video status            # what's currently playing
~/.local/bin/wallcards-video set eDP-1 /path/to/video.mp4
~/.local/bin/wallcards-video clear
```

State is at `~/.local/state/wallcards-video.state`.

**Important:** the patched plugin invokes the helper at its absolute path `/home/ldzbeta/.local/bin/wallcards-video` because Noctalia's environment may have a minimal `PATH`. If you ever move the helper, update both occurrences in `~/.config/noctalia/plugins/wallcards/WallcardsWindow.qml`.

**Caveat:** matugen color extraction uses the current wallpaper *image*, so the color theme doesn't auto-update from videos. Apply an image once first to establish a palette, then apply a video.

### 12.3 Keyboard Navigation

The Wallcards plugin supports full keyboard navigation. You can use the arrow keys to interact with the UI:
- **Left/Right**: Cycle through wallpapers
- **Up**: Shuffle the deck
- **Down**: Select and apply the focused wallpaper

*(Note: We patched the QML keyboard binding implementation in the Wallcards component to properly restore this arrow-key navigation.)*

---

## 13. Screenshots & Screen Recording

- `PrintScreen` → region selector via **HyprQuickFrame** (Quickshell-based). Screenshots save to `~/Pictures/Screenshots/`.
- `Shift+PrintScreen` → annotate the most recent capture (Noctalia screen-toolkit plugin).
- `Ctrl+PrintScreen` or `Super+Shift+S` → region screenshot with OCR (extracts text and copies it to clipboard using Tesseract).

For a screen recorder, install `wf-recorder`:

```bash
sudo dnf install wf-recorder
wf-recorder -g "$(slurp)" -f ~/Videos/recording.mp4   # region recording
```

Or use OBS Studio (`sudo dnf install obs-studio`) for streaming/recording.

---

## 14. Workspace Overview (Super+A)

A 3×3 grid of all 9 workspaces with live thumbnails plus a special-workspace row.

- **Click** any cell → switch to that workspace.
- **Drag a window thumbnail** between cells → moves the window to that workspace.
- **`Super+A`** again to close.

The overview is a separate quickshell process (`quickshell -c overview`). If `Super+A` does nothing:

```bash
pkill -f "quickshell -c overview"
quickshell -c overview &
```

Config: `~/.config/quickshell/overview/`.

---

## 15. Lock Screen, Idle, Lid

| Trigger | Behavior |
|---|---|
| `Super+O` | Lock immediately (Noctalia lock screen) |
| Close laptop lid | Lock + screen off |
| Open lid | Screen on, lock prompt visible |
| `Alt+F4` | Session menu (lock / sleep / shutdown / logout / reboot) |

If you want **idle auto-lock** (e.g., lock after 5 minutes idle), `hypridle` is installed but not configured. Tell me to set it up — it's a 30-second config file.

---

## 16. Sound, Audio, Media Keys

- Volume up/down/mute and brightness work via the standard `XF86Audio*` / `XF86MonBrightness*` keys.
- Audio backend: PipeWire. **EasyEffects** is autostarted in the tray for system-wide EQ / compression / noise suppression.
- Per-app volume mixer: install `pavucontrol` (`sudo dnf install pavucontrol`).
- Media playback control (Spotify, browser, players): `XF86AudioPlay/Pause/Next/Prev` work (bound to `playerctl`).

---

## 17. Display, Scaling, Fonts

### 17.1 Monitor scaling

Set in `~/.config/hypr/monitors.conf`:

```hyprland
monitor=eDP-1,1920x1200@120,0x0,1.25
monitor=,preferred,auto,1.25
```

Last value (`1.25`) is the scale. `1.25` ≈ Windows' default 125% on a HiDPI laptop. Change to `1.5` for bigger, `1` for native. Run `hyprctl reload` after editing.

For a GUI: `nwg-displays` (install with `sudo dnf install nwg-displays`).

### 17.2 Natural scrolling (Mac/Windows-style)

Enabled in `~/.config/hypr/configs/user-overrides.conf` under the `input` block:

```hyprland
input {
    natural_scroll = true
    touchpad {
        natural_scroll = true
    }
}
```

Both the mouse wheel and the touchpad now scroll content with your fingers (drag up to scroll up). To revert, set both to `false` and `hyprctl reload`.

### 17.3 Fonts

Three places, kept consistent at **Inter 9pt** (× 1.25 scale = ~11pt visual, matching Windows defaults):

| App family | File | Setting |
|---|---|---|
| GTK 3 apps | `~/.config/gtk-3.0/settings.ini` | `gtk-font-name=Inter 9` |
| GTK 4 apps | `~/.config/gtk-4.0/settings.ini` | `gtk-font-name=Inter 9` |
| KDE / Qt apps | `~/.config/kdeglobals` | `[General] font=Inter,9,...` |
| kitty | `~/.config/kitty/kitty.conf` | `font_size 10.0` |
| GNOME defaults | `gsettings set org.gnome.desktop.interface font-name 'Inter 9'` | (live) |
| Fontconfig defaults (sans/mono) | `~/.config/fontconfig/fonts.conf` | sans → Inter, mono → JetBrainsMono |

**Existing windows don't reload fonts** — close and reopen the app to see changes.

For Brave's UI specifically: it doesn't read GTK/KDE fonts; it scales with the compositor. If Brave UI feels off, edit `~/.local/share/applications/brave-browser.desktop` and add a `--force-device-scale-factor=1.0` (or `1.1`, `1.5`, etc.) to the `Exec=` lines.

---

## 18. Power Management

Power profiles (Performance / Balanced / Power Saver) are managed by **tuned-ppd** (which translates the standard Power-Profiles-Daemon API to TuneD profiles). 

You can cycle the system's fan and power profile immediately using the **`Fn+F`** hardware hotkey (maps to raw keycodes `482` / `490` representing `KEY_FN_F`) or **`Super+F5`** on your keyboard. 

When toggled, it cycles the system:
1. **Silent 🍃** (`power-saver` / `powersave` profile, ASUS throttle policy `2`) — Quiet acoustics and throttled power.
2. **Balanced ⚖️** (`balanced` / `balanced` profile, ASUS throttle policy `0`) — Default dynamic performance.
3. **Performance 🚀** (`performance` / `throughput-performance` profile, ASUS throttle policy `1`) — Maximum power limits and fan curves.

A premium, custom On-Screen Display (OSD) notification will slide in from the corner to indicate the active profile.

To query or toggle profiles manually via D-Bus (without needing `sudo` passwords):

```bash
# Get the active profile
gdbus call --system --dest org.freedesktop.UPower.PowerProfiles --object-path /org/freedesktop/UPower/PowerProfiles --method org.freedesktop.DBus.Properties.Get org.freedesktop.UPower.PowerProfiles ActiveProfile

# Set to Balanced mode
gdbus call --system --dest org.freedesktop.UPower.PowerProfiles --object-path /org/freedesktop/UPower/PowerProfiles --method org.freedesktop.DBus.Properties.Set org.freedesktop.UPower.PowerProfiles ActiveProfile "<'balanced'>"

# Set to Performance mode
gdbus call --system --dest org.freedesktop.UPower.PowerProfiles --object-path /org/freedesktop/UPower/PowerProfiles --method org.freedesktop.DBus.Properties.Set org.freedesktop.UPower.PowerProfiles ActiveProfile "<'performance'>"

# Set to Silent/Quiet mode
gdbus call --system --dest org.freedesktop.UPower.PowerProfiles --object-path /org/freedesktop/UPower/PowerProfiles --method org.freedesktop.DBus.Properties.Set org.freedesktop.UPower.PowerProfiles ActiveProfile "<'power-saver'>"
```

You can also change profiles in GNOME Control Center → Power. (KDE's `systemsettings` Power panel will say "service not running" because it expects the Plasma daemon `powerdevil` — which we don't run on Hyprland.)

### 18.1 High-Performance Login Architecture (Dynamic Boot Scaling)

To achieve **instant, zero-delay logins** while preserving battery longevity, Noctalia utilizes a custom **Dynamic Boot Performance Scaler**:

1. **Boot / SDDM / Login Phase (Maximum CPU/RAM Performance):**
   * Upon shutdown or reboot, the systemd service **`tuned-bootfast-reset.service`** saves the current profile to `/etc/tuned/ppd_runtime_profile` and sets `/etc/tuned/ppd_base_profile` to **`performance`** (mapped to `throughput-performance`).
   * This overrides standard Intel/AMD powersave governors, forcing all 16 cores to run with the **`performance` scaling governor** and **`performance` Energy Performance Preference (EPP)**.
   * Everything—including SDDM password validation, Hyprland startup, Wayland environment setup, and QML rendering—happens at your hardware's absolute maximum clock speed, bypassing all low-power state throttling.
   
2. **Desktop / Runtime Phase (Balanced Dynamic Battery Management):**
   * Once Hyprland has completed launching and is drawing the desktop background, the autostart script in `user-overrides.conf` triggers the restoration helper:
     ```hyprland
     exec-once = ~/.local/bin/restore-power-profile
     ```
   * After 8 seconds (when all UI panels, bars, and applets have fully loaded), the script reads the saved profile and sets it via D-Bus (requiring no root password or privileges).
   * If the user preferred profile was **`balanced`**, PPD maps it to **`desktop`** on AC power (allowing **`balance_performance`** EPP and CPU scaling) or **`balanced-battery`** on battery power.
   * If the user preferred profile was **`power-saver`** (Silent mode), it automatically throttles down to save battery and reduce fan noise.

This dual-state optimization delivers the best of both worlds: **unthrottled, instantaneous desktop loads** with **silent, long-lasting battery life** during normal desktop use.

### 18.2 Noctalia Persistent Low-Battery Alert

To ensure critical battery conditions are never missed, Noctalia replaces default transient toast notifications with a persistent, fullscreen, and modal-style battery alert overlay when low battery thresholds are reached:

* **Modal Focus:** Utilizes exclusive keyboard grabbing (`WlrKeyboardFocus.Exclusive`) and backdrop dimming to temporarily lock interaction with the rest of the desktop, prompting immediate action.
* **Dismissal Security:** The overlay blocks normal desktop usage and is immune to accidental keypresses. Typing typical characters (including `Space`) does not dismiss the modal. It will only unload if the user explicitly clicks the **"OK"** button or presses **`Enter`**, **`Return`**, or **`Escape`**.
* **Auto-Dismissal:** If you connect a charger and the battery status changes to charging, or if the battery level rises above the warning threshold, the alert automatically unloads itself.
* **Manual Testing & Triggering:** You can manually invoke and test the battery warning dialog using the exposed IPC endpoints:
  ```bash
  # Trigger the modal manually (title, description, and icon name are optional)
  qs ipc call battery triggerLowWarning "Battery Low Warning" "Your system battery is at 10%. Please connect a charger immediately." "battery-exclamation"

  # Programmatically dismiss the modal
  qs ipc call battery dismissLowWarning
  ```

### 18.3 Battery Life Optimizations (Custom TuneD Profiles)

To improve battery runtimes under Linux relative to Windows, we run customized variations of standard TuneD profiles configured to automatically engage aggressive low-power hardware tuning on battery:

1. **Custom Mappings (`/etc/tuned/ppd.conf`):**
   * Switching the system to `Power saver` (Silent mode) activates the custom `powersave-noctalia` profile.
   * Running on battery under `Balanced` mode dynamically activates the custom `balanced-battery-noctalia` profile.

2. **Advanced Hardware Optimization Controls:**
   * **PCIe ASPM Policy:** Forced to `powersave` mode to scale down high-speed serial bus links when idle.
   * **PCI Runtime PM:** Enforces dynamic sleep/suspend controls (`auto`) for all idle PCI controllers, including the dedicated NVIDIA GPU, HD audio, and network adapters.
   * **USB Autosuspend:** Suspends power to all internal and external USB controllers (`USB_AUTOSUSPEND=1`) when inactive.
   * **Wi-Fi Power Saving:** Automatically activates kernel-level Wi-Fi power-save modes.
   * **SATA ALPM:** Configured to save disk interface power (`min_power` on power-saver, `med_power_with_dipm` on balanced).

---

## 19. Battery Charge Limit (80%)

Lithium batteries last longer when not regularly topped up to 100%. We set up an 80% limit at the kernel level.

```bash
sudo charge-limit 80          # enable 80% limit (also the boot default)
sudo charge-limit 100         # full charge mode (e.g., before travel)
sudo charge-limit status      # show current limit + charge level
```

`sudo` doesn't ask for a password — `/etc/sudoers.d/charge-limit` allows passwordless invocation of just this one binary.

**Persistence:** `/etc/tmpfiles.d/charge-limit.conf` writes `80` to the threshold on every boot via systemd-tmpfiles. To change the boot default, edit that file and change `80` to whatever you prefer.

Files involved:

- `/usr/local/bin/charge-limit` — the helper script
- `/etc/sudoers.d/charge-limit` — passwordless sudo rule
- `/etc/tmpfiles.d/charge-limit.conf` — boot persistence
- `/sys/class/power_supply/BAT1/charge_control_end_threshold` — the kernel sysfs file being written

---

## 20. Settings UIs You Can Use

There is no single "Control Panel" on Hyprland the way Windows or macOS has. You mix and match.

| Need | App | How to launch |
|---|---|---|
| **Most things (Power, Displays, Keyboard, Online Accounts, Mouse, Sound)** | **GNOME Control Center** | Search "Settings" in the launcher (we wrapped it with `XDG_CURRENT_DESKTOP=GNOME` so panels render outside GNOME) |
| Bar, plugins, themes, wallpaper rotation, keybindings | Noctalia Control Center | Click the gear icon on the bar |
| Display layout (multi-monitor) | `nwg-displays` | `nwg-displays` |
| Per-app sound mixer | `pavucontrol` | `pavucontrol` |
| Network connections, VPN | `nm-connection-editor` | `nm-connection-editor` |
| Bluetooth pairing | `blueman-manager` | `blueman-manager` |
| Audio EQ / noise suppression | `easyeffects` | `easyeffects` |
| Software install / update | **GNOME Software** | Search "Software" |
| Power profile | `powerprofilesctl` (CLI) or GNOME Control Center → Power | — |
| Hyprland-specific config | text editor on `~/.config/hypr/` | `kate ~/.config/hypr/configs/user-overrides.conf` |

`systemsettings` (KDE) is installed but most of its panels expect Plasma daemons that aren't running here. Stick with the table above.

---

## 21. Package Management — RPM, DNF, Flatpak

Fedora has three package systems. Here's when you use each:

| System | What | Where it lives | Command |
|---|---|---|---|
| **RPM** (via DNF) | OS packages, system tools | `/usr/`, system-wide | `dnf` |
| **Flatpak** | Sandboxed GUI apps from Flathub | `/var/lib/flatpak/` and `~/.local/share/flatpak/` | `flatpak` |
| **AppImage** | Single-binary apps | wherever you put them | run directly |

### 21.1 DNF cheat sheet

```bash
# Install / update / remove
sudo dnf install <pkg>
sudo dnf upgrade                       # update everything
sudo dnf remove <pkg>
sudo dnf autoremove                    # clean up unused dependencies

# Search & info
dnf search <keyword>
dnf info <pkg>
rpm -qi <pkg>                          # detailed info on installed package

# Find which package owns a file
rpm -qf /path/to/file

# What files does a package install?
rpm -ql <pkg>

# What depends on this package?
dnf repoquery --whatrequires <pkg>

# What does this package depend on?
dnf repoquery --requires <pkg>

# What I explicitly installed (vs what was pulled as a dependency)
dnf repoquery --userinstalled

# Recently installed
rpm -qa --queryformat '%{INSTALLTIME} %{NAME}\n' | sort -rn | head

# Activity log
dnf history list
dnf history info <id>

# Find orphan/leaf packages (nothing depends on them)
package-cleanup --leaves --quiet
```

### 21.2 GUI: GNOME Software

The friendliest way. Search "Software" in the launcher. It lists installed apps with screenshots, lets you install/uninstall, manages updates, and supports Flatpak alongside RPM.

To enable Flathub (huge Flatpak repository):

```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Then GNOME Software shows Flathub apps too.

### 21.3 Common cleanup candidates on this system

(Skip any you actually use.)

```bash
sudo dnf remove firefox                          # ~267 MB — you use Brave
sudo dnf remove libreoffice-core libreoffice-\*  # ~500-700 MB — only if you don't open .docx/.odt locally
sudo dnf remove upscayl                          # ~604 MB — image upscaler, only if used
```

`sudo dnf autoremove` already shows nothing on this system, so there are no orphan dependencies right now.

---

## 22. Updating the System

Run weekly:

```bash
sudo dnf upgrade --refresh
flatpak update
```

Or via GNOME Software's Updates pane. If a kernel was updated, reboot afterwards.

To upgrade across Fedora releases (e.g., 43 → 44):

```bash
sudo dnf install dnf-plugin-system-upgrade
sudo dnf system-upgrade download --releasever=44
sudo dnf system-upgrade reboot
```

Don't do this casually — read the Fedora release notes first.

---

## 23. The fastfetch Splash

Auto-runs in every new kitty (via `~/.bashrc`). Logo: builtin "Fedora" ASCII (the colorful F-in-diamond). Modules: OS, kernel, packages (rpm count), shell, terminal, wm, uptime, color palette.

Config: `~/.config/fastfetch/config.jsonc`.

To swap the logo:

- Builtin distros: change `"source": "Fedora"` to any from `fastfetch --list-logos` (e.g., `Fedora_small`, `Fedora_old`).
- Real image (only in kitty/iTerm2): set `"type": "kitty-direct"` and `"source": "/path/to/image.png"`.
- Custom ASCII art: set `"type": "file"` and `"source": "/path/to/your.txt"`.

---

## 24. Profile Manager (Snapshots & Backup)

You have `~/profile-manager/` with a small bash tool that snapshots your config tree to `~/profile-manager/backups/<label>/`.

Use it before risky changes:

```bash
~/profile-manager/profile-manager.sh snapshot pre-experiment-$(date +%F)
```

Listed paths it manages (from `MANAGED_PATHS` in the script):

- `.config/hypr`, `.config/quickshell`, `.config/kitty`, `.config/fuzzel`, `.config/matugen`
- `.config/gtk-3.0`, `.config/gtk-4.0`, `.config/wlogout`, `.config/illogical-impulse`, `.config/kdeglobals`
- `.local/bin`, `.local/share/quickshell-lockscreen`
- `.zshrc`, `.ideavimrc`

To restore from a snapshot, the script has a `switch <label>` subcommand that swaps the current config tree out for the snapshot.

---

## 25. Customizing — Adding Keybinds, Window Rules, Autostarts

All your overrides go in **`~/.config/hypr/configs/user-overrides.conf`**. Editing the system file (`keybinds.conf`) works but gets overwritten on Noctalia/Hyprland updates — overrides survive.

### 25.1 Add a keybind

```hyprland
# Open Spotify with Super+M
bind = $mainMod, M, exec, spotify

# Cycle power profiles with Super+F2
bind = $mainMod, F2, exec, bash -c 'cur=$(powerprofilesctl get); case $cur in power-saver) powerprofilesctl set balanced ;; balanced) powerprofilesctl set performance ;; *) powerprofilesctl set power-saver ;; esac'
```

After editing: `hyprctl reload`.

### 25.2 Variables

You can re-define `$mainMod`, `$browser`, `$terminal`, etc. in your override file to change app defaults without touching the system file.

### 25.3 Window rules

```hyprland
windowrulev2 = float, class:^(Calculator)$
windowrulev2 = workspace 5, class:^(Spotify)$
windowrulev2 = noborder, class:^(kitty)$
windowrulev2 = opacity 0.9 0.85, class:^(kitty)$        # focused 90%, blurred 85%
windowrulev2 = pin, title:^(Picture-in-Picture)$
```

Find class with `hyprctl clients` while the app is open.

### 25.4 Autostart

```hyprland
exec-once = nm-applet
exec-once = blueman-applet
exec-once = [workspace 3 silent] discord
exec-once = brave-browser --no-startup-window     # pre-warm Brave so launcher feels instant
```

`[workspace N silent]` opens the app on workspace N without switching to it.

### 25.5 Environment variables

```hyprland
env = GDK_SCALE,1
env = QT_QPA_PLATFORMTHEME,qt6ct
env = ELECTRON_OZONE_PLATFORM_HINT,wayland
```

After changing env vars, **fully log out and back in** — `hyprctl reload` does not re-export env vars to running apps.

---

## 25.5 App Launch Performance — Pre-Warming & FD Limits

The launcher → app spawn pipeline has been tuned for snappier launches **without keeping apps resident in RAM**. Three layers of optimization:

### A. Spawn-path tuning (zero RAM cost)

- Quickshell starts with `nofile=524288` (was 1024) so launcher-spawned apps inherit it. Browsers/Electron/Java apps allocate hundreds of FDs and behave more conservatively when constrained.
- `HyprlandService.spawn` patched to fork apps directly via `Quickshell.execDetached` instead of the `hyprctl dispatch exec` round-trip. Saves ~20–50 ms per launch.
- `misc:focus_on_activate = true` and `input:focus_on_close = 1` so new windows take focus immediately when the launcher closes.

### B. Adaptive page-cache pre-warm (zero permanent RAM)

A small daemon reads Noctalia's launcher usage stats (`~/.cache/noctalia/shell-state.json` → `launcherUsage`) and pre-loads the install directories of your **top 8 most-used apps with ≥3 launches** into the kernel page cache via `vmtouch -t`. Cache is reclaimable under memory pressure, so cost is effectively zero.

**Tunables in `~/.local/bin/prewarm-apps`:**

```bash
TOP_N=8           # max apps to cache
MIN_USES=3        # require this many launches to qualify
MAX_TOTAL_MB=2000 # hard cap on total cache footprint
```

**Schedule (systemd user timer):**

- Runs **45 seconds after login** (catches up boot-time cache miss)
- Re-runs **every 7 days** with 2-minute random jitter (re-evaluates as your habits change)

**Useful commands:**

```bash
systemctl --user list-timers prewarm-apps.timer       # show next/last run
systemctl --user start prewarm-apps.service           # re-run immediately
cat ~/.local/state/prewarm-apps.log                   # see what was selected each run
systemctl --user disable --now prewarm-apps.timer     # turn it off completely
```

**Files:**

- `~/.local/bin/prewarm-apps` — selection + vmtouch driver
- `~/.config/systemd/user/prewarm-apps.service` — oneshot service
- `~/.config/systemd/user/prewarm-apps.timer` — boot + weekly schedule
- `~/.local/state/prewarm-apps.log` — run history

### C. Pre-warming heavy apps (optional, costs RAM)

We deliberately skipped pre-warming because it costs ~150–300 MB per resident app. If you ever change your mind, add to `~/.config/hypr/configs/user-overrides.conf`:

```hyprland
exec-once = brave-browser --no-startup-window
```

Brave then sits as an idle daemon (~150 MB) and new-window launches from the launcher feel instant. Same pattern works for any Chromium/Electron app that has the flag.

### Honest limits

After all of the above, the dominant cost on a heavy app's first launch is the app's own initialization (Chromium loading shared libs, V8 engine, etc.) — typically 500–1000 ms for Brave/VS Code/Antigravity. Page-cache pre-warm shaves the disk-read portion (~100–300 ms). The only way to make a heavy app **feel instant** is to keep it running, which trades RAM for latency.

---

## 26. Troubleshooting

### 26.1 Top bar is gone / wallpaper gone / black screen

Noctalia died. Recover:

```bash
systemctl --user reset-failed noctalia-shell
systemd-run --user --unit=noctalia-shell --property=Restart=on-failure qs -c noctalia-shell
```

Logs (look for the most recent):

```bash
ls -t /run/user/$UID/quickshell/by-id/*/log.qslog | head -1 | xargs tail -100
```

### 26.2 Launcher icons missing or broken

Kill all noctalia and restart it (see above). If still broken, check `~/.config/noctalia/settings.json` for a custom icon theme that might not exist.

### 26.3 An app I installed doesn't appear in the launcher

Refresh the desktop database:

```bash
update-desktop-database ~/.local/share/applications
```

Also reopen the launcher (it caches on first open in a session).

### 26.4 Brave UI is too small / too big

Edit `~/.local/share/applications/brave-browser.desktop` and add to the `Exec=` lines:

```
--force-device-scale-factor=1.25
```

(`1.0` for smaller, `1.5` for bigger.) Quit and relaunch Brave.

### 26.5 An app refuses to launch from launcher but works in terminal

Often missing env vars. Wrap with `env`:

```
Exec=env XDG_CURRENT_DESKTOP=GNOME gnome-control-center
```

We did this for GNOME Control Center because some panels refuse to run outside a GNOME session.

### 26.6 Wallpaper changing isn't reflected in colors

Noctalia's color extraction (matugen) reads the wallpaper image. If you set a video wallpaper, colors won't update — set an image once first to get a color scheme, then apply the video.

### 26.7 fastfetch logo doesn't render image (just shows ASCII)

The image protocol needs kitty (or another supporting terminal). In TTY / SSH / non-image-capable terminals, fastfetch falls back to the builtin ASCII automatically.

### 26.8 Up arrow opens a weird search instead of previous command

That was atuin's default up-arrow binding. We've disabled it (`__atuin_bind_up_arrow=false` in `~/.bashrc`). Use `Ctrl+R` for atuin's history search instead.

### 26.9 Lid-close doesn't lock the screen

Verify the binding:

```bash
hyprctl binds | grep -A4 "Lid Switch"
```

If empty, check `~/.config/hypr/configs/user-overrides.conf` has the `bindl = , switch:on:Lid Switch, ...` lines.

### 26.10 Weird permission errors when running graphical commands

Don't run GUI apps with `sudo` — it breaks Wayland authentication. If you really need root for a GUI tool, use `pkexec` instead.

### 26.11 Clicking a video in the wallpaper picker does nothing

Likely the helper script can't be found in Noctalia's `PATH`. Verify:

```bash
tr '\0' '\n' < /proc/$(pgrep -f "qs -c noctalia-shell" | head -1)/environ | grep ^PATH=
```

Should include `/home/ldzbeta/.local/bin`. If it doesn't:
- Check `~/.config/hypr/configs/autostart.conf` — Noctalia is started with `bash -c 'export PATH=...; exec qs -c noctalia-shell'`
- The wallcards plugin's `applyCard()` uses the absolute path `/home/ldzbeta/.local/bin/wallcards-video` to be safe regardless of PATH

If mpvpaper layer is present (`hyprctl layers | grep mpvpaper`) but you don't see the video, check that Noctalia's wallpaper layer isn't stuck on top — restart the shell:

```bash
systemctl --user reset-failed noctalia-shell
systemd-run --user --unit=noctalia-shell --property=Restart=on-failure --property=LimitNOFILE=524288 \
  bash -c 'export PATH=$HOME/.local/bin:$PATH; exec qs -c noctalia-shell'
```

### 26.12 Up arrow opens atuin search instead of previous command

Should be fixed already (`__atuin_bind_up_arrow=false` in `~/.bashrc`). Use `Ctrl+R` for atuin's compact search dropdown.

---

## 27. File & Path Reference

| Purpose | Path |
|---|---|
| Hyprland main config | `~/.config/hypr/hyprland.conf` |
| Hyprland keybinds | `~/.config/hypr/configs/keybinds.conf` (system) |
| **Your Hyprland overrides** | `~/.config/hypr/configs/user-overrides.conf` |
| Monitor config | `~/.config/hypr/monitors.conf` |
| Workspace config | `~/.config/hypr/workspaces.conf` |
| Noctalia user settings | `~/.config/noctalia/settings.json` |
| Noctalia plugins | `~/.config/noctalia/plugins/` |
| Noctalia shell (system) | `/etc/xdg/quickshell/noctalia-shell/` |
| Quickshell overview | `~/.config/quickshell/overview/` |
| Quickshell screenshot tool | `~/.config/quickshell/HyprQuickFrame/` |
| Wallcards plugin | `~/.config/noctalia/plugins/wallcards/` |
| Wallcards video state | `~/.local/state/wallcards-video.state` |
| kitty config | `~/.config/kitty/kitty.conf` |
| kitty theme | `~/.config/kitty/current-theme.conf` |
| bash interactive config | `~/.bashrc` |
| ble.sh config | `~/.blerc` |
| atuin config | `~/.config/atuin/config.toml` |
| atuin database | `~/.local/share/atuin/history.db` |
| fastfetch config | `~/.config/fastfetch/config.jsonc` |
| GTK 3 settings | `~/.config/gtk-3.0/settings.ini` |
| GTK 4 settings | `~/.config/gtk-4.0/settings.ini` |
| KDE / Qt settings | `~/.config/kdeglobals` |
| Fontconfig defaults | `~/.config/fontconfig/fonts.conf` |
| Brave user launcher | `~/.local/share/applications/brave-browser.desktop` |
| Settings (GNOME CC) launcher | `~/.local/share/applications/org.gnome.Settings.desktop` |
| Wallpaper directory | `~/Pictures/Wallpapers/` |
| Screenshots directory | `~/Pictures/Screenshots/` |
| Custom helpers | `~/.local/bin/` (`charge-limit`, `wallcards-video`, `hyprland-dialog`, `hyprland-guiutils`) |
| Profile manager | `~/profile-manager/` |
| Profile snapshots | `~/profile-manager/backups/` |
| Local user services | `~/.config/systemd/user/` |

---

## 28. Glossary

| Term | Meaning |
|---|---|
| **Compositor** | The program that draws windows on screen (Hyprland) |
| **Wayland** | Modern display-server protocol replacing X11 |
| **XWayland** | Compatibility layer that lets X11 apps run on Wayland |
| **Tiling WM** | Window manager that auto-arranges windows in a grid (no overlapping by default) |
| **Floating window** | A window opted out of the tile grid — you place it manually |
| **Workspace** | A virtual desktop. You have 10 + a special scratchpad |
| **Special workspace** | A "scratchpad" workspace toggled with `Super+\``; floats over the current workspace |
| **Quickshell** | The QML-based shell framework Noctalia is built on |
| **Layer shell** | Wayland protocol that lets shells draw bars/wallpapers above/below windows |
| **DPMS** | Display Power Management — turning monitors on/off |
| **PPD** | Power Profiles Daemon — exposes Performance/Balanced/Power-Saver profiles via DBus |
| **systemd unit** | A managed service definition. User units live in `~/.config/systemd/user/` |
| **dotfile** | A config file in your home directory starting with `.` |

---

## 29. Useful Links & Where to Learn More

- Hyprland wiki: https://wiki.hypr.land/
- Hyprland config reference: https://wiki.hypr.land/Configuring/Variables/
- Noctalia GitHub: https://github.com/noctalia-dev/noctalia-shell
- Quickshell docs: https://quickshell.outfoxxed.me/
- kitty docs: https://sw.kovidgoyal.net/kitty/
- atuin docs: https://docs.atuin.sh/
- ble.sh manual: https://github.com/akinomyoga/ble.sh
- Fedora Magazine (tips & tutorials): https://fedoramagazine.org/
- Arch Wiki (often the best Linux reference): https://wiki.archlinux.org/

When asking for help on Reddit (`r/hyprland`, `r/Fedora`) or Discord, share:

1. `hyprctl version`
2. The relevant section of your config
3. Logs: `journalctl --user -b 0 | tail -100` and `~/.cache/hyprland/hyprland.log`

---

---

## 30. Bluetooth

Backend: **bluez 5.86** + **blueman** GUI/applet. The Bluetooth adapter is configured for resilient reconnection and silent re-pairing.

### 30.1 Day-to-day

- Pairing / managing devices: open `blueman-manager` (search "Bluetooth" in the launcher).
- Tray icon: `blueman-applet` autostarts at login (5–6s delay) — click for quick connect/disconnect.
- CLI scan:
  ```bash
  bluetoothctl scan on
  bluetoothctl pair XX:XX:XX:XX:XX:XX
  bluetoothctl trust XX:XX:XX:XX:XX:XX
  bluetoothctl connect XX:XX:XX:XX:XX:XX
  ```

### 30.2 Tuning applied (`/etc/bluetooth/main.conf`)

```ini
[General]
JustWorksRepairing = always   # silently re-pair trusted devices
FastConnectable    = true     # quicker handshake

[Policy]
AutoEnable          = true
ReconnectAttempts   = 7
ReconnectIntervals  = 1,2,4,8,16,32,64
```

This fixes the common "device name doesn't show / reconnects fail" symptom. After changing, run `sudo systemctl restart bluetooth`.

### 30.3 Troubleshooting

| symptom | fix |
|---|---|
| "Device name shows as MAC address" | toggle the device in blueman-manager once; bluez will fetch the name and cache it |
| "Sometimes the headphone won't auto-connect" | check `bluetoothctl info <MAC>` — `Trusted: yes` is required for auto |
| "Adapter not powered on after boot" | `AutoEnable=true` should fix it; verify with `bluetoothctl show` |
| "Audio is garbled / low quality" | wireplumber probably negotiated a fallback codec; in `pavucontrol` → Configuration tab → set the device profile to A2DP-Sink AAC or LDAC |

---

## 31. Login Speed Tuning

The post-login feel was tuned to render the bar/wallpaper as quickly as possible:

1. **Brave autostart removed** — saved ~200 MB resident + ~500 ms of CPU contention with Hyprland init. Open Brave on demand (`Super+Z`).
2. **Secondary daemons staggered** in `~/.config/hypr/configs/user-overrides.conf`:
   - `t+2s`: `wallcards-video restore`
   - `t+3s`: `quickshell -c overview`
   - `t+5s`: `easyeffects --gapplication-service`
   - `t+6s`: `blueman-applet`
3. **Quickshell QML cache** at `~/.cache/quickshell/qmlcache/` — Quickshell auto-populates on first run; subsequent starts re-use it.
4. **`hyprland-guiutils` warning silenced** — added `misc:disable_hyprland_guiutils_check = true` to `user-overrides.conf`. This is the upstream-supported way to skip the package-presence check (the actual `hyprland-dialog` and `hyprland-update-screen` runtime calls are satisfied by stubs at `~/.local/bin/`).

If login still feels slow, candidates worth disabling:

- `xdg-desktop-portal-kde` (~484 ms, only used by KDE apps' file pickers — Dolphin tolerates losing it)
- Any Noctalia plugins you don't actually use (Control Center → Plugins). Each unused plugin's QML still gets scanned.

---

## 32. Scroll Sensitivity & Natural Scroll

Set in `~/.config/hypr/configs/user-overrides.conf` under the `input` block:

```hyprland
input {
    natural_scroll = true       # mouse wheel: content moves with finger
    scroll_factor = 0.5         # mouse wheel sensitivity (1.0 = default)
    touchpad {
        natural_scroll = true
        scroll_factor = 0.4     # touchpad two-finger sensitivity
    }
}
```

| value | feel |
|---|---|
| `0.3` | very slow |
| `0.4–0.5` | comfortable for most laptops |
| `0.7` | slightly tamer than default |
| `1.0` | Hyprland default |
| `1.5+` | faster than default |

App-specific overrides:

- **Brave / Chromium**: `chrome://flags/#smooth-scrolling`
- **kitty**: `wheel_scroll_min_lines 1` (in `~/.config/kitty/kitty.conf`); raise to `2-3` for fewer-but-bigger steps

After editing: `hyprctl reload`. No restart needed.

---

## 33. Caps Lock & Keyboard Options

`~/.config/hypr/configs/user-overrides.conf` controls keyboard behavior:

```hyprland
input {
    kb_layout = us
    kb_options =
}
```

- **Layout switch:** (Removed) Previously toggled between US and Turkish layouts via `Alt+Shift`.
- **Caps Lock:** acts normally (toggles uppercase). If you ever want **Caps→Escape** (a vim-user trick), set `kb_options = caps:escape`.

Other useful `kb_options`:

| value | effect |
|---|---|
| `caps:escape` | Caps Lock acts as Escape |
| `caps:swapescape` | Caps Lock and Escape swap |
| `caps:ctrl_modifier` | Caps Lock acts as Ctrl |
| `compose:rwin` | right Win key becomes Compose |
| `terminate:ctrl_alt_bksp` | Ctrl+Alt+Backspace kills X / Wayland session |

Combine with commas: `kb_options = caps:ctrl_modifier`.

---

## 34. Dotfiles Repo & sync.sh

All your customizations are mirrored in `~/dotfiles/` (a git repo).

### 34.1 Layout

```
~/dotfiles/
├── README.md, install.sh, sync.sh, .gitignore
├── home/    — mirrors into $HOME
├── system/  — needs sudo (sudoers.d, tmpfiles.d, /etc/bluetooth/main.conf, /usr/local/bin/charge-limit)
├── patches/ — diffs against system QML files
└── docs/    — this user manual
```

### 34.2 Daily workflow

```bash
cd ~/dotfiles

./sync.sh              # pull current system state into the repo
git diff               # review what changed
./sync.sh -c "tweak: scroll factor 0.4 for trackpad"
                       # same as above + auto-commit with message
git push               # push to GitHub (after `gh auth login` once)
```

`sync.sh` is idempotent — files identical to the source are untouched. With `--delete` on whole-tree mirrors (hypr/, kitty/, fastfetch/, plugins/), files removed from your system also disappear from the repo.

### 34.3 Bootstrapping a new machine

```bash
git clone https://github.com/<you>/dotfiles ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh` does:

1. enable solopasha/hyprland COPR + Flathub
2. dnf-install all packages
3. clone & build ble.sh
4. mirror `home/` → `$HOME` (existing files backed up as `*.preinst.bak`)
5. install `system/` files via sudo
6. patch Noctalia's `HyprlandService.qml` for the spawn-path optimization
7. enable `prewarm-apps.timer`
8. apply boot battery threshold

Re-running is safe — it always overwrites with the latest repo state.

### 34.4 What's not in the repo

`.gitignore` excludes:

- `home/.cache/`, `home/.local/state/` — regenerable
- `home/.config/atuin/history.db` — your private shell history
- `home/.config/BraveSoftware/`, `home/.mozilla/` — browser profiles with credentials
- Quickshell runtime sockets/logs (`by-id`, `*.qslog`, `*.lock`)
- `**/*.bak`, `**/*~` — backups

If you add new directories or files outside the patterns `sync.sh` already covers, edit `sync.sh` to include them — it's a 100-line bash script, easy to extend.

---

*Last updated: based on the live state of this machine after our setup session. Edit freely as you change things — this file is yours.*

---

## 35. Professional SDDM Login Screen (Noctalia-Aligned)

A fully customized, professional SDDM login theme (`noctalia`) modeled after the Noctalia desktop shell's premium aesthetic.

### 35.1 File Architecture & Paths
All theme files are located in:
* **Real System Location:** `/usr/share/sddm/themes/noctalia/`
* **Dotfiles Mirror:** `~/dotfiles/system/usr/share/sddm/themes/noctalia/`

Key Files:
* `Main.qml` — The core logic, design, styling, and animations of the login theme.
* `theme.conf` — SDDM configuration options (e.g., custom background image).
* `fonts/` — Embedded font files (`Montserrat-Regular.otf` and `noctalia-tabler-icons.ttf`).

### 35.2 How to Customize & Configure

#### 35.2.1 Changing the Background Wallpaper
The theme respects the background path set in `/usr/share/sddm/themes/noctalia/theme.conf`.
To change it, edit `/usr/share/sddm/themes/noctalia/theme.conf` and update the `background` property:
```ini
[General]
background=/path/to/your/wallpaper.png
```

#### 35.2.2 Tuning the Resolution Scaling Ratio
If elements appear too large or too small on your specific monitor, you can adjust the scaling engine in `/usr/share/sddm/themes/noctalia/Main.qml`.
Look for `scaleRatio` around line 9:
```qml
readonly property real scaleRatio: {
    var ratio = Screen.width / 1920.0;
    // Tweak 1.35 (baseline multiplier) and 3.5 (maximum clamp) as desired:
    return Math.max(1.35, Math.min(ratio * 1.35, 3.5));
}
```

#### 35.2.3 Customizing Password Characters (Tabler Sequence)
The dynamic character sequence shown as you type is mapped inside `/usr/share/sddm/themes/noctalia/Main.qml` via:
```qml
readonly property var passwordChars: ["\uf671", "\uf68c", "\u{1000c}", "\uf6a5", "\uf67b", "\ufeb1", "\uf6ad"]
```
These are Unicode sequences corresponding to custom Tabler symbols in the loaded font.

### 35.3 Troubleshooting & Reference

#### 35.3.1 GNOME is Selected Instead of Hyprland on Startup
* **Symptom:** On system boot, the session dropdown defaults to GNOME, requiring you to manually switch back to Hyprland every time.
* **The Fix:** This issue is solved by a delayed startup synchronization script in `Main.qml` (under the `focusTimerSlow` block around line 830). It waits `300ms` for the asynchronous SDDM C++ models to register, then queries `sessionModel.lastIndex`. If no index is saved, it searches the session list for a case-insensitive match for `"hyprland"` (excluding `"uwsm"`) and auto-selects it.

#### 35.3.2 Password Input Field Does Not Have Keyboard Focus
* **Symptom:** You cannot immediately start typing your password on boot.
* **The Fix:** The theme runs a dual-timer focus loop on startup:
  * `focusTimer` (`100ms` delay): Triggers an immediate focus request.
  * `focusTimerSlow` (`300ms` delay): Retries focus once the interface has fully rendered.
  * If focus is ever lost, clicking the background or closing a dropdown automatically returns active focus to the password field (`pwField`).

---

## 36. Universal Package Manager Bridge (`sysupdate` & `sysfind`)

To streamline packages and system updates between different Linux conventions (specifically bridging legacy Arch Linux aliases to Fedora's `dnf5` and `flatpak`), we have implemented a unified package bridge.

### 36.1 Command Utilities
These wrapper scripts live in `~/.local/bin/` and automatically route execution to the correct tools:
*   **`sysupdate`** (`~/.local/bin/sysupdate`): 
    *   Detects the system's package manager (`dnf5`, `dnf`, `pacman/yay/paru`, or `apt`).
    *   Runs the native upgrade commands (e.g. `dnf5 upgrade` on Fedora).
    *   Runs Flatpak upgrades if Flatpak is installed (`flatpak update -y`).
    *   Sends desktop notifications via `notify-send` when the update process starts and ends.
*   **`sysfind <query>`** (`~/.local/bin/sysfind`):
    *   Fuzzy-searches both the system repositories (using `dnf5 search` or equivalent) and flatpak applications simultaneously.

### 36.2 Shell Integration
The shell configs (`~/.config/fish/config.fish` and `~/.zshrc`) are configured to route common tasks to the bridge:
*   `update` -> runs `sysupdate`
*   `findpkg` -> runs `sysfind <package_name>`
*   `big` -> uses a native, high-performance query (`rpm -qa --queryformat ...`) to list the top 50 largest installed packages on your system.

---

## 37. Wayland Clipboard Persistence Service (`wl-clip-persist`)

Under Wayland, copied text/data is natively tied to the lifecycle of the window that copied it. When that application is closed, the clipboard content is lost.

To resolve this, we compiled and installed `wl-clip-persist` from source and set up a managed background daemon.

### 37.1 Daemon Configuration & Management
*   **Binary Location:** `~/.local/bin/wl-clip-persist`
*   **Systemd User Service:** `~/.config/systemd/user/wl-clip-persist.service`
*   **Auto-start:** Started automatically on session login via systemd target dependencies.

To verify or manage the service manually:
```bash
# Check service status
systemctl --user status wl-clip-persist.service

# Restart service
systemctl --user restart wl-clip-persist.service
```

---

## 38. Dedicated GPU Launcher Wrapper (`nvrun`)

Your workstation is a hybrid graphics setup (Intel UHD integrated graphics + NVIDIA RTX 4050 mobile dedicated graphics). By default, applications run on the low-power Intel graphics to conserve energy and keep the system cool.

### 38.1 Launching Demanding Applications
For heavy 3D workloads, gaming, or GPU-intensive software, you can prepend **`nvrun`** before the launch command in the terminal:
```bash
nvrun <application-name>

# Example: Run blender on the RTX 4050
nvrun blender
```

### 38.2 Under the Hood
The `nvrun` wrapper script (`~/.local/bin/nvrun`) exports Wayland/NVIDIA render offload targets:
```bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export DRI_PRIME=1
```
This forces the graphics server to steer the application's rendering pipeline directly onto the RTX 4050 GPU.

---

## 39. Elan Match-on-Chip Fingerprint Setup

Your laptop features an **Elan Match-on-Chip 2 (MOC2) fingerprint reader** (`04f3:0c90`) integrated system-wide into the Pluggable Authentication Modules (PAM) stack.

### 39.1 Key Features & Workflow
*   **Terminal & Lock Screen Logins:** Type your password or touch the fingerprint scanner. The PAM stack evaluates both simultaneously.
*   **Polkit Authentication agent:** The custom Noctalia Polkit window (`pkexec` popup) has a unified design. Both the fingerprint scanner icon and the password entry field are displayed at the same time. The password text field is focused on startup, allowing you to instantly type your password or scan your fingerprint with zero delay.
*   **Sub-Second Password Fallback:** The custom compiled `libfprint` driver aborts any active fingerprint scans in under **100ms** when you start typing your password, preventing the PAM stack from hanging or freezing.

### 39.2 Technical Documentation
For full details on the custom patches implemented in the Elan driver (including buffer expansion, signature reconstruction, wrong-touch databases preservation, and cancellation timeouts), refer to:
*   [docs/fingerprint_setup.md](file:///home/ldzbeta/dotfiles/docs/fingerprint_setup.md) — Comprehensive build guide and reverse-engineering logs.
*   [docs/latency_fix_details.md](file:///home/ldzbeta/dotfiles/docs/latency_fix_details.md) — Low-level analysis of the 100ms and 2-second timeout optimizations.

To restart the fingerprint daemon:
```bash
sudo systemctl restart fprintd.service
```