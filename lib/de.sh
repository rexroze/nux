#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Desktop Environment Installer

setup_desktop_environment() {
    local ram_mb de_choice de_pkg de_session de_name
    ram_mb=$(load_profile "RAM_MB")
    ram_mb="${ram_mb:-4096}"

    stage 5 9 "Choose your desktop environment"
    echo ""

    # RAM-based recommendations
    if ((ram_mb < 4000)); then
        warn "Your device has less than 4GB RAM."
        echo -e "  ${DIM}XFCE or LXDE recommended for best performance.${RESET}"
        echo ""
    fi

    echo -e "    ${CYAN}1)${RESET} ${BOLD}XFCE4${RESET}       ${DIM}Lightweight, best performance (recommended)${RESET}"
    echo -e "    ${CYAN}2)${RESET} ${BOLD}KDE Plasma${RESET}   ${DIM}Feature-rich, heavier${RESET}"
    echo -e "    ${CYAN}3)${RESET} ${BOLD}LXDE${RESET}         ${DIM}Ultra-lightweight${RESET}"
    echo -e "    ${CYAN}4)${RESET} ${BOLD}MATE${RESET}         ${DIM}Traditional desktop feel${RESET}"
    echo ""

    if ((ram_mb < 4000)); then
        echo -e "  ${YELLOW}⚠ KDE may be slow on your device.${RESET}"
        echo ""
    fi

    while true; do
        printf "  ${BOLD}▸${RESET} "
        read -r de_choice
        de_choice="${de_choice:-1}"
        case "$de_choice" in
            1) de_name="XFCE4";      de_pkg="xfce4 xfce4-goodies xfce4-terminal";  de_session="startxfce4"; break ;;
            2) de_name="KDE Plasma";  de_pkg="kde-plasma-desktop";                   de_session="startplasma-x11"; break ;;
            3) de_name="LXDE";        de_pkg="lxde";                                 de_session="startlxde"; break ;;
            4) de_name="MATE";        de_pkg="mate-desktop-environment-core";        de_session="mate-session"; break ;;
            *) echo -e "  ${RED}Enter 1-4.${RESET}" ;;
        esac
    done

    save_profile "DE" "$de_name"
    save_profile "DE_PKG" "$de_pkg"
    save_profile "DE_SESSION" "$de_session"

    success "Selected: ${de_name}"
    echo ""
    sleep 1
}

install_desktop_environment() {
    local de_name de_pkg rc
    de_name=$(load_profile "DE")
    de_pkg=$(load_profile "DE_PKG")

    info "Installing ${de_name}... This may take several minutes."
    echo ""

    { echo ""; echo "\$ apt-get install ${de_pkg} dbus-x11"; } >> "$NUX_LOG"
    set +e
    run_in_ubuntu bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y --no-install-recommends ${de_pkg} dbus-x11
    " 2>&1 | tee -a "$NUX_LOG" | while IFS= read -r line; do
        # Parse apt progress and show a simplified output
        if echo "$line" | grep -qP '^\w'; then
            printf "\r  ${DIM}%s${RESET}%*s" "$(echo "$line" | head -c 60)" 20 ""
        fi
    done
    rc=${PIPESTATUS[0]}
    set -e
    [[ "$rc" -eq 0 ]] || report_failure "Installing ${de_name} desktop"

    echo ""
    success "${de_name} installed."
}
