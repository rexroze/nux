#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — nux backup
# Backs up the full proot Ubuntu environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

main() {
    echo ""
    echo -e "  ${CYAN}${BOLD}Nux Backup${RESET}"
    echo ""

    # Create backup directory
    mkdir -p "$NUX_BACKUP_DIR" 2>/dev/null
    if [[ ! -d "$NUX_BACKUP_DIR" ]]; then
        die "Cannot create backup directory at ${NUX_BACKUP_DIR}. Check storage permissions."
    fi

    local timestamp backup_file
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="${NUX_BACKUP_DIR}/nux_backup_${timestamp}.tar.gz"

    # Check if proot distro exists
    if [[ ! -d "$NUX_PROOT_DIR" ]]; then
        die "No Nux installation found to backup."
    fi

    # Estimate size
    local distro_size
    distro_size=$(du -sm "$NUX_PROOT_DIR" 2>/dev/null | awk '{print $1}')
    info "Environment size: ~${distro_size}MB"
    info "Backup destination: ${backup_file}"
    echo ""

    if ! prompt_yn "Start backup? This may take a few minutes."; then
        info "Backup cancelled."
        return
    fi

    echo ""
    info "Backing up... (this will take a while)"

    # Backup proot environment + nux profile
    tar czf "$backup_file" \
        -C "$(dirname "$NUX_PROOT_DIR")" "$(basename "$NUX_PROOT_DIR")" \
        -C "$HOME" ".nux" \
        2>/dev/null &
    spinner $! "Compressing environment"

    if [[ -f "$backup_file" ]]; then
        local backup_size
        backup_size=$(du -sm "$backup_file" 2>/dev/null | awk '{print $1}')
        echo ""
        success "Backup complete!"
        echo -e "    ${DIM}File:${RESET} ${WHITE}${backup_file}${RESET}"
        echo -e "    ${DIM}Size:${RESET} ${WHITE}${backup_size}MB${RESET}"
        echo ""
        echo -e "  ${DIM}You can move this file to cloud storage or a PC for safekeeping.${RESET}"
    else
        die "Backup failed. Check available storage."
    fi

    echo ""
}

main "$@"
