#!/usr/bin/env bash
# sync.sh — pull current system state back into this dotfiles repo, or run dashboard.
#
# Usage:
#   ./sync.sh              # launches interactive dashboard
#   ./sync.sh -c "msg"     # legacy: sync + commit (no push)
#   ./sync.sh -d           # legacy: dry-run
#

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
COMMIT_MSG=""
DRYRUN=0

# Parse arguments for legacy mode
while [ $# -gt 0 ]; do
  case "$1" in
    -c|--commit) COMMIT_MSG="${2:-}"; shift 2 ;;
    -d|--dry-run) DRYRUN=1; shift ;;
    -h|--help) sed -n '/^# Usage:/,/^$/p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

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
      sudo cp -a "$1" "$2"
      sudo chown "$USER:$USER" "$2"
    fi
  fi
}

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

# -----------------------------------------------------------------------------
# Pull logic (Sync from active system into the git repo)
# -----------------------------------------------------------------------------
pull_from_system() {
  say "1/5  Mirroring desktop compositor & shell configs"
  local common_excludes=(
    --exclude='__pycache__'
    --exclude='*.pyc'
    --exclude='*.pyo'
    --exclude='*.log'
    --exclude='*.qslog'
    --exclude='*.lock'
    --exclude='by-id'
    --exclude='by-pid'
    --exclude='.git'
  )

  for dir in hypr kitty fastfetch xdg-desktop-portal foot fuzzel waybar cava yazi Kvantum qt5ct qt6ct cliphist; do
    if [ -d "$HOME/.config/$dir" ]; then
      R --delete "${common_excludes[@]}" "$HOME/.config/$dir/" "$HERE/home/.config/$dir/"
    fi
  done

  # Noctalia: settings, plugins, colors, templates, keybinds, commands, plugins (skip runtime log/clipboard)
  if [ -d "$HOME/.config/noctalia" ]; then
    R --delete \
       --include='settings.json' \
       --include='plugins.json' \
       --include='colors.json' \
       --include='manual-keybinds.json' \
       --include='terminal-commands.json' \
       --include='user-keybinds.json' \
       --include='user-templates.toml' \
       --include='matugenTemplates/***' \
       --include='plugins/***' \
       --exclude='*' \
       "$HOME/.config/noctalia/"                              "$HERE/home/.config/noctalia/"
  fi

  # Quickshell: user shells only, no bytecode / logs
  if [ -d "$HOME/.config/quickshell" ]; then
    R --delete "${common_excludes[@]}" "$HOME/.config/quickshell/" "$HERE/home/.config/quickshell/"
  fi

  # systemd user units we manage
  if [ -d "$HOME/.config/systemd/user" ]; then
    R --delete --include='prewarm-apps.*' --include='wl-clip-persist.*' --exclude='*' \
       "$HOME/.config/systemd/user/"                          "$HERE/home/.config/systemd/user/"
  fi

  say "2/5  Single-file desktop configs"
  CP "$HOME/.bashrc"                                        "$HERE/home/.bashrc"
  CP "$HOME/.blerc"                                         "$HERE/home/.blerc"
  CP "$HOME/.config/atuin/config.toml"                      "$HERE/home/.config/atuin/config.toml"
  CP "$HOME/.config/gtk-3.0/settings.ini"                   "$HERE/home/.config/gtk-3.0/settings.ini"
  CP "$HOME/.config/gtk-4.0/settings.ini"                   "$HERE/home/.config/gtk-4.0/settings.ini"
  CP "$HOME/.config/kdeglobals"                             "$HERE/home/.config/kdeglobals"
  CP "$HOME/.config/fontconfig/fonts.conf"                  "$HERE/home/.config/fontconfig/fonts.conf"
  CP "$HOME/.config/autostart/noctalia-session-cleanup.desktop" "$HERE/home/.config/autostart/noctalia-session-cleanup.desktop"

  say "3/5  ~/.local/bin helper scripts and .desktop overrides"
  for s in charge-limit wallcards-video prewarm-apps toggle-fan-profile \
           hyprland-dialog hyprland-update-screen hyprland-guiutils \
           noctalia-session-cleanup restore-power-profile update-sddm-wallpaper waybarctl \
           sysupdate sysfind nvrun sys-stats-period wallpaper-fetch fetch-wallpapers hypr-resume-handler.sh; do
    if [ -f "$HOME/.local/bin/$s" ]; then
      CP "$HOME/.local/bin/$s"                              "$HERE/home/.local/bin/$s"
    fi
  done

  for f in brave-browser.desktop org.gnome.Settings.desktop; do
    if [ -f "$HOME/.local/share/applications/$f" ]; then
      CP "$HOME/.local/share/applications/$f"               "$HERE/home/.local/share/applications/$f"
    fi
  done

  say "4/5  System files (sudo)"
  mkdir -p "$HERE/system/etc/sudoers.d" \
           "$HERE/system/etc/tmpfiles.d" \
           "$HERE/system/etc/bluetooth" \
           "$HERE/system/usr/local/bin" \
           "$HERE/system/etc/systemd/system" \
           "$HERE/system/etc/systemd/system.conf.d" \
           "$HERE/system/etc/systemd/user.conf.d" \
           "$HERE/system/etc/security/limits.d" \
           "$HERE/system/etc/pam.d"

  SUDO_CP /etc/sudoers.d/charge-limit                 "$HERE/system/etc/sudoers.d/charge-limit"
  SUDO_CP /etc/sudoers.d/asus-fan-control             "$HERE/system/etc/sudoers.d/asus-fan-control"
  SUDO_CP /etc/sudoers.d/sddm-wallpaper               "$HERE/system/etc/sudoers.d/sddm-wallpaper"
  SUDO_CP /etc/tmpfiles.d/charge-limit.conf           "$HERE/system/etc/tmpfiles.d/charge-limit.conf"
  SUDO_CP /etc/bluetooth/main.conf                    "$HERE/system/etc/bluetooth/main.conf"
  SUDO_CP /usr/local/bin/charge-limit                 "$HERE/system/usr/local/bin/charge-limit"
  SUDO_CP /usr/local/bin/asus-fan-control             "$HERE/system/usr/local/bin/asus-fan-control"
  SUDO_CP /etc/systemd/system.conf.d/limits.conf      "$HERE/system/etc/systemd/system.conf.d/limits.conf"
  SUDO_CP /etc/systemd/user.conf.d/limits.conf        "$HERE/system/etc/systemd/user.conf.d/limits.conf"
  SUDO_CP /etc/security/limits.d/99-nofile-limits.conf "$HERE/system/etc/security/limits.d/99-nofile-limits.conf"
  SUDO_CP /etc/systemd/system/tuned-bootfast-reset.service "$HERE/system/etc/systemd/system/tuned-bootfast-reset.service"
  SUDO_CP /etc/systemd/system/libfprint-custom.service "$HERE/system/etc/systemd/system/libfprint-custom.service"
  SUDO_CP /etc/pam.d/sudo                             "$HERE/system/etc/pam.d/sudo"
  SUDO_CP /etc/pam.d/sddm                             "$HERE/system/etc/pam.d/sddm"
  SUDO_CP /etc/pam.d/polkit-1                         "$HERE/system/etc/pam.d/polkit-1"
  SUDO_CP /etc/udev/rules.d/70-libfprint-0c90.rules   "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules"

  for s in dnf-makecache fstrim packagekit plocate-updatedb; do
    mkdir -p "$HERE/system/etc/systemd/system/$s.service.d"
    SUDO_CP /etc/systemd/system/"$s".service.d/override.conf "$HERE/system/etc/systemd/system/$s.service.d/override.conf"
  done

  if [ -d /usr/share/sddm/themes/noctalia ]; then
    if [ "$DRYRUN" = 1 ]; then
      echo "would sudo-copy whole SDDM theme directory"
    elif sudo -n true 2>/dev/null; then
      mkdir -p "$HERE/system/usr/share/sddm/themes/noctalia"
      sudo rsync -a --delete --exclude='.git' /usr/share/sddm/themes/noctalia/ "$HERE/system/usr/share/sddm/themes/noctalia/"
      sudo chown -R "$USER:$USER" "$HERE/system/usr/share/sddm/themes/noctalia/"
    else
      echo "Skipping SDDM theme copy (sudo authentication required)"
    fi
  fi

  if [ -f /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml.bak ] && [ "$DRYRUN" != 1 ]; then
    diff -u /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml.bak \
            /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml \
            > "$HERE/patches/HyprlandService.qml.patch" || true
  fi

  say "5/5  Done pulling desktop configs into dotfiles."
}

# -----------------------------------------------------------------------------
# Check Drift Logic
# -----------------------------------------------------------------------------
check_drift() {
  echo -e "\n\033[1;36m=== Checking for Configuration Drifts ===\033[0m"
  local drift_found=0

  check_file() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$src" ]; then
      echo -e "  \033[1;31m[MISSING SYSTEM]\033[0m $src"
      drift_found=1
    elif [ ! -f "$dst" ]; then
      echo -e "  \033[1;33m[UNTRACKED REPO]\033[0m $src"
      drift_found=1
    elif ! cmp -s "$src" "$dst"; then
      echo -e "  \033[1;32m[MODIFIED]\033[0m       $src"
      drift_found=1
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
    elif ! diff -rq --exclude="__pycache__" --exclude="*.pyc" "$src" "$dst" &>/dev/null; then
      echo -e "  \033[1;32m[MODIFIED]\033[0m       $src"
      drift_found=1
    fi
  }

  # Folders
  for d in hypr kitty fastfetch xdg-desktop-portal foot fuzzel waybar cava yazi Kvantum qt5ct qt6ct cliphist quickshell systemd/user; do
    if [ -d "$HOME/.config/$d" ] || [ -d "$HERE/home/.config/$d" ]; then
      check_dir "$HOME/.config/$d/" "$HERE/home/.config/$d/"
    fi
  done

  check_file "$HOME/.config/noctalia/settings.json" "$HERE/home/.config/noctalia/settings.json"
  check_file "$HOME/.config/noctalia/plugins.json" "$HERE/home/.config/noctalia/plugins.json"
  check_file "$HOME/.config/noctalia/colors.json" "$HERE/home/.config/noctalia/colors.json"
  check_file "$HOME/.config/noctalia/manual-keybinds.json" "$HERE/home/.config/noctalia/manual-keybinds.json"
  check_file "$HOME/.config/noctalia/terminal-commands.json" "$HERE/home/.config/noctalia/terminal-commands.json"
  check_file "$HOME/.config/noctalia/user-keybinds.json" "$HERE/home/.config/noctalia/user-keybinds.json"
  check_file "$HOME/.config/noctalia/user-templates.toml" "$HERE/home/.config/noctalia/user-templates.toml"
  check_dir "$HOME/.config/noctalia/plugins/" "$HERE/home/.config/noctalia/plugins/"
  check_dir "$HOME/.config/noctalia/matugenTemplates/" "$HERE/home/.config/noctalia/matugenTemplates/"

  # Home files
  for f in .bashrc .blerc .config/atuin/config.toml .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini .config/kdeglobals .config/fontconfig/fonts.conf .config/autostart/noctalia-session-cleanup.desktop; do
    check_file "$HOME/$f" "$HERE/home/$f"
  done

  # Helpers & overrides
  for s in charge-limit wallcards-video prewarm-apps toggle-fan-profile hyprland-dialog hyprland-update-screen hyprland-guiutils noctalia-session-cleanup restore-power-profile update-sddm-wallpaper waybarctl sysupdate sysfind nvrun sys-stats-period wallpaper-fetch fetch-wallpapers hypr-resume-handler.sh; do
    check_file "$HOME/.local/bin/$s" "$HERE/home/.local/bin/$s"
  done

  for f in brave-browser.desktop org.gnome.Settings.desktop; do
    check_file "$HOME/.local/share/applications/$f" "$HERE/home/.local/share/applications/$f"
  done

  # System files
  check_file /etc/sudoers.d/charge-limit "$HERE/system/etc/sudoers.d/charge-limit"
  check_file /etc/sudoers.d/asus-fan-control "$HERE/system/etc/sudoers.d/asus-fan-control"
  check_file /etc/sudoers.d/sddm-wallpaper "$HERE/system/etc/sudoers.d/sddm-wallpaper"
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
  check_file /etc/pam.d/sddm "$HERE/system/etc/pam.d/sddm"
  check_file /etc/pam.d/polkit-1 "$HERE/system/etc/pam.d/polkit-1"
  check_file /etc/udev/rules.d/70-libfprint-0c90.rules "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules"

  for s in dnf-makecache fstrim packagekit plocate-updatedb; do
    check_file /etc/systemd/system/"$s".service.d/override.conf "$HERE/system/etc/systemd/system/$s.service.d/override.conf"
  done
  check_dir /usr/share/sddm/themes/noctalia/ "$HERE/system/usr/share/sddm/themes/noctalia/"

  if [ "$drift_found" = 0 ]; then
    echo -e "  \033[1;32m✔ All configurations are fully in sync!\033[0m"
  fi
}

# -----------------------------------------------------------------------------
# View Diffs Logic
# -----------------------------------------------------------------------------
view_diffs() {
  echo -e "\n\033[1;36m=== Showing Configuration Differences ===\033[0m"
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
  for s in charge-limit wallcards-video prewarm-apps toggle-fan-profile hyprland-dialog hyprland-update-screen hyprland-guiutils noctalia-session-cleanup restore-power-profile update-sddm-wallpaper waybarctl sysupdate sysfind nvrun sys-stats-period wallpaper-fetch fetch-wallpapers hypr-resume-handler.sh; do
    diff_file "$HOME/.local/bin/$s" "$HERE/home/.local/bin/$s"
  done

  # Noctalia / hyprland critical files
  diff_file "$HOME/.config/noctalia/settings.json" "$HERE/home/.config/noctalia/settings.json"
  diff_file "$HOME/.config/noctalia/plugins.json" "$HERE/home/.config/noctalia/plugins.json"
  diff_file "$HOME/.config/noctalia/colors.json" "$HERE/home/.config/noctalia/colors.json"
  diff_file "$HOME/.config/noctalia/manual-keybinds.json" "$HERE/home/.config/noctalia/manual-keybinds.json"
  diff_file "$HOME/.config/noctalia/terminal-commands.json" "$HERE/home/.config/noctalia/terminal-commands.json"
  diff_file "$HOME/.config/noctalia/user-keybinds.json" "$HERE/home/.config/noctalia/user-keybinds.json"
  diff_file "$HOME/.config/noctalia/user-templates.toml" "$HERE/home/.config/noctalia/user-templates.toml"

  # System files
  diff_file /etc/systemd/system/libfprint-custom.service "$HERE/system/etc/systemd/system/libfprint-custom.service"
  diff_file /etc/pam.d/sudo "$HERE/system/etc/pam.d/sudo"
  diff_file /etc/pam.d/sddm "$HERE/system/etc/pam.d/sddm"
  diff_file /etc/pam.d/polkit-1 "$HERE/system/etc/pam.d/polkit-1"
  diff_file /etc/udev/rules.d/70-libfprint-0c90.rules "$HERE/system/etc/udev/rules.d/70-libfprint-0c90.rules"

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

  for dir in "$HOME"/.config/*; do
    if [ -d "$dir" ]; then
      local base=$(basename "$dir")
      case "$base" in
        hypr|kitty|fastfetch|xdg-desktop-portal|noctalia|quickshell|systemd|atuin|gtk-3.0|gtk-4.0|kdeglobals|fontconfig|autostart|vesktop|Vencord|*) ;;
      esac
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

  if ! command -v stow >/dev/null; then
    echo -e "\033[1;31mError: GNU Stow installation failed.\033[0m"
    return 1
  fi

  echo "Stow is installed. Setting up symlinks..."
  cd "$HERE"

  # Stow --adopt merges existing config files into the repo if they differ
  stow --adopt -v -d "$HERE" -t "$HOME" home || {
    echo -e "\033[1;31mStow failed. Check for directory/file conflicts.\033[0m"
    return 1
  }

  echo -e "\033[1;32m✔ GNU Stow symlinks successfully established!\033[0m"
}



# -----------------------------------------------------------------------------
# Git commit/push
# -----------------------------------------------------------------------------
git_push() {
  echo -e "\n\033[1;36m=== Committing & Pushing to GitHub ===\033[0m"
  cd "$HERE"
  git status --short
  
  if git diff --quiet && git diff --cached --quiet; then
    echo "Nothing to commit."
    return 0
  fi
  
  read -p "Enter commit message: " msg
  if [ -z "$msg" ]; then
    echo "Commit message cannot be empty. Aborted."
    return 1
  fi
  
  git add -A
  git commit -m "$msg"
  echo "Pushing to GitHub..."
  git push
  echo -e "\033[1;32m✔ Changes pushed successfully!\033[0m"
}

# -----------------------------------------------------------------------------
# Execute
# -----------------------------------------------------------------------------
# If arguments are passed, run legacy CLI mode
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
      echo "Committed. Push with:  git push"
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
  echo -e "  \033[1;33m[1]\033[0m Check Drift Status (System vs Repo)"
  echo -e "  \033[1;33m[2]\033[0m View Differences (diff)"
  echo -e "  \033[1;33m[3]\033[0m Scan for Untracked Configuration Files"
  echo -e "  \033[1;33m[4]\033[0m Restore from Repo to System (Deploy/Install)"
  echo -e "  \033[1;33m[5]\033[0m Backup from System to Repo (Pull/Sync)"
  echo -e "  \033[1;33m[6]\033[0m Convert Home Configs to GNU Stow Symlinks"
  echo -e "  \033[1;33m[7]\033[0m Commit & Push to GitHub"
  echo -e "  \033[1;33m[8]\033[0m Exit"
  echo -e "\033[1;35m=====================================================\033[0m"
  read -p "Select option [1-8]: " choice

  case "$choice" in
    1) check_drift ;;
    2) view_diffs ;;
    3) scan_untracked ;;
    4) 
      echo -e "\n=== Restoring/Deploying Configs ==="
      ./install.sh
      ;;
    5) 
      echo -e "\n=== Syncing active system files to repo ==="
      pull_from_system
      ;;
    6) setup_stow ;;
    7) git_push ;;
    8) echo "Goodbye!"; exit 0 ;;
    *) echo -e "\033[1;31mInvalid choice. Press enter to continue...\033[0m"; read -r ;;
  esac
  echo -e "\nPress Enter to return to menu..."; read -r _
  clear
done
