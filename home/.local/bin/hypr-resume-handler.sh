#!/usr/bin/env bash

# Exit if another instance is already running
MY_PID=$$
for pid in $(pgrep -f "hypr-resume-handler.sh"); do
    if [ "$pid" != "$MY_PID" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

# Monitor DBus PrepareForSleep signal
dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" | while read -r line; do
    # Log suspend event
    if echo "$line" | grep -q "boolean true"; then
        echo "$(/usr/bin/date +%s) suspend" >> /home/ldzbeta/.local/state/sys-stats-lock.log
    fi

    # When system resumes, PrepareForSleep outputs 'boolean false'
    if echo "$line" | grep -q "boolean false"; then
        # Log resume event to mark end of sleep gap
        echo "$(/usr/bin/date +%s) resume" >> /home/ldzbeta/.local/state/sys-stats-lock.log

        # Retry turning on DPMS to ensure the graphics driver is ready.
        # We run it multiple times with short delays (0.2s) so it wakes up as fast as the GPU driver initializes,
        # making it feel snappy like Windows.
        for i in {1..5}; do
            hyprctl dispatch dpms on eDP-1
            sleep 0.2
        done
    fi
done
