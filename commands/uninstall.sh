#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — nux uninstall
# Completely removes Nux, the proot distro, configs, and the nux command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

main() {
    echo ""
    echo -e "  ${RED}${BOLD}Nux Uninstall${RESET}"
    echo ""

    # Estimate space recovery
    local distro_size=0 nux_size=0
    if [[ -d "$NUX_PROOT_DIR" ]]; then
        distro_size=$(du -sm "$NUX_PROOT_DIR" 2>/dev/null | awk '{print $1}')
    fi
    if [[ -d "$NUX_DIR" ]]; then
        nux_size=$(du -sm "$NUX_DIR" 2>/dev/null | awk '{print $1}')
    fi
    local total_size=$((distro_size + nux_size))

    echo -e "  ${DIM}This will remove:${RESET}"
    echo -e "    • Ubuntu proot environment"
    echo -e "    • All installed apps and data inside Ubuntu"
    echo -e "    • Nux configs, profiles, and GPU settings"
    echo -e "    • The ${GREEN}nux${RESET} command itself"
    echo ""
    echo -e "  ${DIM}Storage recovered: ~${total_size}MB${RESET}"
    echo ""

    warn "This action cannot be undone."
    echo ""
    if ! prompt_yn "Are you sure you want to uninstall Nux?" "n"; then
        info "Uninstall cancelled."
        return
    fi

    echo ""

    # Double confirmation
    echo -e "  ${RED}Type 'UNINSTALL' to confirm:${RESET}"
    printf "  ${BOLD}▸${RESET} "
    read -r confirm < /dev/tty
    if [[ "$confirm" != "UNINSTALL" ]]; then
        info "Uninstall cancelled."
        return
    fi

    echo ""

    # Stop running session
    "$SCRIPT_DIR/commands/stop.sh" 2>/dev/null

    # Remove proot distro
    if command -v proot-distro &>/dev/null; then
        run_with_spinner "Removing Ubuntu environment" \
            proot-distro remove "$NUX_DISTRO" 2>/dev/null
        success "Ubuntu environment removed."
    fi

    # Remove Nux config directory
    if [[ -d "$NUX_DIR" ]]; then
        rm -rf "$NUX_DIR"
        success "Nux configs removed."
    fi

    # Remove Nux install directory
    local nux_install_dir="$PREFIX/share/nux"
    if [[ -d "$nux_install_dir" ]]; then
        rm -rf "$nux_install_dir"
        success "Nux scripts removed."
    fi

    # Remove nux command symlink
    rm -f "$PREFIX/bin/nux" 2>/dev/null
    success "nux command removed."

    echo ""
    echo -e "  ${GREEN}Nux has been completely uninstalled.${RESET}"
    echo -e "  ${DIM}~${total_size}MB of storage has been freed.${RESET}"
    echo -e "  ${DIM}Thanks for using Nux! — @rexroze${RESET}"
    echo ""
}

main "$@"
