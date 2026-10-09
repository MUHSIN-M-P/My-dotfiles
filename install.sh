#!/usr/bin/env bash
# install.sh — bootstrap a new Fedora machine to match this Hyprland +
# Noctalia v5 (C++) + Noctalia Greeter (greetd) setup. Idempotent: re-running upgrades in place.
#
# Run from inside the cloned repo:
#   git clone https://github.com/<you>/dotfiles ~/dotfiles
#   cd ~/dotfiles && ./install.sh
#

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[ -n "$HOME_DIR" ] && [ -d "$HOME_DIR" ] || die "Cannot resolve a home directory for user '$USER_NAME'."

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m## %s\033[0m\n' "$*" >&2; exit 1; }

[ -d "$HERE/home" ] || die "Run this script from the dotfiles repo root."
command -v dnf >/dev/null || die "dnf not found; this script targets Fedora."

if [ "$(id -u)" = 0 ]; then
  die "Run as your normal user (not root, not sudo). The script calls sudo itself where needed."
fi

REPO_OWNER="ldzbeta"
PROFILE_LABEL="Noctalia v5 Native (C++) + Greeter"

say "Target profile: $PROFILE_LABEL"

#------------------------------------------------------------------------------
say "1/8  Enabling solopasha/hyprland COPR + Flathub"
#------------------------------------------------------------------------------
sudo dnf -y copr enable solopasha/hyprland 2>/dev/null || true
sudo dnf -y install flatpak >/dev/null || warn "flatpak install failed; Flathub setup skipped."
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null \
  || warn "Flathub remote setup failed (offline?); continuing."

#------------------------------------------------------------------------------
say "2/8  Installing packages (dnf)"
#------------------------------------------------------------------------------
PKGS=(
  # core compositor & greeter
  hyprland greetd cage wlr-randr
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
  # build tools & C++ libraries (for compiling Noctalia & Greeter)
  meson ninja-build gcc gcc-c++ clang pkgconf-pkg-config
  wayland-devel wayland-protocols-devel libxkbcommon-devel
  cairo-devel pango-devel librsvg2-devel libxml2-devel glib2-devel
  tomlplusplus-devel json-devel libwebp-devel libjxl-devel libsndfile-devel
  sdbus-cpp-devel libsecret-devel libsodium-devel libqalculate-devel libical-devel
  systemd-devel dbus-devel pam-devel polkit-devel
  # dnf utilities
  dnf-utils
)
sudo dnf -y install "${PKGS[@]}" || warn "Some packages failed; continuing."

#------------------------------------------------------------------------------
say "3/8  Building external helpers (ble.sh & wl-clip-persist)"
#------------------------------------------------------------------------------
if [ ! -d "$HOME_DIR/.local/share/blesh" ]; then
  tmp=$(mktemp -d)
  if git clone --depth 1 --recursive https://github.com/akinomyoga/ble.sh.git "$tmp" &&
     ( cd "$tmp" && make install PREFIX="$HOME_DIR/.local" ); then
    say "  ble.sh installed."
  else
    warn "ble.sh install failed (network/git/make?); continuing without it."
  fi
  rm -rf "$tmp"
fi

if ! [ -f "$HOME_DIR/.local/bin/wl-clip-persist" ] && command -v cargo >/dev/null; then
  say "Compiling wl-clip-persist from source..."
  sudo -u "$USER_NAME" -H cargo install --git https://github.com/Linus789/wl-clip-persist --root "$HOME_DIR/.local" \
    || warn "wl-clip-persist build failed; continuing without it."
fi

#------------------------------------------------------------------------------
say "4/8  Compiling / Installing Noctalia v5 and Noctalia Greeter (C++)"
#------------------------------------------------------------------------------
# Build Noctalia Shell if source repository exists
if [ -d "$HOME_DIR/noctalia" ]; then
  say "Building Noctalia v5 (C++)..."
  (
    cd "$HOME_DIR/noctalia"
    if [ ! -d "build-release" ]; then
      meson setup build-release --buildtype=release --prefix="$HOME_DIR/.local"
    fi
    ninja -C build-release
    ninja -C build-release install
  ) || warn "Noctalia compilation/installation failed."
fi

# Build Noctalia Greeter if source repository exists
if [ -d "$HOME_DIR/noctalia-greeter" ]; then
  say "Building Noctalia Greeter (C++)..."
  (
    cd "$HOME_DIR/noctalia-greeter"
    if [ ! -d "build-release" ]; then
      meson setup build-release --buildtype=release --prefix=/usr
    fi
    ninja -C build-release
    if [ -f "./install.sh" ]; then
      sudo ./install.sh
    else
      sudo ninja -C build-release install
    fi
  ) || warn "Noctalia Greeter compilation/installation failed."
fi

#------------------------------------------------------------------------------
say "5/8  Mirroring ./home/* into \$HOME"
#------------------------------------------------------------------------------
( cd "$HERE/home" && find . -type f ) | while IFS= read -r f; do
  src="$HERE/home/$f"
  dst="$HOME_DIR/$f"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    cp -a "$dst" "$dst.preinst.bak"
  fi
  install -D -m "$(stat -c %a "$src")" "$src" "$dst"
done

# Ensure helper scripts in ~/.local/bin are executable
if [ -d "$HOME_DIR/.local/bin" ]; then
  chmod +x "$HOME_DIR/.local/bin/"* 2>/dev/null || true
fi

# Rehome user-bound absolute paths baked into the repo
if [ "$USER_NAME" != "$REPO_OWNER" ]; then
  say "  Rehoming /home/$REPO_OWNER → /home/$USER_NAME in deployed configs"
  for f in settings.json config.toml; do
    target="$HOME_DIR/.config/noctalia/$f"
    if [ -f "$target" ] && grep -q "/home/$REPO_OWNER" "$target"; then
      sed -i "s|/home/$REPO_OWNER|/home/$USER_NAME|g" "$target"
      echo "  rehomed: $target"
    fi
  done
fi

#------------------------------------------------------------------------------
say "6/8  Applying system configs (greetd, greeter, limits, PAM, udev)"
#------------------------------------------------------------------------------
deploy_sys() {
  local mode="$1" src="$2" dst="$3"
  if [ ! -f "$src" ]; then
    warn "Repo file missing, skipping: $src"
    return 0
  fi
  sudo mkdir -p "$(dirname "$dst")"
  sudo install -m "$mode" "$src" "$dst"
}

deploy_sudoers() {
  local src="$1" name="$2"
  if [ ! -f "$src" ]; then
    warn "Repo file missing, skipping: $src"
    return 0
  fi
  local tmp
  tmp=$(mktemp)
  sed "s/$REPO_OWNER/$USER_NAME/g" "$src" > "$tmp"
  if sudo visudo -c -f "$tmp" >/dev/null; then
    sudo install -m 0640 "$tmp" "/etc/sudoers.d/$name"
  else
    warn "Refusing to install $name: visudo validation failed."
  fi
  rm -f "$tmp"
}

deploy_sudoers "$HERE/system/etc/sudoers.d/charge-limit" charge-limit
deploy_sudoers "$HERE/system/etc/sudoers.d/asus-fan-control" asus-fan-control
deploy_sys 0644 "$HERE/system/etc/tmpfiles.d/charge-limit.conf" /etc/tmpfiles.d/charge-limit.conf
deploy_sys 0755 "$HERE/system/usr/local/bin/charge-limit" /usr/local/bin/charge-limit
deploy_sys 0755 "$HERE/system/usr/local/bin/asus-fan-control" /usr/local/bin/asus-fan-control

# Bluetooth
if [ -f "$HERE/system/etc/bluetooth/main.conf" ]; then
  deploy_sys 0644 "$HERE/system/etc/bluetooth/main.conf" /etc/bluetooth/main.conf
fi

# Systemd Limits
deploy_sys 0644 "$HERE/system/etc/systemd/system.conf.d/limits.conf" /etc/systemd/system.conf.d/limits.conf
deploy_sys 0644 "$HERE/system/etc/systemd/user.conf.d/limits.conf" /etc/systemd/user.conf.d/limits.conf

# Background services override files
for s in dnf-makecache fstrim packagekit plocate-updatedb; do
  deploy_sys 0644 "$HERE/system/etc/systemd/system/$s.service.d/override.conf" "/etc/systemd/system/$s.service.d/override.conf"
done

# Boot scaling and libfprint services
if [ -f "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service" ]; then
  deploy_sys 0644 "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service" /etc/systemd/system/tuned-bootfast-reset.service
  sudo systemctl daemon-reload
  sudo systemctl enable tuned-bootfast-reset.service
fi

if [ -f "$HERE/system/etc/systemd/system/libfprint-custom.service" ]; then
  deploy_sys 0644 "$HERE/system/etc/systemd/system/libfprint-custom.service" /etc/systemd/system/libfprint-custom.service
  sudo systemctl daemon-reload
  sudo systemctl enable libfprint-custom.service
fi

if [ -f "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules" ]; then
  deploy_sys 0644 "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules" /etc/udev/rules.d/70-libfprint-0c90.rules
  if command -v udevadm >/dev/null; then
    sudo udevadm control --reload-rules && sudo udevadm trigger || true
  fi
fi

# Greetd & Noctalia Greeter setup
say "Deploying Greetd & Noctalia Greeter configs..."
deploy_sys 0644 "$HERE/system/etc/greetd/config.toml" /etc/greetd/config.toml
deploy_sys 0644 "$HERE/system/etc/greetd/environments" /etc/greetd/environments
deploy_sys 0644 "$HERE/system/etc/pam.d/greetd" /etc/pam.d/greetd
deploy_sys 0644 "$HERE/system/etc/pam.d/greetd-greeter" /etc/pam.d/greetd-greeter
deploy_sys 0644 "$HERE/system/usr/share/wayland-sessions/noctalia-v5.desktop" /usr/share/wayland-sessions/noctalia-v5.desktop
deploy_sys 0644 "$HERE/system/usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy" /usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy
deploy_sys 0755 "$HERE/system/usr/bin/noctalia-greeter-session" /usr/bin/noctalia-greeter-session
deploy_sys 0755 "$HERE/system/usr/bin/noctalia-greeter-print-greetd-config" /usr/bin/noctalia-greeter-print-greetd-config
deploy_sys 0755 "$HERE/system/usr/share/noctalia-greeter/noctalia-greeter-cage-entry" /usr/share/noctalia-greeter/noctalia-greeter-cage-entry

if [ -f "$HERE/system/usr/share/noctalia-greeter/assets/noctalia.svg" ]; then
  deploy_sys 0644 "$HERE/system/usr/share/noctalia-greeter/assets/noctalia.svg" /usr/share/noctalia-greeter/assets/noctalia.svg
fi

# Greeter state directory
if [ -f "$HERE/system/var/lib/noctalia-greeter/greeter.toml" ]; then
  sudo mkdir -p /var/lib/noctalia-greeter
  deploy_sys 0666 "$HERE/system/var/lib/noctalia-greeter/greeter.toml" /var/lib/noctalia-greeter/greeter.toml
  sudo chown -R greeter:greeter /var/lib/noctalia-greeter 2>/dev/null || true
  sudo chmod 775 /var/lib/noctalia-greeter 2>/dev/null || true
fi

# Enable greetd display manager, disable sddm
sudo systemctl disable sddm.service 2>/dev/null || true
sudo systemctl enable greetd.service 2>/dev/null || true

# Optimize boot time by masking NetworkManager-wait-online.service
sudo systemctl mask NetworkManager-wait-online.service

# Dual-auth PAM configurations (sudo, polkit)
for f in sudo polkit-1; do
  if [ -f "$HERE/system/etc/pam.d/$f" ]; then
    deploy_sys 0644 "$HERE/system/etc/pam.d/$f" "/etc/pam.d/$f"
  fi
done

#------------------------------------------------------------------------------
say "7/8  Enabling systemd user services"
#------------------------------------------------------------------------------
systemctl --user daemon-reload
systemctl --user enable --now prewarm-apps.timer 2>/dev/null || warn "Could not enable prewarm-apps.timer."
systemctl --user enable --now wl-clip-persist.service 2>/dev/null || warn "Could not enable wl-clip-persist.service."
systemctl --user enable --now hypr-resume-handler.service 2>/dev/null || warn "Could not enable hypr-resume-handler.service."

#------------------------------------------------------------------------------
say "8/8  Applying battery threshold & finalizing"
#------------------------------------------------------------------------------
sudo systemd-tmpfiles --create /etc/tmpfiles.d/charge-limit.conf || true
sudo systemctl restart bluetooth 2>/dev/null || true

cat <<EOF

=======================================================
 Noctalia v5 + Noctalia Greeter Installation Complete!
=======================================================

Components configured:
  ✔ Hyprland compositor
  ✔ Noctalia v5 native shell daemon (C++)
  ✔ Noctalia Greeter login screen with greetd
  ✔ System appearance & wallpaper syncing
  ✔ Fast boot & battery limits

Next steps:
  1. To test the greeter: reboot or restart greetd service
  2. To re-sync or compile at any time: run ./sync.sh
EOF
