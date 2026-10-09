#!/usr/bin/env bash
# Toggle floating; when floating, resize active window to launcher-like size and center it.

WIDTH=984
HEIGHT=864

floating=$(hyprctl activewindow -j | jq -r '.floating')

if [ "$floating" = "false" ]; then
  hyprctl dispatch togglefloating active
  hyprctl dispatch resizeactive exact "$WIDTH $HEIGHT"
  hyprctl dispatch centerwindow
else
  hyprctl dispatch togglefloating active
fi