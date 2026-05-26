#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — ASCII Banner and Branding

show_banner() {
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
    echo -e "   ${DIM}Droid${RESET}            ${MAGENTA}v${NUX_VERSION}${RESET} ${DIM}|${RESET} ${CYAN}@rexroze${RESET}"
    echo ""
    separator
}

show_welcome() {
    clear_screen
    show_banner
    echo ""
    echo -e "  ${BOLD}${WHITE}Welcome to Nux Droid${RESET}"
    echo ""
    echo -e "  ${DIM}A one-command Linux desktop installer for Android.${RESET}"
    echo -e "  ${DIM}You'll get a full Ubuntu desktop with GPU acceleration,${RESET}"
    echo -e "  ${DIM}audio, and apps — no Linux knowledge required.${RESET}"
    echo ""
    separator
    echo ""
    echo -e "  ${DIM}Press Enter to begin setup...${RESET}"
    read -r < /dev/tty
}

show_completion() {
    local de username gpu_driver
    de=$(load_profile "DE")
    username=$(load_profile "USERNAME")
    gpu_driver=$(load_profile "GPU_DRIVER")

    clear_screen
    show_banner
    echo ""
    echo -e "  ${GREEN}${BOLD}✔ Installation Complete!${RESET}"
    echo ""
    separator
    echo ""
    echo -e "  ${BOLD}Summary:${RESET}"
    echo -e "    ${DIM}User:${RESET}     ${WHITE}${username}${RESET}"
    echo -e "    ${DIM}Desktop:${RESET}  ${WHITE}${de}${RESET}"
    echo -e "    ${DIM}GPU:${RESET}      ${WHITE}${gpu_driver}${RESET}"
    echo ""
    separator
    echo ""
    echo -e "  ${BOLD}Getting started:${RESET}"
    echo ""
    echo -e "    ${CYAN}1.${RESET} Open the ${BOLD}Termux-X11${RESET} app on your device"
    echo -e "    ${CYAN}2.${RESET} Come back here and run: ${GREEN}nux start${RESET}"
    echo -e "    ${CYAN}3.${RESET} Switch to Termux-X11 — your desktop is ready"
    echo ""
    echo -e "  ${BOLD}Commands:${RESET}"
    echo ""
    echo -e "    ${GREEN}nux start${RESET}      ${DIM}Launch your desktop${RESET}"
    echo -e "    ${GREEN}nux stop${RESET}       ${DIM}Shut down the desktop${RESET}"
    echo -e "    ${GREEN}nux apps${RESET}       ${DIM}Install more apps${RESET}"
    echo -e "    ${GREEN}nux backup${RESET}     ${DIM}Backup your environment${RESET}"
    echo -e "    ${GREEN}nux --help${RESET}     ${DIM}See all commands${RESET}"
    echo ""
    separator
    echo ""
    echo -e "  ${DIM}First boot may take 30-60 seconds. Enjoy Nux!${RESET}"
    echo ""
}
