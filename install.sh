#!/data/data/com.termux/files/usr/bin/bash
# ─────────────────────────────────────────────────────────────
#  Nux Droid — One-Command Linux Desktop for Android
#  curl -sL https://raw.githubusercontent.com/rexroze/nux/main/install.sh | bash
# ─────────────────────────────────────────────────────────────

set -Eeo pipefail

NUX_VERSION="1.0"
NUX_REPO="https://raw.githubusercontent.com/rexroze/nux/main"
NUX_INSTALL_DIR="$PREFIX/share/nux"
NUX_DIR="$HOME/.nux"
NUX_LOG="$NUX_DIR/install.log"

# ── Minimal bootstrap colors ──
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

die() { echo -e "${RED}  ✖ $*${RESET}"; exit 1; }
info() { echo -e "${CYAN}  ℹ ${WHITE}$*${RESET}"; }
success() { echo -e "${GREEN}  ✔ ${WHITE}$*${RESET}"; }
warn() { echo -e "${YELLOW}  ⚠ ${WHITE}$*${RESET}"; }

# ── Logging ──
# Everything that does real work writes its output to $NUX_LOG so that a
# failure can be explained instead of silently aborting the script.

log_init() {
    mkdir -p "$(dirname "$NUX_LOG")"
    echo "=== Nux install — $(date) ===" > "$NUX_LOG"
}

# Print a clear failure message, the tail of the log, and where to find it.
report_failure() {
    echo ""
    echo -e "${RED}  ✖ ${WHITE}Failed: $1${RESET}"
    if [[ -s "$NUX_LOG" ]]; then
        echo -e "${DIM}  ── last lines of the log ──${RESET}"
        tail -n 20 "$NUX_LOG" | sed 's/^/    /'
        echo ""
        echo -e "${YELLOW}  Full log:${RESET} ${WHITE}$NUX_LOG${RESET}"
        echo -e "${DIM}  Share this log when reporting the problem.${RESET}"
    fi
    exit 1
}

# Bootstrap spinner — mirrors lib/utils.sh:spinner(). Needed here because the
# Termux-dependency phase runs before utils.sh has been downloaded. Animates
# next to $label, clears its line on exit; degrades off a TTY / without UTF-8.
spinner() {
    local pid="$1" label="$2"
    if [[ ! -t 1 ]]; then
        printf "  %s ...\n" "$label"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.3; done
        return
    fi
    local frames
    if [[ "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" == *[Uu][Tt][Ff]* ]]; then
        frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    else
        frames=('-' '\' '|' '/')
    fi
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${RESET} ${WHITE}%s${RESET}" "${frames[$((i % ${#frames[@]}))]}" "$label"
        sleep 0.1
        i=$((i + 1))
    done
    printf "\r\033[K"
}

# Run a command, capturing all output to the log; report on non-zero exit.
# Backgrounds the work so the spinner animates while it runs (mirrors
# lib/utils.sh:run_logged once that has loaded). Fatal on failure.
run_logged() {
    local desc="$1"; shift
    { echo ""; echo "\$ $*"; } >> "$NUX_LOG"
    "$@" >> "$NUX_LOG" 2>&1 &
    local pid=$!
    spinner "$pid" "$desc"
    if wait "$pid"; then
        success "$desc"
    else
        report_failure "$desc"
    fi
}

# Safety net: catch any unwrapped command that trips `set -e`.
trap 'report_failure "command on line $LINENO"' ERR

log_init

# ── Pre-flight checks ──

# 1. Verify Termux
if [[ ! -d "/data/data/com.termux" ]]; then
    die "Nux must be run inside Termux. Install Termux from F-Droid and try again."
fi

echo ""
echo -e "${CYAN}"
cat << 'BANNER'
   ███╗   ██╗██╗   ██╗██╗  ██╗
   ████╗  ██║██║   ██║╚██╗██╔╝
   ██╔██╗ ██║██║   ██║ ╚███╔╝
   ██║╚██╗██║██║   ██║ ██╔██╗
   ██║ ╚████║╚██████╔╝██╔╝ ██╗
   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
BANNER
echo -e "${RESET}"
echo -e "   ${DIM}Droid${RESET}            ${CYAN}v${NUX_VERSION}${RESET} ${DIM}|${RESET} ${CYAN}@rexroze${RESET}"
echo ""
echo -e "  ${DIM}──────────────────────────────────────────────────${RESET}"
echo ""
echo -e "  ${BOLD}${WHITE}Preparing your system...${RESET}"
echo ""

# 2. Update Termux packages
info "Updating Termux packages..."
run_logged "Updating Termux packages" pkg update -y -o Dpkg::Options::="--force-confnew"
run_logged "Upgrading Termux packages" pkg upgrade -y -o Dpkg::Options::="--force-confnew"
success "Termux packages updated."

# 3. Setup storage
info "Checking storage permissions..."
if [[ ! -d "$HOME/storage" ]]; then
    termux-setup-storage 2>/dev/null
    sleep 2
fi
success "Storage permissions OK."

# 4. Check internet
info "Checking internet connectivity..."
if ! ping -c 1 -W 3 google.com > /dev/null 2>&1; then
    if ! ping -c 1 -W 3 github.com > /dev/null 2>&1; then
        die "No internet connection. Connect to the internet and try again."
    fi
fi
success "Internet connected."

# 5. Check available storage
info "Checking available storage..."
available_mb=$(df "$PREFIX" 2>/dev/null | awk 'NR==2{print int($4/1024)}')
if [[ -n "$available_mb" ]]; then
    if ((available_mb < 4000)); then
        warn "Only ${available_mb}MB free. Nux needs at least 4GB. You may run out of space."
    else
        success "Storage: ${available_mb}MB available."
    fi
fi

echo ""

# ── Install dependencies ──
info "Installing core dependencies..."

# termux-x11-nightly lives in the x11-repo, which must be enabled first.
run_logged "Enabling X11 package repository" pkg install -y x11-repo
run_logged "Refreshing package lists" pkg update -y -o Dpkg::Options::="--force-confnew"

# Install each dependency on its own so a failure names the exact package.
for dep in proot-distro termux-x11-nightly pulseaudio wget git curl; do
    run_logged "Installing $dep" pkg install -y "$dep"
done
success "Dependencies installed."

# ── Download Nux scripts ──
info "Downloading Nux..."

mkdir -p "$NUX_INSTALL_DIR"/{lib,commands,assets}
mkdir -p "$NUX_DIR"

# Download one file, retrying once. -f makes curl fail on HTTP errors (e.g. 404)
# instead of silently writing the error page; we also verify the file is non-empty
# so a bad download is caught here rather than later as a confusing `source:` error.
download_file() {
    local path="$1"
    local url="${NUX_REPO}/${path}"
    local dest="${NUX_INSTALL_DIR}/${path}"
    local attempt
    mkdir -p "$(dirname "$dest")"   # supports nested paths like assets/xfce4/…
    for attempt in 1 2; do
        { echo ""; echo "\$ curl -fsSL $url"; } >> "$NUX_LOG"
        if curl -fsSL "$url" -o "$dest" >> "$NUX_LOG" 2>&1 && [[ -s "$dest" ]]; then
            return 0
        fi
        sleep 1
    done
    report_failure "Downloading ${path} (${url})"
}

# Download all library files
for f in utils.sh banner.sh profiler.sh gpu.sh audio.sh display.sh locale.sh apps.sh de.sh username.sh; do
    download_file "lib/$f"
done

# Download all command files
for f in start.sh stop.sh apps.sh backup.sh restore.sh update.sh uninstall.sh; do
    download_file "commands/$f"
done

# Download bundled assets (e.g. the fallback XFCE panel layout)
for f in xfce4/xfce4-panel.xml; do
    download_file "assets/$f"
done

# Make everything executable
chmod +x "$NUX_INSTALL_DIR"/commands/*.sh 2>/dev/null
chmod +x "$NUX_INSTALL_DIR"/lib/*.sh 2>/dev/null

success "Nux scripts installed."

# ── Create nux command ──
cat > "$PREFIX/bin/nux" << 'NUXCMD'
#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Command Router

NUX_DIR="$PREFIX/share/nux"
NUX_VERSION="1.0"

show_help() {
    echo ""
    echo -e "\033[1;36m"
    cat << 'B'
   ███╗   ██╗██╗   ██╗██╗  ██╗
   ████╗  ██║██║   ██║╚██╗██╔╝
   ██╔██╗ ██║██║   ██║ ╚███╔╝
   ██║╚██╗██║██║   ██║ ██╔██╗
   ██║ ╚████║╚██████╔╝██╔╝ ██╗
   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
B
    echo -e "\033[0m"
    echo -e "   \033[2mDroid\033[0m            \033[1;35mv${NUX_VERSION}\033[0m \033[2m|\033[0m \033[1;36m@rexroze\033[0m"
    echo ""
    echo -e "  \033[1;37mCommands:\033[0m"
    echo ""
    echo -e "    \033[1;32mnux start\033[0m        Launch your Linux desktop"
    echo -e "    \033[1;32mnux stop\033[0m         Shut down the desktop"
    echo -e "    \033[1;32mnux apps\033[0m         Install additional apps"
    echo -e "    \033[1;32mnux backup\033[0m       Backup your environment"
    echo -e "    \033[1;32mnux restore\033[0m      Restore from a backup"
    echo -e "    \033[1;32mnux update\033[0m       Update Nux and system packages"
    echo -e "    \033[1;32mnux uninstall\033[0m    Remove Nux completely"
    echo -e "    \033[1;32mnux --help\033[0m       Show this help"
    echo ""
}

case "${1:-}" in
    start)     exec bash "$NUX_DIR/commands/start.sh" "${@:2}" ;;
    stop)      exec bash "$NUX_DIR/commands/stop.sh" "${@:2}" ;;
    apps)      exec bash "$NUX_DIR/commands/apps.sh" "${@:2}" ;;
    backup)    exec bash "$NUX_DIR/commands/backup.sh" "${@:2}" ;;
    restore)   exec bash "$NUX_DIR/commands/restore.sh" "${@:2}" ;;
    update)    exec bash "$NUX_DIR/commands/update.sh" "${@:2}" ;;
    uninstall) exec bash "$NUX_DIR/commands/uninstall.sh" "${@:2}" ;;
    --help|-h|help|"") show_help ;;
    *)
        echo -e "\033[1;31m  ✖ Unknown command: $1\033[0m"
        echo -e "  \033[2mRun \033[1;32mnux --help\033[0m\033[2m for available commands.\033[0m"
        exit 1
        ;;
esac
NUXCMD
chmod +x "$PREFIX/bin/nux"

success "nux command installed."

echo ""

# ── Source libraries and run onboarding ──
source "$NUX_INSTALL_DIR/lib/utils.sh"
source "$NUX_INSTALL_DIR/lib/banner.sh"
source "$NUX_INSTALL_DIR/lib/profiler.sh"
source "$NUX_INSTALL_DIR/lib/gpu.sh"
source "$NUX_INSTALL_DIR/lib/audio.sh"
source "$NUX_INSTALL_DIR/lib/display.sh"
source "$NUX_INSTALL_DIR/lib/locale.sh"
source "$NUX_INSTALL_DIR/lib/username.sh"
source "$NUX_INSTALL_DIR/lib/de.sh"
source "$NUX_INSTALL_DIR/lib/apps.sh"

# ── Step 1: Welcome ──
show_welcome

# ── Step 2: Device Profiling ──
run_device_profiling

# ── Step 3-4: GPU Setup + Test ──
setup_gpu

# ── Step 5: Username ──
setup_username

# ── Step 6: Desktop Environment ──
setup_desktop_environment

# ── Step 7: App Selection ──
show_app_picker "false"

# ── Step 8: Confirmation ──
show_confirmation

# ── Step 9: Installation ──
stage 8 9 "Installing everything..."
echo ""

# Install Ubuntu via proot-distro
if ! proot-distro list 2>/dev/null | grep -q "$NUX_DISTRO"; then
    info "Installing Ubuntu via proot-distro... (this can take a few minutes)"
    run_logged "Installing Ubuntu via proot-distro" proot-distro install "$NUX_DISTRO"
else
    success "Ubuntu already installed."
fi

# Base system setup inside Ubuntu
info "Setting up base system..."
run_logged "Installing base system packages" run_in_ubuntu bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        sudo \
        nano \
        wget \
        curl \
        ca-certificates \
        locales \
        dbus-x11
"
success "Base system configured."

# Setup username inside Ubuntu
info "Creating user account..."
username=$(load_profile "USERNAME")
username="${username:-nuxdroid}"
run_logged "Creating user account '${username}'" run_in_ubuntu bash -c "
    if ! id '${username}' &>/dev/null; then
        useradd -m -s /bin/bash '${username}'
        echo '${username} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
        cat > /home/${username}/.bashrc << 'BASHEOF'
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=xterm-256color
export PULSE_SERVER=127.0.0.1
alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'
BASHEOF
        chown -R '${username}:${username}' /home/${username}
    fi
"
success "User '${username}' created."

# Configure locale and timezone
info "Configuring locale and timezone..."
setup_locale

# Configure audio
info "Configuring audio..."
setup_audio

# Detect display
info "Detecting display..."
detect_display

# Install desktop environment
info "Installing desktop environment..."
install_desktop_environment

# Install core apps
info "Installing core apps..."
install_core_apps

# Install selected optional apps
info "Installing selected apps..."
install_selected_apps

# Make the XFCE desktop deterministic so the panel always renders, even after
# the extra apps above pulled in autostart entries / menu changes (see de.sh).
repair_xfce_desktop full

# ── Step 10: Completion ──
stage 9 9 "Finishing up..."
save_profile "NUX_VERSION" "$NUX_VERSION"
save_profile "INSTALLED_AT" "$(date -Iseconds)"

show_completion
