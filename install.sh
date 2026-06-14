#!/usr/bin/env bash
# install.sh — bootstrap a new Fedora 43+ machine to match this Hyprland +
# Noctalia setup. Idempotent: re-running upgrades in place.
#
# Run from inside the cloned repo:
#   git clone https://github.com/<you>/dotfiles ~/dotfiles
#   cd ~/dotfiles && ./install.sh
#
# Steps performed:
#   1. enable solopasha/hyprland COPR + add Flathub
#   2. dnf install required packages
#   3. install ble.sh into ~/.local/share/blesh
#   4. mirror ./home/* into $HOME (with backups for any existing files)
#   5. mirror ./system/* into / (sudo) — sudoers.d, tmpfiles.d, bluetooth, /usr/local/bin
#   6. apply system-level QML patches (Noctalia spawn-path tuning)
#   7. enable systemd user timer for prewarm-apps
#   8. systemd-tmpfiles --create to set the boot battery threshold
#   9. final reload hint
#
# Re-run is safe.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m## %s\033[0m\n' "$*" >&2; exit 1; }

[ -d "$HERE/home" ] || die "Run this script from the dotfiles repo root."
command -v dnf >/dev/null || die "dnf not found; this script targets Fedora."

#------------------------------------------------------------------------------
say "1/9  Enabling solopasha/hyprland COPR + Flathub"
#------------------------------------------------------------------------------
sudo dnf -y copr enable solopasha/hyprland 2>/dev/null || true
sudo dnf -y install flatpak >/dev/null
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

#------------------------------------------------------------------------------
say "2/9  Installing packages (dnf)"
#------------------------------------------------------------------------------
PKGS=(
  # core compositor & shell
  hyprland noctalia-qs quickshell
  # terminal & shell tools
  kitty fastfetch atuin bash-completion git stow
  # wallpaper / video
  mpvpaper ffmpeg ImageMagick
  # screenshot / screen tools
  hyprpicker grim slurp wl-clipboard cliphist
  # audio / media
  easyeffects pipewire-pulseaudio playerctl
  # bluetooth
  bluez bluez-libs blueman
  # power / battery
  tuned-ppd vmtouch
  # GUI helpers
  nautilus nwg-displays pavucontrol nm-connection-editor gnome-control-center gnome-software
  # apps
  brave-browser
  # fonts
  rsms-inter-fonts jetbrains-mono-fonts-all google-noto-emoji-fonts
  # dnf utilities
  dnf-utils
)
sudo dnf -y install "${PKGS[@]}" || warn "Some packages failed; continuing."

#------------------------------------------------------------------------------
say "3/9  Building external helpers (ble.sh & wl-clip-persist)"
#------------------------------------------------------------------------------
if [ ! -d "$HOME_DIR/.local/share/blesh" ]; then
  tmp=$(mktemp -d)
  git clone --depth 1 --recursive https://github.com/akinomyoga/ble.sh.git "$tmp"
  ( cd "$tmp" && make install PREFIX="$HOME_DIR/.local" )
  rm -rf "$tmp"
fi

if ! [ -f "$HOME_DIR/.local/bin/wl-clip-persist" ] && command -v cargo >/dev/null; then
  say "Compiling wl-clip-persist from source..."
  sudo -u "$USER_NAME" -H cargo install --git https://github.com/Linus789/wl-clip-persist --root "$HOME_DIR/.local"
fi

#------------------------------------------------------------------------------
say "4/9  Mirroring ./home/* into \$HOME (backups: existing files → *.preinst.bak)"
#------------------------------------------------------------------------------
( cd "$HERE/home" && find . -type f ) | while IFS= read -r f; do
  src="$HERE/home/$f"
  dst="$HOME_DIR/$f"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    cp -a "$dst" "$dst.preinst.bak"
  fi
  install -D -m "$(stat -c %a "$src")" "$src" "$dst"
done

#------------------------------------------------------------------------------
say "5/9  Applying ./system/* (needs sudo)"
#------------------------------------------------------------------------------
sudo install -m 0640 "$HERE/system/etc/sudoers.d/charge-limit" /etc/sudoers.d/charge-limit
sudo install -m 0644 "$HERE/system/etc/tmpfiles.d/charge-limit.conf" /etc/tmpfiles.d/charge-limit.conf
sudo install -m 0755 "$HERE/system/usr/local/bin/charge-limit" /usr/local/bin/charge-limit
# Bluetooth main.conf — back up existing, then install ours.
if [ -f /etc/bluetooth/main.conf ] && ! cmp -s "$HERE/system/etc/bluetooth/main.conf" /etc/bluetooth/main.conf; then
  sudo cp -a /etc/bluetooth/main.conf /etc/bluetooth/main.conf.preinst.bak
fi
sudo install -m 0644 "$HERE/system/etc/bluetooth/main.conf" /etc/bluetooth/main.conf

# Systemd Limits config
sudo mkdir -p /etc/systemd/system.conf.d /etc/systemd/user.conf.d
sudo install -m 0644 "$HERE/system/etc/systemd/system.conf.d/limits.conf" /etc/systemd/system.conf.d/limits.conf
sudo install -m 0644 "$HERE/system/etc/systemd/user.conf.d/limits.conf" /etc/systemd/user.conf.d/limits.conf

# Boot scaling service reset for fast boot
if [ -f "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service" ]; then
  sudo install -m 0644 "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service" /etc/systemd/system/tuned-bootfast-reset.service
  sudo systemctl daemon-reload
  sudo systemctl enable tuned-bootfast-reset.service
fi

# Custom libfprint restoration service for fingerprint sensor
if [ -f "$HERE/system/etc/systemd/system/libfprint-custom.service" ]; then
  sudo install -m 0644 "$HERE/system/etc/systemd/system/libfprint-custom.service" /etc/systemd/system/libfprint-custom.service
  sudo systemctl daemon-reload
  sudo systemctl enable libfprint-custom.service
fi

# Systemd background services override files for perceived responsiveness
for s in dnf-makecache fstrim packagekit plocate-updatedb; do
  sudo mkdir -p /etc/systemd/system/"$s".service.d
  sudo install -m 0644 "$HERE/system/etc/systemd/system/$s.service.d/override.conf" /etc/systemd/system/"$s".service.d/override.conf
done

# Optimize boot time by masking NetworkManager-wait-online.service
sudo systemctl mask NetworkManager-wait-online.service

# Enable fingerprint authentication in authselect
if command -v authselect >/dev/null; then
  sudo authselect select local with-fingerprint --force || warn "Could not enable with-fingerprint in authselect"
fi

# PAM configurations for dual-auth (fingerprint + password)
sudo mkdir -p /etc/pam.d
for f in sudo sddm polkit-1; do
  if [ -f "$HERE/system/etc/pam.d/$f" ]; then
    if [ -f "/etc/pam.d/$f" ] && ! cmp -s "$HERE/system/etc/pam.d/$f" "/etc/pam.d/$f"; then
      sudo cp -a "/etc/pam.d/$f" "/etc/pam.d/$f.preinst.bak"
    fi
    sudo install -m 0644 "$HERE/system/etc/pam.d/$f" "/etc/pam.d/$f"
  fi
done

# SDDM Theme Installation
if [ -d "$HERE/system/usr/share/sddm/themes/noctalia" ]; then
  say "Installing SDDM Noctalia Theme..."
  sudo mkdir -p /usr/share/sddm/themes/noctalia
  sudo rsync -a --delete "$HERE/system/usr/share/sddm/themes/noctalia/" /usr/share/sddm/themes/noctalia/
  
  # Register & Enable theme in sddm.conf.d
  sudo mkdir -p /etc/sddm.conf.d
  sudo tee /etc/sddm.conf.d/noctalia.conf >/dev/null <<'CONFIG'
[Theme]
Current=noctalia
CONFIG
fi

#------------------------------------------------------------------------------
say "6/9  Patching Noctalia system QML (faster launcher + UI contrast)"
#------------------------------------------------------------------------------
TARGET=/etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml
if [ -f "$TARGET" ] && ! grep -q '(local) skip hyprctl indirection' "$TARGET"; then
  sudo cp -a "$TARGET" "$TARGET.bak"
  sudo sed -i 's|Quickshell.execDetached(\["hyprctl", "dispatch", "--", "exec"\].concat(command));|Quickshell.execDetached(command);  // (local) skip hyprctl indirection for faster launch|' "$TARGET"
fi

# Apply UI Contrast Tweaks (Popup menus and top bar)
sudo sed -i 's/property color color: Color.mSurfaceVariant/property color color: Qt.lighter(Color.mSurfaceVariant, 1.51)/g' /etc/xdg/quickshell/noctalia-shell/Widgets/NBox.qml
sudo sed -i 's/color: showOnlyLists ? Color.mSurfaceVariant : "transparent"/color: showOnlyLists ? Qt.lighter(Color.mSurfaceVariant, 1.51) : "transparent"/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml
sudo sed -i 's/color: addHiddenMouseArea.containsMouse ? Color.mSurfaceVariant : Color.mSurface/color: addHiddenMouseArea.containsMouse ? Qt.lighter(Color.mSurfaceVariant, 1.51) : Color.mSurface/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml
sudo sed -i 's/colorBg: Color.mSurfaceVariant/colorBg: Qt.lighter(Color.mSurfaceVariant, 1.51)/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Network/NetworkPanel.qml
sudo sed -i 's/color: Color.mSurfaceVariant/color: Qt.lighter(Color.mSurfaceVariant, 1.51)/g' /etc/xdg/quickshell/noctalia-shell/Modules/Panels/Network/NetworkPanel.qml
sudo sed -i 's/: Color.mSurfaceVariant, Settings.data.bar.capsuleOpacity)/: "#252629", Settings.data.bar.capsuleOpacity)/g' /etc/xdg/quickshell/noctalia-shell/Commons/Style.qml

#------------------------------------------------------------------------------
say "7/9  Enabling systemd user services (prewarm-apps & wl-clip-persist)"
#------------------------------------------------------------------------------
systemctl --user daemon-reload
systemctl --user enable --now prewarm-apps.timer 2>/dev/null || warn "Could not enable prewarm-apps.timer (run again after first login)."
systemctl --user enable --now wl-clip-persist.service 2>/dev/null || warn "Could not enable wl-clip-persist.service (run again after first login)."

#------------------------------------------------------------------------------
say "8/9  Applying boot battery-charge threshold"
#------------------------------------------------------------------------------
sudo systemd-tmpfiles --create /etc/tmpfiles.d/charge-limit.conf || true
sudo systemctl restart bluetooth || true

#------------------------------------------------------------------------------
say "9/9  Done."
#------------------------------------------------------------------------------
cat <<'EOF'

Next steps:

  1. Reboot, OR run `hyprctl reload` if you're already in a Hyprland session.
  2. Open a new kitty: fastfetch + ble.sh + atuin should be live.
  3. Wallpapers: drop images/videos in ~/Pictures/Wallpapers/, then Super+Y.
  4. Bluetooth: run `bluetoothctl scan on` and pair via blueman-applet (tray).

Read docs/HYPRLAND_NOCTALIA_USER_MANUAL.md for the full feature tour.

If anything looks wrong, see *.preinst.bak files in your home dir
and /etc/ — those are the originals before this script ran.
EOF
