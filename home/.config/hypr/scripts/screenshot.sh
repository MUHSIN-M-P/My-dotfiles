#!/usr/bin/env bash
# Wrapper to launch HyprQuickFrame with animations disabled specifically for screenshot capture

# Prevent duplicate overlay instances
if pgrep -x "hyprquickframe" >/dev/null 2>&1; then
    exit 0
fi

# Always ensure animations are restored to enabled (1) after the layer surface unmaps
restore_anim() {
    sleep 0.05
    hyprctl --batch "keyword animations:enabled 1"
}
trap restore_anim EXIT INT TERM

# Disable animations before opening screenshot overlay
hyprctl --batch "keyword animations:enabled 0"

# Run screenshot tool
hyprquickframe
