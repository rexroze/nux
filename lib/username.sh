#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Custom Username

setup_username() {
    stage 4 9 "Choose your username"
    echo ""
    echo -e "  ${DIM}This will be your Linux desktop username.${RESET}"
    echo -e "  ${DIM}Rules: lowercase letters and numbers only, no spaces.${RESET}"
    echo ""

    local username
    while true; do
        username=$(prompt_text "Username" "nuxdroid")
        # Validate: lowercase, no spaces, no special chars, 1-32 chars
        if [[ "$username" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
            break
        else
            error "Invalid username. Use lowercase letters, numbers, underscores, or hyphens."
            error "Must start with a letter. Max 32 characters."
        fi
    done

    save_profile "USERNAME" "$username"

    # NOTE: the Linux account is created later by install.sh, once the Ubuntu
    # rootfs actually exists. Creating it here would run `proot-distro login`
    # against a distro that isn't installed yet (onboarding is step 4; Ubuntu
    # is installed at step 8) and abort the installer.

    success "Username set: ${username}"
    echo ""
    sleep 1
}
