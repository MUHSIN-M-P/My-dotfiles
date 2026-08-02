#!/usr/bin/env bash
# Script to toggle 4-finger window full space (hiding top bar + maximizing window).
# Removes border highlight color ONLY for 4-finger mode, preserving it for Super+F.

active_info=$(hyprctl activewindow -j 2>/dev/null)

if [ -z "$active_info" ] || [ "$active_info" = "{}" ]; then
    qs -c noctalia-shell ipc call bar toggle
    exit 0
fi

fs_mode=$(echo "$active_info" | jq -r '.fullscreen // 0')

if [ "$fs_mode" -eq 1 ]; then
    # Currently maximized -> restore window bounds, restore active border color, and show top bar
    hyprctl dispatch fullscreen 1
    hyprctl keyword "general:col.active_border" "rgba(45483aAA)"
    qs -c noctalia-shell ipc call bar showBar
elif [ "$fs_mode" -eq 2 ]; then
    # Currently true fullscreen -> exit true fullscreen, hide top bar, maximize, remove border highlight
    hyprctl dispatch fullscreen 0
    qs -c noctalia-shell ipc call bar hideBar
    hyprctl dispatch fullscreen 1
    hyprctl keyword "general:col.active_border" "rgba(00000000)"
else
    # Currently normal -> hide top bar, maximize window, and remove border highlight
    qs -c noctalia-shell ipc call bar hideBar
    hyprctl dispatch fullscreen 1
    hyprctl keyword "general:col.active_border" "rgba(00000000)"
fi
