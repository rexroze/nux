#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — nux stop
# Cleanly stops all Nux processes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/gpu.sh"
source "$SCRIPT_DIR/lib/audio.sh"

main() {
    echo ""
    echo -e "  ${CYAN}Stopping Nux...${RESET}"
    echo ""

    # Kill proot session
    if [[ -f "$NUX_DIR/proot.pid" ]]; then
        kill "$(cat "$NUX_DIR/proot.pid")" 2>/dev/null
        rm -f "$NUX_DIR/proot.pid"
    fi
    pkill -f "proot-distro" 2>/dev/null
    pkill -f "proot --" 2>/dev/null
    success "Desktop session stopped."

    # Stop X11
    pkill -f "termux-x11" 2>/dev/null
    rm -f /tmp/.X0-lock 2>/dev/null
    rm -rf /tmp/.X11-unix 2>/dev/null
    success "Display server stopped."

    # Stop GPU
    stop_gpu_renderer
    success "GPU renderer stopped."

    # Stop audio
    stop_audio
    success "Audio stopped."

    # Kill any leftover dbus
    pkill -f "dbus-daemon" 2>/dev/null

    echo ""
    echo -e "  ${GREEN}Nux has been shut down.${RESET}"
    echo ""
}

main "$@"
