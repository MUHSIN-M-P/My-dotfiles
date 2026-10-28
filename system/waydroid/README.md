# Waydroid Configuration Back-up (Environment Only)

Stored in this repo: config + LXC setup only. **No user data / APKs** kept (repo stays small).

## What's tracked
- `lib/waydroid/` — `waydroid.cfg`, `waydroid.prop`, `waydroid_base.prop`
- `lxc/waydroid/` — container config files
- Scripts — `setup-waydroid`, `backup-waydroid`

## Images (not tracked — too large ~3GB)
Re-download with: `waydroid init -s GAPPS -f`

## Restore
```bash
sudo ./system/usr/local/bin/setup-waydroid
```

## Note on user data
Apps, accounts, and settings live in `$HOME/.local/share/waydroid/data`. These are **not** backed up; container will build fresh data dir on first start.
