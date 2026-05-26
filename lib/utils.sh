#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Shared Utilities
# Common functions used across all Nux scripts

NUX_VERSION="1.0"
NUX_DIR="$HOME/.nux"
NUX_PROFILE="$NUX_DIR/profile"
NUX_DISTRO="ubuntu"
NUX_PROOT_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"
NUX_BACKUP_DIR="/sdcard/Nux/backups"
NUX_REPO="https://raw.githubusercontent.com/rexroze/nux/main"
NUX_RELEASE_API="https://api.github.com/repos/rexroze/nux/releases/latest"
NUX_LOG="$NUX_DIR/install.log"

# ── Colors ──
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Output helpers ──
msg()     { echo -e "${WHITE}$*${RESET}"; }
info()    { echo -e "${CYAN}  ℹ ${WHITE}$*${RESET}"; }
success() { echo -e "${GREEN}  ✔ ${WHITE}$*${RESET}"; }
warn()    { echo -e "${YELLOW}  ⚠ ${WHITE}$*${RESET}"; }
error()   { echo -e "${RED}  ✖ ${WHITE}$*${RESET}"; }
die()     { error "$*"; exit 1; }

# ── Logging ──
# Real work writes its output to $NUX_LOG so a failure can be explained.
# report_failure / run_logged mirror the bootstrap copies in install.sh.
report_failure() {
    echo ""
    error "Failed: $1"
    if [[ -s "$NUX_LOG" ]]; then
        echo -e "${DIM}  ── last lines of the log ──${RESET}"
        tail -n 20 "$NUX_LOG" | sed 's/^/    /'
        echo ""
        echo -e "${YELLOW}  Full log:${RESET} ${WHITE}$NUX_LOG${RESET}"
        echo -e "${DIM}  Share this log when reporting the problem.${RESET}"
    fi
    exit 1
}

run_logged() {
    local desc="$1"; shift
    { echo ""; echo "\$ $*"; } >> "$NUX_LOG"
    if ! "$@" >> "$NUX_LOG" 2>&1; then
        report_failure "$desc"
    fi
}

# Stage header: [1/8] Installing Ubuntu...
stage() {
    local current="$1" total="$2" label="$3"
    echo ""
    echo -e "${MAGENTA}  [${current}/${total}]${BOLD}${WHITE} ${label}${RESET}"
    echo -e "${DIM}  $(printf '─%.0s' $(seq 1 50))${RESET}"
}

# ── Progress bar ──
# Usage: progress_bar 45 100 "Installing packages"
progress_bar() {
    local current="$1" total="$2" label="${3:-}"
    local pct=$((current * 100 / total))
    local filled=$((pct / 2))
    local empty=$((50 - filled))
    local bar="${GREEN}"
    for ((i=0; i<filled; i++)); do bar+="█"; done
    bar+="${DIM}"
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="${RESET}"
    printf "\r  %s ${WHITE}%3d%%${RESET} %s" "$bar" "$pct" "$label"
    [[ "$current" -eq "$total" ]] && echo ""
}

# ── Spinner ──
spinner() {
    local pid="$1" label="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${RESET} ${WHITE}%s${RESET}" "${frames[$((i % ${#frames[@]}))]}" "$label"
        sleep 0.1
        i=$((i + 1))
    done
    printf "\r  ${GREEN}✔${RESET} ${WHITE}%s${RESET}\n" "$label"
}

# Run a command with a spinner, sending its output to the log.
# Returns the wrapped command's exit code so callers can react to failure.
run_with_spinner() {
    local label="$1"; shift
    { echo ""; echo "\$ $*"; } >> "$NUX_LOG"
    "$@" >> "$NUX_LOG" 2>&1 &
    local pid=$!
    spinner "$pid" "$label"
    local rc=0
    wait "$pid" || rc=$?
    return "$rc"
}

# ── Profile helpers ──
ensure_nux_dir() {
    mkdir -p "$NUX_DIR" 2>/dev/null
}

save_profile() {
    local key="$1" value="$2"
    ensure_nux_dir
    if grep -q "^${key}=" "$NUX_PROFILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$NUX_PROFILE"
    else
        echo "${key}=${value}" >> "$NUX_PROFILE"
    fi
}

load_profile() {
    local key="$1"
    grep "^${key}=" "$NUX_PROFILE" 2>/dev/null | cut -d'=' -f2-
}

load_all_profile() {
    [[ -f "$NUX_PROFILE" ]] && source "$NUX_PROFILE"
}

# ── Input helpers ──
prompt_choice() {
    local prompt="$1"; shift
    local options=("$@")
    echo ""
    echo -e "  ${BOLD}${WHITE}${prompt}${RESET}"
    echo ""
    for i in "${!options[@]}"; do
        echo -e "    ${CYAN}$((i+1)))${RESET} ${options[$i]}"
    done
    echo ""
    while true; do
        printf "  ${BOLD}▸${RESET} "
        read -r choice < /dev/tty
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
            return $((choice - 1))
        fi
        echo -e "  ${RED}Invalid choice. Enter a number 1-${#options[@]}.${RESET}"
    done
}

prompt_yn() {
    local prompt="$1" default="${2:-y}"
    local hint="[Y/n]"
    [[ "$default" == "n" ]] && hint="[y/N]"
    printf "  ${BOLD}${WHITE}%s${RESET} ${DIM}%s${RESET} " "$prompt" "$hint"
    read -r answer < /dev/tty
    answer="${answer:-$default}"
    [[ "${answer,,}" == "y" ]]
}

prompt_text() {
    local prompt="$1" default="$2"
    # The prompt must go to the terminal, not stdout: callers use
    # value=$(prompt_text ...), so anything on stdout other than the final
    # answer would be captured into the returned value (and hidden from view).
    if [[ -n "$default" ]]; then
        printf "  ${BOLD}${WHITE}%s${RESET} ${DIM}[%s]${RESET}: " "$prompt" "$default" > /dev/tty
    else
        printf "  ${BOLD}${WHITE}%s${RESET}: " "$prompt" > /dev/tty
    fi
    read -r answer < /dev/tty
    echo "${answer:-$default}"
}

# ── System checks ──
check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        die "Nux must be run inside Termux."
    fi
}

check_internet() {
    if ! ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        if ! ping -c 1 -W 3 github.com > /dev/null 2>&1; then
            die "No internet connection detected. Please connect and try again."
        fi
    fi
}

check_storage() {
    local available_mb
    available_mb=$(df "$PREFIX" 2>/dev/null | awk 'NR==2{print int($4/1024)}')
    if [[ -n "$available_mb" ]] && ((available_mb < 4000)); then
        warn "Low storage: only ${available_mb}MB available. Nux needs at least 4GB free."
        if ! prompt_yn "Continue anyway?"; then
            die "Installation cancelled. Free up storage and try again."
        fi
    fi
}

bytes_to_human() {
    local bytes="$1"
    if ((bytes >= 1073741824)); then
        printf "%.1fGB" "$(echo "$bytes / 1073741824" | bc -l 2>/dev/null || echo "0")"
    elif ((bytes >= 1048576)); then
        printf "%dMB" "$((bytes / 1048576))"
    elif ((bytes >= 1024)); then
        printf "%dKB" "$((bytes / 1024))"
    else
        printf "%dB" "$bytes"
    fi
}

# ── proot-distro helpers ──
run_in_ubuntu() {
    proot-distro login "$NUX_DISTRO" -- "$@"
}

run_in_ubuntu_user() {
    local username
    username=$(load_profile "USERNAME")
    username="${username:-nuxdroid}"
    proot-distro login "$NUX_DISTRO" --user "$username" -- "$@"
}

# ── Separator ──
separator() {
    echo -e "  ${DIM}$(printf '─%.0s' $(seq 1 50))${RESET}"
}

clear_screen() {
    clear 2>/dev/null || printf '\033[2J\033[H'
}
