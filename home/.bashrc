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
export PATH="$HOME/.local/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# ===== GPU / NVIDIA Optimus Aliases =====
# Run any app on NVIDIA GPU: nvidia-run blender, nvidia-run ollama, etc.
alias nvidia-run='prime-run'
alias gpu-status='~/.local/bin/gpu-status'

# Quick CUDA test
alias cuda-test='python3 -c "import torch; print(\"CUDA available:\", torch.cuda.is_available()); print(\"GPU:\", torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\")" 2>/dev/null || echo "PyTorch not installed"'

# GPU switching helpers (requires reboot)
alias gpu-hybrid='pkexec envycontrol --switch hybrid && echo "Set to HYBRID mode — reboot required"'
alias gpu-nvidia='pkexec envycontrol --switch nvidia && echo "Set to NVIDIA-only mode — reboot required"'
alias gpu-intel='pkexec envycontrol --switch integrated && echo "Set to Intel-only mode — reboot required"'
