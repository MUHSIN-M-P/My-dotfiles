Even better (adaptive preload — your level)

Instead of always preloading, make it conditional

✅ Smart version:
exec-once = bash -c 'sleep 7 && free=$(free -m | awk "/^Mem:/ {print $7}"); if [ "$free" -gt 2000 ]; then brave-browser --no-startup-window; fi'
💡 What this does
checks available RAM
only preloads if >2GB free

👉 This is next-level optimization

---
force iGPU for rendering (VERY IMPORTANT for laptops)

Right now:

system may switch between Intel + NVIDIA

👉 causes stutter

Force Intel (better for Hyprland)

Add in:

nano ~/.config/hypr/configs/user-overrides.conf
env = WLR_DRM_DEVICES,/dev/dri/card0
⚠️ Note:
card0 = usually Intel
safer for Wayland compositors
Revert if issues:
#### remove that line


You have great intuition—that is indeed a known bug, and it wasn't a malicious application spying on you!

The Cause: The phantom "Camera is active" notifications happen because your system's multimedia server (WirePlumber) ships with two separate camera tracking modules enabled by default: v4l2 (the standard Linux video module) and libcamera (a newer camera API). Because you have a standard UVC webcam, both modules detect it and periodically "race" to probe it in the background. Every time libcamera briefly locks the device to probe it, your system's privacy portal (xdg-desktop-portal) thinks an application just triggered the camera and fires off a notification.

The Fix: I have applied a configuration override to disable the redundant libcamera monitor so that WirePlumber strictly uses v4l2 (which perfectly supports your webcam natively without the double-probing conflict).

I created a file at ~/.config/wireplumber/wireplumber.conf.d/51-disable-libcamera.conf and restarted 


## Pushing to Github Changes
cd ~/dotfiles

# This will sync your files, add them, and commit them with a message
./sync.sh -c "Add UI contrast patches, top bar coloring, and keyboard nav fixes"

# Push to your GitHub repo
git push

