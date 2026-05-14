#!/usr/bin/env bash
# sync.sh — pull current system state back into this dotfiles repo.
#
# Usage:
#   ./sync.sh              # just sync; show git status; you commit/push manually
#   ./sync.sh -c "msg"     # also `git add -A && git commit -m "<msg>"` (no push)
#   ./sync.sh -d           # dry-run: show what would change without writing
#
# Re-runs the same mirroring logic the original snapshot used. Idempotent —
# files identical to source are untouched. Files removed from your system are
# also removed from the repo (rsync --delete on whole-tree mirrors).

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
COMMIT_MSG=""
DRYRUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--commit) COMMIT_MSG="${2:-}"; shift 2 ;;
    -d|--dry-run) DRYRUN=1; shift ;;
    -h|--help) sed -n '/^# Usage:/,/^$/p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

R() {  # rsync wrapper that respects dry-run
  local args=(-a)
  [ "$DRYRUN" = 1 ] && args+=(-n -v)
  rsync "${args[@]}" "$@"
}

CP() {  # cp that respects dry-run
  if [ "$DRYRUN" = 1 ]; then
    [ -e "$1" ] && echo "would copy: $1 → $2" || true
  else
    [ -e "$1" ] && install -D "$1" "$2" || true
  fi
}

SUDO_CP() {  # sudo cp into dotfiles, retains user-readable perms
  if [ "$DRYRUN" = 1 ]; then
    [ -e "$1" ] && echo "would sudo-copy: $1 → $2" || true
  else
    if [ -e "$1" ]; then
      sudo -n cp -a "$1" "$2" 2>/dev/null || sudo cp -a "$1" "$2"
      sudo -n chown "$USER:$USER" "$2" 2>/dev/null || true
    fi
  fi
}

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

#------------------------------------------------------------------------------
say "1/5  Mirroring whole-tree configs (with --delete to track removals)"
#------------------------------------------------------------------------------
R --delete ~/.config/hypr/                          "$HERE/home/.config/hypr/"
R --delete ~/.config/kitty/                         "$HERE/home/.config/kitty/"
R --delete ~/.config/fastfetch/                     "$HERE/home/.config/fastfetch/"

# Noctalia: only settings + plugins (skip cache and runtime)
R --delete --include='settings.json' --include='plugins/***' --exclude='*' \
   ~/.config/noctalia/                              "$HERE/home/.config/noctalia/"

# Quickshell: only the user-level shells (overview, HyprQuickFrame), no runtime files
R --delete --exclude='by-id' --exclude='by-pid' --exclude='*.lock' \
   --exclude='*.qslog' --exclude='*.log' --exclude='.git' \
   ~/.config/quickshell/                            "$HERE/home/.config/quickshell/"

# systemd user units we manage
R --delete --include='prewarm-apps.*' --exclude='*' \
   ~/.config/systemd/user/                          "$HERE/home/.config/systemd/user/"

#------------------------------------------------------------------------------
say "2/5  Single-file configs"
#------------------------------------------------------------------------------
CP ~/.bashrc                                        "$HERE/home/.bashrc"
CP ~/.blerc                                         "$HERE/home/.blerc"
CP ~/.config/atuin/config.toml                      "$HERE/home/.config/atuin/config.toml"
CP ~/.config/gtk-3.0/settings.ini                   "$HERE/home/.config/gtk-3.0/settings.ini"
CP ~/.config/gtk-4.0/settings.ini                   "$HERE/home/.config/gtk-4.0/settings.ini"
CP ~/.config/kdeglobals                             "$HERE/home/.config/kdeglobals"
CP ~/.config/fontconfig/fonts.conf                  "$HERE/home/.config/fontconfig/fonts.conf"

#------------------------------------------------------------------------------
say "3/5  ~/.local/bin helper scripts and .desktop overrides"
#------------------------------------------------------------------------------
for s in charge-limit wallcards-video prewarm-apps \
         hyprland-dialog hyprland-update-screen hyprland-guiutils; do
  CP ~/.local/bin/"$s"                              "$HERE/home/.local/bin/$s"
done
for f in brave-browser.desktop org.gnome.Settings.desktop; do
  CP ~/.local/share/applications/"$f"               "$HERE/home/.local/share/applications/$f"
done

#------------------------------------------------------------------------------
say "4/5  System files (sudo)"
#------------------------------------------------------------------------------
SUDO_CP /etc/sudoers.d/charge-limit                 "$HERE/system/etc/sudoers.d/charge-limit"
SUDO_CP /etc/tmpfiles.d/charge-limit.conf           "$HERE/system/etc/tmpfiles.d/charge-limit.conf"
SUDO_CP /etc/bluetooth/main.conf                    "$HERE/system/etc/bluetooth/main.conf"
SUDO_CP /usr/local/bin/charge-limit                 "$HERE/system/usr/local/bin/charge-limit"

# QML patch (regenerate from current state)
if [ -f /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml.bak ] && \
   [ "$DRYRUN" != 1 ]; then
  diff -u /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml.bak \
          /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml \
          > "$HERE/patches/HyprlandService.qml.patch" || true
fi

#------------------------------------------------------------------------------
say "5/5  Manual"
#------------------------------------------------------------------------------
CP ~/Downloads/HYPRLAND_NOCTALIA_USER_MANUAL.md     "$HERE/docs/HYPRLAND_NOCTALIA_USER_MANUAL.md"

#------------------------------------------------------------------------------
say "Git status"
#------------------------------------------------------------------------------
cd "$HERE"
git status --short

if [ -n "$COMMIT_MSG" ] && [ "$DRYRUN" != 1 ]; then
  if git diff --quiet && git diff --cached --quiet; then
    echo "Nothing to commit."
  else
    git add -A
    git commit -m "$COMMIT_MSG"
    echo
    echo "Committed. Push with:  git push"
  fi
fi
