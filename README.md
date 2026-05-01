# Hyprland + Noctalia dotfiles

A complete personal Fedora 43 setup: Hyprland compositor, Noctalia shell,
kitty + bash + ble.sh + atuin, custom video-wallpaper support, battery
charge limit, adaptive page-cache pre-warming, and a written user manual.

## What's in here

```
dotfiles/
├── README.md                       this file
├── install.sh                      bootstrap script (idempotent)
├── .gitignore
├── home/                           mirrors into $HOME on install
│   ├── .bashrc, .blerc
│   ├── .config/
│   │   ├── hypr/                   compositor config (with our overrides)
│   │   ├── kitty/                  terminal
│   │   ├── fastfetch/              login splash
│   │   ├── atuin/config.toml       compact history dropdown
│   │   ├── kdeglobals              KDE/Qt theme
│   │   ├── gtk-3.0/, gtk-4.0/      GTK theme
│   │   ├── fontconfig/fonts.conf   sans→Inter, mono→JetBrainsMono NF
│   │   ├── noctalia/               settings + custom plugins (incl. patched wallcards)
│   │   ├── quickshell/             overview + HyprQuickFrame
│   │   └── systemd/user/           prewarm-apps service & timer
│   └── .local/
│       ├── bin/                    helpers (charge-limit, wallcards-video, prewarm-apps, hyprland-* stubs)
│       └── share/applications/     user .desktop overrides (Brave, Settings)
├── system/                         needs sudo to install
│   ├── etc/sudoers.d/charge-limit  passwordless invocation of /usr/local/bin/charge-limit
│   ├── etc/tmpfiles.d/             boot battery threshold persistence
│   ├── etc/bluetooth/main.conf     auto-enable + reconnect tuning
│   └── usr/local/bin/charge-limit
├── patches/
│   └── HyprlandService.qml.patch   Noctalia spawn-path optimization (applied by install.sh)
└── docs/
    └── HYPRLAND_NOCTALIA_USER_MANUAL.md
```

## Quick start on a fresh Fedora 43 machine

```bash
git clone https://github.com/<you>/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script:

1. enables the `solopasha/hyprland` COPR and Flathub
2. installs all RPM packages
3. clones & builds `ble.sh` into `~/.local/share/blesh/`
4. mirrors `./home/` into `$HOME` (existing files backed up as `*.preinst.bak`)
5. installs `./system/` files into `/etc/` and `/usr/local/bin/` via sudo
6. patches Noctalia's `HyprlandService.qml` to skip the `hyprctl` IPC fork hop on app launch
7. enables `prewarm-apps.timer` (boot + weekly page-cache warmup)
8. runs `systemd-tmpfiles --create` so battery threshold applies at boot

Re-running is safe; existing files are backed up before overwrite.

## Notable pieces

- **Battery 80% limit** — `sudo charge-limit 80|100|status`. Persists at boot via `systemd-tmpfiles`.
- **Adaptive prewarm** — reads Noctalia's launcher click counts from `~/.cache/noctalia/shell-state.json`, picks top-8 apps with ≥3 launches, `vmtouch -t`s their install dirs into kernel page cache. Runs at boot+weekly. Zero permanent RAM.
- **Video wallpapers** — patched the upstream wallcards plugin to actually apply videos via `mpvpaper` (upstream has the apply path as a TODO).
- **ble.sh + atuin** — fish-style inline ghost-text autosuggestions + Ctrl+R compact history dropdown. Up arrow stays as stock bash.
- **Bluetooth resilience** — `JustWorksRepairing=always`, `AutoEnable=true`, `ReconnectAttempts=7` with exponential backoff; `blueman-applet` in autostart.

## What's NOT in here

- Browser profiles (Brave/Firefox) — too big and contain credentials/cookies
- Atuin shell history database — machine-local & potentially sensitive
- Quickshell runtime sockets/logs (regenerated on start)
- Wallpapers — drop your own into `~/Pictures/Wallpapers/`

See `.gitignore` for the full list of excluded paths.

## Reverting

Every file the installer overwrites is backed up to `*.preinst.bak` in the
same directory. To revert a file:

```bash
mv ~/.bashrc.preinst.bak ~/.bashrc
sudo mv /etc/bluetooth/main.conf.preinst.bak /etc/bluetooth/main.conf
```

To remove the Noctalia QML patch:

```bash
sudo mv /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml.bak \
        /etc/xdg/quickshell/noctalia-shell/Services/Compositor/HyprlandService.qml
```

To stop the prewarm timer:

```bash
systemctl --user disable --now prewarm-apps.timer
```

## License

MIT — do whatever you want.
