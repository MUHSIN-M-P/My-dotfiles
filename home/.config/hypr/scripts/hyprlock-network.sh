#!/usr/bin/env bash
SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes:" | cut -d: -f2)
if [ -n "$SSID" ]; then
    echo "󰤨 $SSID"
    exit 0
fi

IFACE=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
if [ -n "$IFACE" ]; then
    echo "󰈀 $IFACE"
else
    echo "󰤭 Offline"
fi
