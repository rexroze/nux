#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — nux start
# Launches proot session, GPU, PulseAudio, X11, and the desktop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/gpu.sh"
source "$SCRIPT_DIR/lib/audio.sh"
source "$SCRIPT_DIR/lib/display.sh"
source "$SCRIPT_DIR/lib/de.sh"

load_all_profile

# ── Version check (non-blocking) ──
check_for_updates() {
    local latest_version
    latest_version=$(curl -sL --connect-timeout 3 "$NUX_RELEASE_API" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')
    if [[ -n "$latest_version" && "$latest_version" != "$NUX_VERSION" ]]; then
        echo -e "  ${CYAN}Nux v${NUX_VERSION} → v${latest_version} available, run ${GREEN}nux update${RESET}"
    fi
}

main() {
    echo ""
    echo -e "  ${CYAN}Starting Nux Droid...${RESET}"
    echo ""

    # Non-blocking update check
    check_for_updates &
    local update_pid=$!

    # Load profile
    local de_session username gpu_tier
    de_session=$(load_profile "DE_SESSION")
    username=$(load_profile "USERNAME")
    gpu_tier=$(load_profile "GPU_TIER")

    de_session="${de_session:-startxfce4}"
    username="${username:-nuxdroid}"
    gpu_tier="${gpu_tier:-3}"

    # 1. Stop any existing session
    "$SCRIPT_DIR/commands/stop.sh" 2>/dev/null

    # 2. Set GPU environment
    info "Setting up GPU driver..."
    [[ -f "$NUX_DIR/gpu_env.sh" ]] && source "$NUX_DIR/gpu_env.sh"
    start_gpu_renderer
    success "GPU renderer started."

    # 3. Start PulseAudio
    info "Starting audio..."
    start_audio
    success "PulseAudio running."

    # 4. Detect display
    get_display_env

    # 5. Kill stale X11 locks
    rm -f /tmp/.X0-lock 2>/dev/null
    rm -rf /tmp/.X11-unix 2>/dev/null

    # 6. Start Termux-X11
    info "Starting Termux-X11 display server..."
    termux-x11 :0 &
    sleep 2
    export DISPLAY=:0
    success "Display server ready."

    # 7. Make sure the desktop has a valid panel layout before launching
    #    (deploys defaults only if missing, so user tweaks survive).
    repair_xfce_desktop ensure

    # 8. Launch proot Ubuntu with DE
    info "Launching ${de_session}..."
    echo ""

    # Build the launch command
    proot-distro login "$NUX_DISTRO" --user "$username" \
        --shared-tmp \
        --bind /dev/null:/proc/stat \
        -- bash -c "
            export DISPLAY=:0
            export PULSE_SERVER=127.0.0.1
            export XDG_RUNTIME_DIR=/tmp/runtime-${username}
            export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session
            mkdir -p /tmp/runtime-${username}

            # Source GPU env if available
            [[ -f '$NUX_DIR/gpu_env.sh' ]] && source '$NUX_DIR/gpu_env.sh'

            # Start dbus
            dbus-daemon --session --address=\$DBUS_SESSION_BUS_ADDRESS --nofork --nopidfile &

            # Launch DE
            ${de_session}
        " &

    local proot_pid=$!
    echo $proot_pid > "$NUX_DIR/proot.pid"

    # Wait for update check to finish
    wait $update_pid 2>/dev/null

    echo ""
    separator
    echo ""
    echo -e "  ${GREEN}${BOLD}Desktop is running!${RESET}"
    echo -e "  ${DIM}Switch to the ${BOLD}Termux-X11${RESET}${DIM} app to see your desktop.${RESET}"
    echo -e "  ${DIM}Run ${GREEN}nux stop${RESET}${DIM} to shut down.${RESET}"
    echo ""

    # Keep running in foreground
    wait $proot_pid 2>/dev/null
}

main "$@"
