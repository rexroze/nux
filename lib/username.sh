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

    # Create user inside Ubuntu proot
    run_in_ubuntu bash -c "
        if ! id '${username}' &>/dev/null; then
            useradd -m -s /bin/bash '${username}' 2>/dev/null
            echo '${username} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers 2>/dev/null

            # Set up basic shell config
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
    " 2>/dev/null

    success "Username set: ${username}"
    echo ""
    sleep 1
}
