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

## Pushing to Github Changes
cd ~/dotfiles

# This will sync your files, add them, and commit them with a message
./sync.sh -c "Add UI contrast patches, top bar coloring, and keyboard nav fixes"

# Push to your GitHub repo
git push

