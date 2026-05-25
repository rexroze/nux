#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — nux apps
# Reopens the app picker to install additional apps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/apps.sh"

main() {
    clear_screen

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

    show_app_picker "true"
    install_selected_apps

    echo ""
    success "All selected apps have been installed."
    echo -e "  ${DIM}Restart your desktop with ${GREEN}nux stop && nux start${RESET}${DIM} to see changes.${RESET}"
    echo ""
}

main "$@"
