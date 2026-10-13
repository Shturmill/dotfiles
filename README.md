# Dotsfile for hyprland

<p align="center">
  <a href="https://github.com/Shturmill/Traffic-Relay/stargazers">
    <img src="https://img.shields.io/github/stars/Shturmill/Traffic-Relay?style=for-the-badge&color=blue">
  </a>
  <a href="https://github.com/Shturmill/Traffic-Relay/commits/main">
    <img src="https://img.shields.io/github/last-commit/Shturmill/Traffic-Relay?style=for-the-badge&color=blue">
  </a>
</p>

**This repository contains the author's personal configuration files for Hyprland and related applications, along with an automated installation script.**

## Author`s system

![imag](data/image.png)

for fast installing you can run

```
git clone https://github.com/Shturmill/dotfiles
cd dotfiles
chmod +x install.sh
./install.sh
```

What re-running the installer does and does not do:

- Configs are updated file by file. Files that were removed from this repository stay in `~/.config` until you delete them, as do files you added yourself (e.g. a local `monitors.conf`).
- Firefox settings go to the profile's `user.js`. Removing a line from `firefox.txt` does not revert that setting: Firefox already copied its value into `prefs.js`, so reset it in `about:config`.
- Backups go to `~/.dotfiles_backups`; the last 10 runs are kept, plus `~/.dotfiles_backups/original/`, which keeps the first version of every file the installer replaced, i.e. your own configs from before it ran. Backup runs of installer 2.1 and older are moved to `original/legacy/` on the first run of a newer one and are never pruned.
- The lid-switch comment in `hyprland.lua` refers to the NixOS setup (`HandleLidSwitch=lock`). On Arch the installer does not touch logind, so closing the lid suspends the laptop; add a drop-in in `/etc/systemd/logind.conf.d/` with `HandleLidSwitch=lock` if you want the NixOS behaviour.
- Combining two `--only-*` flags runs nothing; pass one.

## Key Bindings

There you can shortcuts for apps i use

| Shortcut | Action |
|------------|----------|
| `Super + Q` | Open terminal (Kitty) |
| `Super + C` | Close selected window |
| `Super + E` | Open file manager (Thunar) |
| `Super + R` | Open Wofi |
| `Super + B` | Open Firefox |
| `Super + T` | Open Telegram |
| `Super + Shift+ S` | Take screenshot to clipboard |

**Note:** all orientation function the same as default hyprland config
