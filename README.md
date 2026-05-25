# Nux Droid

**One-command Linux desktop for Android.**

Paste a single line into Termux and get a fully functional Ubuntu desktop with GPU acceleration, audio, and apps — no Linux knowledge required.

```
 ███╗   ██╗██╗   ██╗██╗  ██╗
 ████╗  ██║██║   ██║╚██╗██╔╝
 ██╔██╗ ██║██║   ██║ ╚███╔╝
 ██║╚██╗██║██║   ██║ ██╔██╗
 ██║ ╚████║╚██████╔╝██╔╝ ██╗
 ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
 Droid            v1.0 | @rexroze
```

---

## Features

- **One command install** — copy, paste, done
- **GPU acceleration** — Turnip+Zink for Snapdragon, VirGL for Mali/Exynos/Tensor, automatic fallback
- **Auto-detects everything** — GPU, RAM, display resolution, locale, timezone
- **Polished onboarding** — progress bars, color-coded output, stage labels
- **4 desktop environments** — XFCE (default), KDE Plasma, LXDE, MATE
- **Curated app picker** — browse by category, see install sizes, add more anytime
- **Full backup & restore** — one command to save, one to restore
- **Self-updating** — scripts and system packages update together
- **Clean uninstall** — removes everything, leaves nothing behind

---

## Requirements

| Requirement | Minimum |
|-------------|---------|
| Android | 10 or newer |
| RAM | 4GB (2GB possible with LXDE) |
| Free storage | 8GB recommended |
| Termux | Latest from [F-Droid](https://f-droid.org/en/packages/com.termux/) |
| Termux-X11 | Install from [GitHub releases](https://github.com/termux/termux-x11/releases) |

> **Important:** Install Termux from F-Droid, not the Play Store. The Play Store version is outdated and will not work.

---

## Installation

Open Termux and paste:

```bash
curl -sL https://raw.githubusercontent.com/rexroze/nux/main/install.sh | bash
```

### What happens:

1. Termux packages are updated
2. Storage permissions are checked
3. Internet connectivity is verified
4. Dependencies are installed (proot-distro, termux-x11, pulseaudio)
5. Nux scripts are downloaded
6. The onboarding wizard launches:
   - Device scan (GPU, RAM, storage, Android version)
   - GPU driver selection with automatic testing
   - Username setup
   - Desktop environment selection
   - App picker (categories → individual apps)
   - Confirmation with total install size
   - Installation with visual progress
7. Done — you get a summary and instructions

---

## Quick Start

After installation:

1. **Open the Termux-X11 app** on your device (install it first if you haven't)
2. **Go back to Termux** and run:
   ```bash
   nux start
   ```
3. **Switch to Termux-X11** — your desktop is ready

First boot may take 30-60 seconds.

---

## Commands

| Command | What it does |
|---------|-------------|
| `nux start` | Launch proot session, GPU driver, audio, display, and desktop |
| `nux stop` | Cleanly kill all running processes |
| `nux apps` | Open the app picker to install more apps |
| `nux backup` | Compress everything into an archive on `/sdcard/Nux/backups/` |
| `nux restore` | Restore from a backup archive |
| `nux update` | Pull latest Nux scripts + run `apt upgrade` inside Ubuntu |
| `nux uninstall` | Remove everything — distro, configs, the `nux` command itself |
| `nux --help` | Show all available commands |

### `nux start` — what it does under the hood:

1. Loads your saved device profile and GPU driver choice
2. Sets GPU environment variables
3. Starts VirGL renderer or Turnip in background
4. Starts PulseAudio
5. Launches Termux-X11 display server
6. Boots proot Ubuntu with your selected desktop environment

### `nux stop`

Kills everything cleanly: desktop, X11, GPU renderer, PulseAudio, dbus.

### `nux uninstall`

Shows how much storage will be freed, requires typing `UNINSTALL` to confirm. Removes the proot distro, all configs, saved profiles, and the `nux` command itself.

---

## GPU Drivers

Nux uses a three-tier GPU priority system:

| Tier | Driver | Devices | Performance |
|------|--------|---------|-------------|
| 1 | Turnip + Zink | Snapdragon (Adreno GPU) | Best — near-native Vulkan |
| 2 | VirGL | Mali, Immortalis, Xclipse, Tensor | Good — hardware accelerated |
| 3 | llvmpipe | Everything else / fallback | Usable — software rendering |

### How it works:

1. Nux detects your GPU family (Adreno, Mali, Xclipse, etc.)
2. Selects the highest available tier
3. Runs a quick 2-second render test
4. If the test fails, silently falls back to the next tier
5. Software rendering is the last resort (with a warning)

### Manual override:

During onboarding, after auto-detection, you can choose a different driver. Your choice is saved and remembered by `nux start`.

---

## Supported Devices

Nux uses broad GPU family detection to maximize compatibility:

| SoC | GPU Family | Driver Tier |
|-----|-----------|-------------|
| Snapdragon 6xx/7xx/8xx | Adreno | Tier 1 (Turnip+Zink) |
| Dimensity 700-9000+ | Mali | Tier 2 (VirGL) |
| Exynos 990-2400 | Mali / Xclipse | Tier 2 (VirGL) |
| Google Tensor / Tensor G2-G4 | Mali | Tier 2 (VirGL) |
| Other | Varies | Tier 2 or 3 |

---

## Apps

### Core (always installed):

- Firefox — web browser
- Thunar — file manager
- xfce4-terminal — terminal emulator

### Optional (pick during install or with `nux apps`):

**Creative:**
- GIMP (image editor)
- Inkscape (vector graphics)
- Blender (3D modeling)

**Dev Tools:**
- VS Code (code-server)
- Git
- Node.js
- Python 3

**Office:**
- LibreOffice (full suite)

**Media:**
- VLC (media player)
- Audacity (audio editor)

**Utilities:**
- htop (system monitor)
- neofetch (system info)

Every app shows its estimated install size. Run `nux apps` anytime to add more.

---

## Backup and Restore

### Backup:

```bash
nux backup
```

Creates a compressed archive at `/sdcard/Nux/backups/` containing your full Ubuntu environment, configs, profile, and app list. Transfer it to cloud storage or a PC.

### Restore:

```bash
nux restore
```

Lists available backups or accepts a file path. Validates the archive, warns about hardware differences, and restores everything.

---

## Troubleshooting

### Desktop doesn't start

1. Make sure Termux-X11 app is installed and open
2. Run `nux stop` then `nux start`
3. Check that you haven't run out of storage

### No GPU acceleration

1. Run `nux start` — it auto-detects and falls back
2. If you're on Snapdragon and Turnip isn't working, the driver may not support your specific Adreno model. VirGL fallback should kick in automatically.

### No audio

1. Audio should work automatically via PulseAudio
2. Run `nux stop && nux start` to restart audio
3. Make sure your phone's volume is up

### "proot-distro: command not found"

Run `pkg install proot-distro` and try again.

### Black screen in Termux-X11

1. Wait 30-60 seconds on first boot
2. Try tapping the screen
3. Run `nux stop && nux start`

### Storage full

Run `nux uninstall` to free space, or remove individual apps from inside Ubuntu using `sudo apt remove <package>`.

---

## Uninstall

```bash
nux uninstall
```

Shows how much space will be recovered. Requires typing `UNINSTALL` to confirm. Removes everything and leaves no leftover files.

---

## Credits

Made by **@rexroze**

---

*Nux Droid v1.0*
