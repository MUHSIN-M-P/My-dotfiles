#!/usr/bin/env bash
BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[ -z "$BAT" ] && exit 0

CAP=$(cat "$BAT/capacity" 2>/dev/null || echo 0)
STAT=$(cat "$BAT/status" 2>/dev/null || echo "Unknown")

if [ "$STAT" = "Charging" ]; then
    ICON="󰂄"
elif [ "$CAP" -ge 90 ]; then
    ICON="󰁹"
elif [ "$CAP" -ge 75 ]; then
    ICON="󰂁"
elif [ "$CAP" -ge 60 ]; then
    ICON="󰂀"
elif [ "$CAP" -ge 45 ]; then
    ICON="󰁾"
elif [ "$CAP" -ge 30 ]; then
    ICON="󰁽"
elif [ "$CAP" -ge 15 ]; then
    ICON="󰁺"
else
    ICON="󰂃"
fi

echo "$ICON ${CAP}%"
