#!/usr/bin/env bash
# sync.sh — pull current system state back into this dotfiles repo, or run dashboard.
# Refurbished for Noctalia v5 (C++) + Noctalia Greeter (greetd).
#
# Usage:
#   ./sync.sh              # launches interactive dashboard
#   ./sync.sh --drift      # check drift status (system vs repo)
#   ./sync.sh --diff       # view diffs
#   ./sync.sh --scan       # scan untracked configs
#   ./sync.sh --pull       # pull/sync system to repo
#   ./sync.sh --build      # recompile Noctalia v5 & Greeter from C++ sources
#   ./sync.sh -c "msg"     # pull + commit (no push)
#   ./sync.sh -d           # dry-run pull
#

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
COMMIT_MSG=""
DRYRUN=0
CLI_ACTION=""

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -c|--commit) COMMIT_MSG="${2:-}"; shift 2 || shift ;;
    -d|--dry-run) DRYRUN=1; shift ;;
    --drift|-1) CLI_ACTION="drift"; shift ;;
    --diff|-2) CLI_ACTION="diff"; shift ;;
    --scan|-3) CLI_ACTION="scan"; shift ;;
    --install|-4) CLI_ACTION="install"; shift ;;
    --pull|-5) CLI_ACTION="pull"; shift ;;
    --build|-6) CLI_ACTION="build"; shift ;;
    --stow|-7) CLI_ACTION="stow"; shift ;;
    -h|--help) sed -n '/^# Usage:/,/^$/p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

BRANCH="$(git -C "$HERE" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
NOCTALIA_LIVE="$HOME/.config/noctalia"
NOCTALIA_REPO="$HERE/home/.config/noctalia"
PROFILE_LABEL="Noctalia v5 Native (C++) + Greeter"

# Helper: simple copy respects dry-run
CP() {
  if [ "$DRYRUN" = 1 ]; then
    [ -e "$1" ] && echo "would copy: $1 → $2" || true
  else
    [ -e "$1" ] && install -D "$1" "$2" || true
  fi
}

# Helper: rsync respects dry-run
R() {
  local args=(-a)
  [ "$DRYRUN" = 1 ] && args+=(-n -v)
  rsync "${args[@]}" "$@"
}

# Helper: sudo copy
SUDO_CP() {
  if [ "$DRYRUN" = 1 ]; then
    [ -e "$1" ] && echo "would sudo-copy: $1 → $2" || true
  else
    if [ -e "$1" ]; then
      if [ -r "$1" ]; then
        cp -a "$1" "$2"
      else
        sudo cp -a "$1" "$2"
        sudo chown "$USER:$USER" "$2" 2>/dev/null || true
      fi
    fi
  fi
}

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Single source of truth for what's managed.
# ---------------------------------------------------------------------------
# Plain directories under ~/.config mirrored whole.
CONFIG_DIRS=(hypr kitty fastfetch xdg-desktop-portal foot fuzzel waybar cava
  yazi Kvantum qt5ct qt6ct cliphist)

# Helper scripts under ~/.local/bin tracked individually.
HELPER_SCRIPTS=(
  # Noctalia v5 helpers & session
  noctalia-session-start noctalia-startup-manager start-noctalia-v5
  noctalia-greeting noctalia-ipc noctalia-session-cleanup noctalia-smart-paste
  show-keybinds
  # System & desktop helpers
  charge-limit wallcards-video prewarm-apps toggle-fan-profile toggle-fullarea
  hyprland-dialog hyprland-update-screen hyprland-guiutils
  restore-power-profile waybarctl sysupdate sysfind nvrun sys-stats-period
  fetch-wallpapers touchpad-gestures-daemon unlock-keyring.sh setup-keyring-tpm.sh
  ds dv gpu-status hypr-display hypr-resume-handler.sh hypr-resume-handler.py
)

# systemd user units we manage.
USER_UNITS=(prewarm-apps.service prewarm-apps.timer wl-clip-persist.service
  hypr-resume-handler.service)

# Junk that must never enter the repo.
JUNK_EXCLUDES=(--exclude='*.bak*' --exclude='*.backup*'
  --exclude='*~' --exclude='.Trash-*/' --exclude='__pycache__/'
  --exclude='*.pyc' --exclude='shell.log' --exclude='pinned_clipboard.json')

# -----------------------------------------------------------------------------
# Pull logic (Sync from active system into the git repo)
# -----------------------------------------------------------------------------
pull_from_system() {
  say "1/5  Mirroring compositor & application configs  [$PROFILE_LABEL]"
  local common_excludes=(
    --exclude='__pycache__/'
    --exclude='*.pyc'
    --exclude='*.pyo'
    --exclude='*.log'
    --exclude='*.lock'
    --exclude='by-id'
    --exclude='by-pid'
    --exclude='.git'
    "${JUNK_EXCLUDES[@]}"
  )

  for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$HOME/.config/$dir" ]; then
      R --delete "${common_excludes[@]}" "$HOME/.config/$dir/" "$HERE/home/.config/$dir/"
    fi
  done

  # Noctalia v5: configuration, palettes, themes, templates, keybinds, plugins
  if [ -d "$NOCTALIA_LIVE" ]; then
    mkdir -p "$NOCTALIA_REPO"
    R --delete "${common_excludes[@]}" "$NOCTALIA_LIVE/" "$NOCTALIA_REPO/"
  fi

  # systemd user units
  if [ -d "$HOME/.config/systemd/user" ]; then
    mkdir -p "$HERE/home/.config/systemd/user"
    for u in "${USER_UNITS[@]}"; do
      CP "$HOME/.config/systemd/user/$u" "$HERE/home/.config/systemd/user/$u"
    done
  fi

  say "2/5  Single-file desktop configs & icons"
  CP "$HOME/.bashrc"                                        "$HERE/home/.bashrc"
  [ -f "$HOME/.blerc" ] && CP "$HOME/.blerc"                "$HERE/home/.blerc"
  CP "$HOME/.config/atuin/config.toml"                      "$HERE/home/.config/atuin/config.toml"
  CP "$HOME/.config/gtk-3.0/settings.ini"                   "$HERE/home/.config/gtk-3.0/settings.ini"
  CP "$HOME/.config/gtk-4.0/settings.ini"                   "$HERE/home/.config/gtk-4.0/settings.ini"
  CP "$HOME/.config/kdeglobals"                             "$HERE/home/.config/kdeglobals"
  CP "$HOME/.config/fontconfig/fonts.conf"                  "$HERE/home/.config/fontconfig/fonts.conf"
  CP "$HOME/.config/autostart/noctalia-session-cleanup.desktop" "$HERE/home/.config/autostart/noctalia-session-cleanup.desktop"
  CP "$HOME/.local/share/applications/dev.noctalia.Noctalia.desktop" "$HERE/home/.local/share/applications/dev.noctalia.Noctalia.desktop"
  CP "$HOME/.local/share/icons/hicolor/scalable/apps/noctalia.svg" "$HERE/home/.local/share/icons/hicolor/scalable/apps/noctalia.svg"

  say "3/5  ~/.local/bin helper scripts and .desktop overrides"
  for s in "${HELPER_SCRIPTS[@]}"; do
    if [ -f "$HOME/.local/bin/$s" ]; then
      CP "$HOME/.local/bin/$s"  "$HERE/home/.local/bin/$s"
    fi
  done

  for f in brave-browser.desktop org.gnome.Settings.desktop; do
    if [ -f "$HOME/.local/share/applications/$f" ]; then
      CP "$HOME/.local/share/applications/$f"  "$HERE/home/.local/share/applications/$f"
    fi
  done

  say "4/5  System files (greetd, noctalia-greeter, hardware services)"
  mkdir -p "$HERE/system/etc/sudoers.d" \
           "$HERE/system/etc/tmpfiles.d" \
           "$HERE/system/etc/bluetooth" \
           "$HERE/system/usr/local/bin" \
           "$HERE/system/usr/bin" \
           "$HERE/system/etc/systemd/system" \
           "$HERE/system/etc/systemd/system.conf.d" \
           "$HERE/system/etc/systemd/user.conf.d" \
           "$HERE/system/etc/security/limits.d" \
           "$HERE/system/etc/pam.d" \
           "$HERE/system/etc/udev/rules.d" \
           "$HERE/system/etc/greetd" \
           "$HERE/system/usr/share/wayland-sessions" \
           "$HERE/system/usr/share/polkit-1/actions" \
           "$HERE/system/usr/share/noctalia-greeter/assets" \
           "$HERE/system/var/lib/noctalia-greeter"

  # Hardware / Power / Limits
  SUDO_CP /etc/sudoers.d/charge-limit                 "$HERE/system/etc/sudoers.d/charge-limit"
  SUDO_CP /etc/sudoers.d/asus-fan-control             "$HERE/system/etc/sudoers.d/asus-fan-control"
  SUDO_CP /etc/tmpfiles.d/charge-limit.conf           "$HERE/system/etc/tmpfiles.d/charge-limit.conf"
  SUDO_CP /etc/bluetooth/main.conf                    "$HERE/system/etc/bluetooth/main.conf"
  SUDO_CP /usr/local/bin/charge-limit                 "$HERE/system/usr/local/bin/charge-limit"
  SUDO_CP /usr/local/bin/asus-fan-control             "$HERE/system/usr/local/bin/asus-fan-control"
  SUDO_CP /etc/systemd/system.conf.d/limits.conf      "$HERE/system/etc/systemd/system.conf.d/limits.conf"
  SUDO_CP /etc/systemd/user.conf.d/limits.conf        "$HERE/system/etc/systemd/user.conf.d/limits.conf"
  SUDO_CP /etc/security/limits.d/99-nofile-limits.conf "$HERE/system/etc/security/limits.d/99-nofile-limits.conf"
  SUDO_CP /etc/systemd/system/tuned-bootfast-reset.service "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service"
  SUDO_CP /etc/systemd/system/libfprint-custom.service "$HERE/system/etc/systemd/system/libfprint-custom.service"
  SUDO_CP /etc/udev/rules.d/70-libfprint-0c90.rules   "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules"
  SUDO_CP /etc/pam.d/sudo                             "$HERE/system/etc/pam.d/sudo"
  SUDO_CP /etc/pam.d/polkit-1                         "$HERE/system/etc/pam.d/polkit-1"

  # Noctalia Greeter & Greetd Login Screen
  SUDO_CP /etc/greetd/config.toml                     "$HERE/system/etc/greetd/config.toml"
  SUDO_CP /etc/greetd/environments                    "$HERE/system/etc/greetd/environments"
  SUDO_CP /etc/pam.d/greetd                           "$HERE/system/etc/pam.d/greetd"
  SUDO_CP /etc/pam.d/greetd-greeter                   "$HERE/system/etc/pam.d/greetd-greeter"
  SUDO_CP /usr/share/wayland-sessions/noctalia-v5.desktop "$HERE/system/usr/share/wayland-sessions/noctalia-v5.desktop"
  SUDO_CP /usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy "$HERE/system/usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy"
  SUDO_CP /var/lib/noctalia-greeter/greeter.toml       "$HERE/system/var/lib/noctalia-greeter/greeter.toml"
  SUDO_CP /usr/bin/noctalia-greeter-session           "$HERE/system/usr/bin/noctalia-greeter-session"
  SUDO_CP /usr/bin/noctalia-greeter-print-greetd-config "$HERE/system/usr/bin/noctalia-greeter-print-greetd-config"
  SUDO_CP /usr/share/noctalia-greeter/noctalia-greeter-cage-entry "$HERE/system/usr/share/noctalia-greeter/noctalia-greeter-cage-entry"
  if [ -f /usr/share/noctalia-greeter/assets/noctalia.svg ]; then
    SUDO_CP /usr/share/noctalia-greeter/assets/noctalia.svg "$HERE/system/usr/share/noctalia-greeter/assets/noctalia.svg"
  fi

  for s in dnf-makecache fstrim packagekit plocate-updatedb; do
    mkdir -p "$HERE/system/etc/systemd/system/$s.service.d"
    SUDO_CP /etc/systemd/system/"$s".service.d/override.conf "$HERE/system/etc/systemd/system/$s.service.d/override.conf"
  done

  say "5/5  Done pulling configs into dotfiles  [$PROFILE_LABEL]"
}

# -----------------------------------------------------------------------------
# Check Drift Logic
# -----------------------------------------------------------------------------
check_drift() {
  echo -e "\n\033[1;36m=== Checking for Configuration Drifts  [$PROFILE_LABEL] ===\033[0m"
  local drift_found=0

  check_file() {
    local src="$1"
    local dst="$2"
    if [[ "$src" == /etc/sudoers.d/* ]] && ! sudo -n test -e "$src" 2>/dev/null; then
      return 0
    fi
    if [ ! -f "$src" ]; then
      echo -e "  \033[1;31m[MISSING SYSTEM]\033[0m $src"
      drift_found=1
    elif [ ! -f "$dst" ]; then
      echo -e "  \033[1;33m[UNTRACKED REPO]\033[0m $src"
      drift_found=1
    elif [ -r "$src" ] && [ -r "$dst" ]; then
      if ! cmp -s "$src" "$dst"; then
        echo -e "  \033[1;32m[MODIFIED]\033[0m       $src"
        drift_found=1
      fi
    fi
  }

  check_dir() {
    local src="$1"
    local dst="$2"
    if [ ! -d "$src" ]; then
      echo -e "  \033[1;31m[MISSING SYSTEM]\033[0m $src"
      drift_found=1
    elif [ ! -d "$dst" ]; then
      echo -e "  \033[1;33m[UNTRACKED REPO]\033[0m $src"
      drift_found=1
    elif ! diff -rq \
         --exclude="__pycache__" \
         --exclude="*.pyc" \
         --exclude="shell.log" \
         --exclude="*.bak*" \
         --exclude="*.backup*" \
         --exclude="pinned_clipboard.json" \
         "$src" "$dst" &>/dev/null; then
      echo -e "  \033[1;32m[MODIFIED]\033[0m       $src"
      drift_found=1
    fi
  }

  # Folders
  for d in "${CONFIG_DIRS[@]}"; do
    if [ -d "$HOME/.config/$d" ] || [ -d "$HERE/home/.config/$d" ]; then
      check_dir "$HOME/.config/$d/" "$HERE/home/.config/$d/"
    fi
  done

  # systemd user units
  for u in "${USER_UNITS[@]}"; do
    check_file "$HOME/.config/systemd/user/$u" "$HERE/home/.config/systemd/user/$u"
  done

  # Noctalia v5
  check_dir "$NOCTALIA_LIVE/" "$NOCTALIA_REPO/"

  # Home files
  for f in .bashrc .blerc .config/atuin/config.toml .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini .config/kdeglobals .config/fontconfig/fonts.conf .config/autostart/noctalia-session-cleanup.desktop .local/share/applications/dev.noctalia.Noctalia.desktop .local/share/icons/hicolor/scalable/apps/noctalia.svg; do
    check_file "$HOME/$f" "$HERE/home/$f"
  done

  # Helpers
  for s in "${HELPER_SCRIPTS[@]}"; do
    if [ -f "$HOME/.local/bin/$s" ] || [ -f "$HERE/home/.local/bin/$s" ]; then
      check_file "$HOME/.local/bin/$s" "$HERE/home/.local/bin/$s"
    fi
  done

  # System files
  check_file /etc/sudoers.d/charge-limit "$HERE/system/etc/sudoers.d/charge-limit"
  check_file /etc/sudoers.d/asus-fan-control "$HERE/system/etc/sudoers.d/asus-fan-control"
  check_file /etc/tmpfiles.d/charge-limit.conf "$HERE/system/etc/tmpfiles.d/charge-limit.conf"
  check_file /etc/bluetooth/main.conf "$HERE/system/etc/bluetooth/main.conf"
  check_file /usr/local/bin/charge-limit "$HERE/system/usr/local/bin/charge-limit"
  check_file /usr/local/bin/asus-fan-control "$HERE/system/usr/local/bin/asus-fan-control"
  check_file /etc/systemd/system.conf.d/limits.conf "$HERE/system/etc/systemd/system.conf.d/limits.conf"
  check_file /etc/systemd/user.conf.d/limits.conf "$HERE/system/etc/systemd/user.conf.d/limits.conf"
  check_file /etc/security/limits.d/99-nofile-limits.conf "$HERE/system/etc/security/limits.d/99-nofile-limits.conf"
  check_file /etc/systemd/system/tuned-bootfast-reset.service "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service"
  check_file /etc/systemd/system/libfprint-custom.service "$HERE/system/etc/systemd/system/libfprint-custom.service"
  check_file /etc/pam.d/sudo "$HERE/system/etc/pam.d/sudo"
  check_file /etc/pam.d/polkit-1 "$HERE/system/etc/pam.d/polkit-1"
  check_file /etc/udev/rules.d/70-libfprint-0c90.rules "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules"

  # Noctalia Greeter & greetd
  check_file /etc/greetd/config.toml "$HERE/system/etc/greetd/config.toml"
  check_file /etc/greetd/environments "$HERE/system/etc/greetd/environments"
  check_file /etc/pam.d/greetd "$HERE/system/etc/pam.d/greetd"
  check_file /etc/pam.d/greetd-greeter "$HERE/system/etc/pam.d/greetd-greeter"
  check_file /usr/share/wayland-sessions/noctalia-v5.desktop "$HERE/system/usr/share/wayland-sessions/noctalia-v5.desktop"
  check_file /usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy "$HERE/system/usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy"
  check_file /var/lib/noctalia-greeter/greeter.toml "$HERE/system/var/lib/noctalia-greeter/greeter.toml"
  check_file /usr/bin/noctalia-greeter-session "$HERE/system/usr/bin/noctalia-greeter-session"
  check_file /usr/bin/noctalia-greeter-print-greetd-config "$HERE/system/usr/bin/noctalia-greeter-print-greetd-config"
  check_file /usr/share/noctalia-greeter/noctalia-greeter-cage-entry "$HERE/system/usr/share/noctalia-greeter/noctalia-greeter-cage-entry"

  if [ "$drift_found" = 0 ]; then
    echo -e "  \033[1;32m✔ All configurations are fully in sync!\033[0m"
  fi
}

# -----------------------------------------------------------------------------
# View Diffs Logic
# -----------------------------------------------------------------------------
view_diffs() {
  echo -e "\n\033[1;36m=== Showing Configuration Differences  [$PROFILE_LABEL] ===\033[0m"
  local count=0

  diff_file() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ] && [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
      echo -e "\n\033[1;33m--- $src vs Repo Copy ---\033[0m"
      diff -u "$dst" "$src" || true
      count=$((count+1))
    fi
  }

  # Home files
  for f in .bashrc .blerc .config/atuin/config.toml .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini .config/kdeglobals .config/fontconfig/fonts.conf .config/autostart/noctalia-session-cleanup.desktop; do
    diff_file "$HOME/$f" "$HERE/home/$f"
  done

  # Helpers
  for s in "${HELPER_SCRIPTS[@]}"; do
    diff_file "$HOME/.local/bin/$s" "$HERE/home/.local/bin/$s"
  done

  # Managed user units
  for u in "${USER_UNITS[@]}"; do
    diff_file "$HOME/.config/systemd/user/$u" "$HERE/home/.config/systemd/user/$u"
  done

  # Noctalia v5 critical files
  for f in settings.json config.toml plugins.json colors.json manual-keybinds.json terminal-commands.json user-keybinds.json user-templates.toml; do
    diff_file "$NOCTALIA_LIVE/$f" "$NOCTALIA_REPO/$f"
  done

  # System files
  diff_file /etc/sudoers.d/charge-limit "$HERE/system/etc/sudoers.d/charge-limit"
  diff_file /etc/sudoers.d/asus-fan-control "$HERE/system/etc/sudoers.d/asus-fan-control"
  diff_file /etc/tmpfiles.d/charge-limit.conf "$HERE/system/etc/tmpfiles.d/charge-limit.conf"
  diff_file /etc/bluetooth/main.conf "$HERE/system/etc/bluetooth/main.conf"
  diff_file /usr/local/bin/charge-limit "$HERE/system/usr/local/bin/charge-limit"
  diff_file /usr/local/bin/asus-fan-control "$HERE/system/usr/local/bin/asus-fan-control"
  diff_file /etc/systemd/system.conf.d/limits.conf "$HERE/system/etc/systemd/system.conf.d/limits.conf"
  diff_file /etc/systemd/user.conf.d/limits.conf "$HERE/system/etc/systemd/user.conf.d/limits.conf"
  diff_file /etc/security/limits.d/99-nofile-limits.conf "$HERE/system/etc/security/limits.d/99-nofile-limits.conf"
  diff_file /etc/systemd/system/tuned-bootfast-reset.service "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service"
  diff_file /etc/systemd/system/libfprint-custom.service "$HERE/system/etc/systemd/system/libfprint-custom.service"
  diff_file /etc/pam.d/sudo "$HERE/system/etc/pam.d/sudo"
  diff_file /etc/pam.d/polkit-1 "$HERE/system/etc/pam.d/polkit-1"
  diff_file /etc/udev/rules.d/70-libfprint-0c90.rules "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules"

  # Noctalia Greeter & greetd
  diff_file /etc/greetd/config.toml "$HERE/system/etc/greetd/config.toml"
  diff_file /etc/greetd/environments "$HERE/system/etc/greetd/environments"
  diff_file /etc/pam.d/greetd "$HERE/system/etc/pam.d/greetd"
  diff_file /etc/pam.d/greetd-greeter "$HERE/system/etc/pam.d/greetd-greeter"
  diff_file /usr/share/wayland-sessions/noctalia-v5.desktop "$HERE/system/usr/share/wayland-sessions/noctalia-v5.desktop"
  diff_file /usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy "$HERE/system/usr/share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy"
  diff_file /var/lib/noctalia-greeter/greeter.toml "$HERE/system/var/lib/noctalia-greeter/greeter.toml"
  diff_file /usr/bin/noctalia-greeter-session "$HERE/system/usr/bin/noctalia-greeter-session"
  diff_file /usr/bin/noctalia-greeter-print-greetd-config "$HERE/system/usr/bin/noctalia-greeter-print-greetd-config"
  diff_file /usr/share/noctalia-greeter/noctalia-greeter-cage-entry "$HERE/system/usr/share/noctalia-greeter/noctalia-greeter-cage-entry"

  if [ "$count" = 0 ]; then
    echo -e "  \033[1;32m✔ No file differences detected.\033[0m"
  fi
}

# -----------------------------------------------------------------------------
# Scan Untracked Configurations
# -----------------------------------------------------------------------------
scan_untracked() {
  echo -e "\n\033[1;36m=== Scanning for Untracked Configurations ===\033[0m"
  local found=0

  for dir in "$HOME"/.config/*/; do
    [ -d "$dir" ] || continue
    local base
    base=$(basename "$dir")
    local covered=0
    for d in "${CONFIG_DIRS[@]}" systemd noctalia atuin \
             gtk-3.0 gtk-4.0 fontconfig autostart; do
      [ "$base" = "$d" ] && covered=1 && break
    done
    case "$base" in
      kdeglobals|BraveSoftware|mozilla|btop|vesktop|Vencord|goa-1.0|dconf|gtk-4.0|gtk-3.0)
        covered=1 ;;
      gh|keyring-tpm|libaccounts-glib|evolution|*chrome*|*Chromium*|Code|Electron|\
      abrt|ibus|enchant|go|libvirt|libreoffice|GenOffice|gnome-boxes|\
      kdedefaults|kde-material-you-colors|*Antigravity*|*antigravity*|\
      ai.opencode.desktop|opencode|blender|astro|gum|containers|podman|\
      flatpak|libdecor|pulse|pipewire|wireplumber|samba|systemd-private*|quickshell*)
        covered=1 ;;
    esac
    if [ "$covered" = 0 ]; then
      echo -e "  \033[1;33m[UNTRACKED DIR]\033[0m  ~/.config/$base/"
      found=1
    fi
  done

  for f in "$HOME"/.local/bin/*; do
    [ -f "$f" ] || continue
    local base
    base=$(basename "$f")
    local covered=0
    for s in "${HELPER_SCRIPTS[@]}"; do
      [ "$base" = "$s" ] && covered=1 && break
    done
    if [ "$covered" = 0 ] && grep -Iq . "$f" 2>/dev/null && \
       { [[ "$base" == *.sh || "$base" == *.py ]] || \
         grep -rq -F -- "$base" "$HOME/.config/hypr" "$HOME/.config/systemd" "$HOME/.config/autostart" 2>/dev/null; }; then
      echo -e "  \033[1;33m[UNTRACKED HELPER]\033[0m  ~/.local/bin/$base"
      found=1
    fi
  done

  if [ "$found" = 0 ]; then
    echo -e "  \033[1;32m✔ No new untracked configurations found in ~/.config or ~/.local/bin.\033[0m"
  fi
}

# -----------------------------------------------------------------------------
# GNU Stow Symlink Conversion
# -----------------------------------------------------------------------------
setup_stow() {
  echo -e "\n\033[1;36m=== GNU Stow Symlink Integration ===\033[0m"
  if ! command -v stow >/dev/null; then
    echo "GNU Stow is not installed. Installing it now..."
    sudo dnf install -y stow
  fi

  if ! git -C "$HERE" diff --quiet || ! git -C "$HERE" diff --cached --quiet; then
    echo -e "\033[1;31mRefusing: repo has uncommitted changes.\033[0m"
    echo "Commit or stash first."
    git -C "$HERE" status --short | head -n 20
    return 1
  fi

  echo "Setting up symlinks..."
  cd "$HERE"
  stow --adopt -v -d "$HERE" -t "$HOME" home || {
    echo -e "\033[1;31mStow failed. Check for directory/file conflicts.\033[0m"
    return 1
  }

  echo -e "\033[1;32m✔ GNU Stow symlinks successfully established!\033[0m"
}

# -----------------------------------------------------------------------------
# C++ Compilation Support for Noctalia v5 & Noctalia Greeter
# -----------------------------------------------------------------------------
rebuild_cpp_binaries() {
  echo -e "\n\033[1;36m=== Rebuilding C++ Binaries: Noctalia v5 & Noctalia Greeter ===\033[0m"

  # 1. Noctalia Shell (v5)
  if [ -d "$HOME/noctalia" ]; then
    say "Building Noctalia v5 (C++) from $HOME/noctalia..."
    (
      cd "$HOME/noctalia"
      if [ ! -d "build-release" ]; then
        meson setup build-release --buildtype=release --prefix="$HOME/.local"
      fi
      ninja -C build-release
      ninja -C build-release install
    )
    echo -e "\033[1;32m✔ Noctalia v5 compiled & installed to ~/.local/bin/noctalia\033[0m"
  else
    warn "Directory $HOME/noctalia not found. Skipping Noctalia compilation."
  fi

  # 2. Noctalia Greeter
  if [ -d "$HOME/noctalia-greeter" ]; then
    say "Building Noctalia Greeter (C++) from $HOME/noctalia-greeter..."
    (
      cd "$HOME/noctalia-greeter"
      if [ ! -d "build-release" ]; then
        meson setup build-release --buildtype=release --prefix=/usr
      fi
      ninja -C build-release
      if [ -f "./install.sh" ]; then
        sudo ./install.sh
      else
        sudo ninja -C build-release install
      fi
    )
    echo -e "\033[1;32m✔ Noctalia Greeter compiled & installed to /usr/bin/noctalia-greeter\033[0m"
  else
    warn "Directory $HOME/noctalia-greeter not found. Skipping Greeter compilation."
  fi
}

# -----------------------------------------------------------------------------
# Git commit/push
# -----------------------------------------------------------------------------
git_push() {
  echo -e "\n\033[1;36m=== Committing & Pushing to GitHub  [branch: $BRANCH] ===\033[0m"
  cd "$HERE"
  git status --short

  if git diff --quiet && git diff --cached --quiet; then
    echo "Nothing to commit."
    return 0
  fi

  read -p "Enter commit message: " msg || return 0
  if [ -z "$msg" ]; then
    echo "Commit message cannot be empty. Aborted."
    return 1
  fi

  git add -A
  git commit -m "$msg"
  echo "Pushing to GitHub (branch: $BRANCH)..."
  git push origin "$BRANCH"
  echo -e "\033[1;32m✔ Changes pushed successfully to $BRANCH!\033[0m"
}

# -----------------------------------------------------------------------------
# Direct CLI mode
# -----------------------------------------------------------------------------
if [ -n "$CLI_ACTION" ]; then
  case "$CLI_ACTION" in
    drift) check_drift ;;
    diff) view_diffs ;;
    scan) scan_untracked ;;
    install) "$HERE/install.sh" ;;
    pull) pull_from_system ;;
    build) rebuild_cpp_binaries ;;
    stow) setup_stow ;;
  esac
  exit 0
fi

if [ -n "${COMMIT_MSG}" ] || [ "${DRYRUN}" = 1 ]; then
  pull_from_system
  cd "$HERE"
  git status --short
  if [ -n "$COMMIT_MSG" ] && [ "$DRYRUN" != 1 ]; then
    if git diff --quiet && git diff --cached --quiet; then
      echo "Nothing to commit."
    else
      git add -A
      git commit -m "$COMMIT_MSG"
      echo "Committed. Push with:  git push origin $BRANCH"
    fi
  fi
  exit 0
fi

# Run Interactive Menu
clear
while true; do
  echo -e "\033[1;35m"
  echo "====================================================="
  echo "    🚀 DOTFILES INTERACTIVE MANAGEMENT DASHBOARD     "
  echo "====================================================="
  echo -e "\033[0m"
  echo -e "  \033[1;36mBranch:\033[0m $BRANCH  \033[1;36m|\033[0m  \033[1;36mProfile:\033[0m $PROFILE_LABEL"
  echo ""
  echo -e "  \033[1;33m[1]\033[0m Check Drift Status (System vs Repo)"
  echo -e "  \033[1;33m[2]\033[0m View Differences (diff)"
  echo -e "  \033[1;33m[3]\033[0m Scan for Untracked Configuration Files"
  echo -e "  \033[1;33m[4]\033[0m Restore from Repo to System (Deploy/Install)"
  echo -e "  \033[1;33m[5]\033[0m Backup from System to Repo (Pull/Sync)"
  echo -e "  \033[1;33m[6]\033[0m Recompile & Install Noctalia v5 + Greeter (C++)"
  echo -e "  \033[1;33m[7]\033[0m Convert Home Configs to GNU Stow Symlinks"
  echo -e "  \033[1;33m[8]\033[0m Commit & Push to GitHub"
  echo -e "  \033[1;33m[9]\033[0m Exit"
  echo -e "\033[1;35m=====================================================\033[0m"
  read -p "Select option [1-9]: " choice || break

  case "$choice" in
    1) check_drift ;;
    2) view_diffs ;;
    3) scan_untracked ;;
    4)
      echo -e "\n=== Restoring/Deploying Configs ==="
      "$HERE/install.sh"
      ;;
    5)
      echo -e "\n=== Syncing active system files to repo ==="
      pull_from_system
      ;;
    6) rebuild_cpp_binaries ;;
    7) setup_stow ;;
    8) git_push ;;
    9) echo "Goodbye!"; exit 0 ;;
    *) echo -e "\033[1;31mInvalid choice. Press enter to continue...\033[0m" ;;
  esac
  echo -e "\nPress Enter to return to menu..."
  read -r _ || break
  clear
done
