# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Nux Droid is a pure-Bash installer that turns Termux on Android into a full Linux desktop. There is no build system, no package manager, and no test suite — it is a collection of shell scripts that run **on-device inside Termux**, not on a developer machine. They cannot be executed on this Windows checkout; they target the Termux runtime (`/data/data/com.termux/...`, `$PREFIX`, Android `getprop`/`wm` tools, `proot-distro`).

The canonical interpreter line is `#!/data/data/com.termux/files/usr/bin/bash`.

## Verifying changes

Since the scripts can't run here, verification is limited to static checks:

```bash
bash -n install.sh            # syntax check a single file
for f in lib/*.sh commands/*.sh install.sh; do bash -n "$f"; done
shellcheck install.sh lib/*.sh commands/*.sh   # if shellcheck is available
```

Real testing happens by running the install one-liner on an Android/Termux device.

## Two execution contexts

The single most important thing to understand: code runs in **two different environments**, and you must always know which one you're targeting.

- **Termux (Android host)** — where `nux`, `install.sh`, GPU renderers, PulseAudio, and Termux-X11 live.
- **Ubuntu (proot guest)** — the actual Linux distro installed via `proot-distro`, where the desktop and apps run.

Cross the boundary only through the helpers in `lib/utils.sh`:
- `run_in_ubuntu <cmd>` — runs as root inside the proot Ubuntu.
- `run_in_ubuntu_user <cmd>` — runs as the created user inside proot Ubuntu.

The proot rootfs lives at `$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu` (`$NUX_PROOT_DIR`).

## Architecture

**Entry point — `install.sh`** (runs via `curl … | bash`): pre-flight checks → installs Termux dependencies → downloads every `lib/` and `commands/` file from `$NUX_REPO` into `$PREFIX/share/nux` → generates the `nux` command router → sources the libs → runs the onboarding wizard (steps 1–9) → installs Ubuntu + desktop + apps.

**The `nux` router** is **generated as a heredoc inside `install.sh`** (the `NUXCMD` block, written to `$PREFIX/bin/nux`). It is not a tracked file. To add a subcommand you must edit that heredoc's `case` statement **and** add the file to the download loops below.

**`lib/`** — sourced function libraries, no `main()`:
- `utils.sh` — foundation: colors, output helpers, logging, profile read/write, input prompts, the proot bridge. Sourced by everything.
- `profiler.sh` — detects GPU family / RAM / storage / Android version via `getprop` and `/proc`.
- `gpu.sh` — the three-tier GPU system (see below).
- `audio.sh`, `display.sh`, `locale.sh`, `username.sh`, `de.sh`, `apps.sh`, `banner.sh` — one onboarding concern each. Most expose a `setup_*`/`install_*` pair: `setup_*` runs during onboarding (detect + prompt + save to profile), `install_*` does the heavy proot work.

**`commands/`** — each is a standalone script with its own `main()` that re-derives `SCRIPT_DIR` and sources the libs it needs. `start.sh`, `stop.sh`, `apps.sh`, `backup.sh`, `restore.sh`, `update.sh`, `uninstall.sh`.

## Profile: the state contract

All persistent state is `KEY=value` lines in `$HOME/.nux/profile` (`$NUX_PROFILE`). This is the contract between onboarding (which writes it) and the runtime commands (which read it). Always use the helpers, never hand-edit:

- `save_profile KEY VALUE` — upsert.
- `load_profile KEY` — echo one value (callers supply defaults: `x=$(load_profile X); x="${x:-default}"`).
- `load_all_profile` — source the whole file as shell vars.

Keys include `GPU_FAMILY`, `GPU_TIER`, `GPU_DRIVER_SHORT`, `RAM_MB`, `USERNAME`, `DE`/`DE_PKG`/`DE_SESSION`, `SELECTED_APPS`, `DISPLAY_*`, `LOCALE`, `TIMEZONE`. GPU env vars are written separately to `$HOME/.nux/gpu_env.sh` and sourced in both Termux and proot.

## GPU three-tier system (`lib/gpu.sh`)

Tier 1 = Turnip+Zink (Adreno/Snapdragon), Tier 2 = VirGL (Mali/Xclipse/etc.), Tier 3 = llvmpipe (software fallback). `detect_gpu_family` (in `profiler.sh`) maps SoC strings to a family; `get_gpu_tier` maps family → tier. `setup_gpu` selects, lets the user override, runs a short render test, and **silently falls back down the tiers** if a test fails. The chosen tier drives both `set_gpu_env_vars` (writes `gpu_env.sh`) and `start_gpu_renderer`/`stop_gpu_renderer` (used by `nux start`/`nux stop`).

## Conventions to preserve

**Three file lists must stay in sync** when adding/removing/renaming a script:
1. `install.sh` — the `for f in …; do download_file "lib/$f"; done` and the `commands/` loop.
2. `install.sh` — the `nux` router heredoc `case` (for new subcommands).
3. `update.sh` — the `files=( … )` array.

**Logging / error-handling discipline:**
- `run_logged "desc" cmd…` — runs a critical command, pipes output to `$NUX_LOG`, and calls `report_failure` (fatal, prints log tail) on non-zero exit.
- `run_with_spinner "label" cmd…` — same logging but **returns** the exit code so the caller decides. Used for *optional* steps (individual apps, GPU packages) that warn-and-continue rather than abort.
- Rule of thumb: base system / desktop install = fatal (`run_logged`/`report_failure`); optional apps and GPU packages = non-fatal (`run_with_spinner` + `warn`).

**Duplicated bootstrap helpers:** `install.sh` defines its *own* copies of the colors, `report_failure`, and `run_logged` near the top, because it must log failures *before* it has downloaded `lib/utils.sh`. These are intentional duplicates of the canonical versions in `utils.sh` — if you change logging behavior in one, mirror it in the other.

**`install.sh` runs under `set -Eeo pipefail` with an `ERR` trap** that calls `report_failure`. Be careful with commands expected to fail: guard them with `set +e`/`set -e` (as the apt/proot streaming blocks do) or `|| true`.

**Output style** is deliberate: `info`/`success`/`warn`/`error`/`die` helpers, `stage N 9 "label"` for the numbered onboarding headers, `progress_bar`, and `spinner`. Match this rather than raw `echo` so the UX stays consistent.

## Repo / network constants

`$NUX_REPO` (`https://raw.githubusercontent.com/rexroze/nux/main`) is where install/update fetch scripts from, and `$NUX_RELEASE_API` is polled for the latest version tag. The hardcoded `NUX_VERSION="1.0"` appears in `install.sh`, `utils.sh`, and the router heredoc — bump all of them together for a release.
