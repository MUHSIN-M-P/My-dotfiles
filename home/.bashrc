# .bashrc

# ble.sh — fish-style autosuggestions + dropdown menu. Sourced first, attached
# at the bottom after atuin so all hooks register cleanly.
[[ $- == *i* ]] && [ -f ~/.local/share/blesh/ble.sh ] && source ~/.local/share/blesh/ble.sh --noattach

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# auto-run fastfetch on interactive shells
[[ $- == *i* ]] && command -v fastfetch >/dev/null && fastfetch

# atuin: shell history. Up arrow stays as stock bash previous-history.
# Atuin only fires on Ctrl+R (compact dropdown via ~/.config/atuin/config.toml).
__atuin_bind_up_arrow=false
[ -f /usr/libexec/atuin/atuin-init.bash ] && . /usr/libexec/atuin/atuin-init.bash

# ble.sh — attach at the very end, after all other hooks are in place.
[[ ${BLE_VERSION-} ]] && ble-attach


# Added by Antigravity CLI installer
export PATH="/home/ldzbeta/.local/bin:$PATH"
