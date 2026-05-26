#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — nux update
# Updates Nux scripts and the Ubuntu system packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

main() {
    echo ""
    echo -e "  ${CYAN}${BOLD}Nux Update${RESET}"
    echo ""

    # ── Part 1: Script update ──
    info "Checking for Nux script updates..."

    local latest_version
    latest_version=$(curl -sL --connect-timeout 5 "$NUX_RELEASE_API" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')

    if [[ -n "$latest_version" && "$latest_version" != "$NUX_VERSION" ]]; then
        info "Updating Nux v${NUX_VERSION} → v${latest_version}..."

        local nux_install_dir="$PREFIX/share/nux"
        local temp_dir="$HOME/.nux/update_tmp"
        mkdir -p "$temp_dir"

        # Download latest scripts
        local files=(
            "lib/utils.sh" "lib/banner.sh" "lib/profiler.sh" "lib/gpu.sh"
            "lib/audio.sh" "lib/display.sh" "lib/locale.sh" "lib/apps.sh"
            "lib/de.sh" "lib/username.sh"
            "commands/start.sh" "commands/stop.sh" "commands/apps.sh"
            "commands/backup.sh" "commands/restore.sh" "commands/update.sh"
            "commands/uninstall.sh"
            "assets/xfce4/xfce4-panel.xml"
            "install.sh"
        )

        local download_ok=true
        for f in "${files[@]}"; do
            local dir
            dir=$(dirname "$f")
            mkdir -p "${temp_dir}/${dir}"
            if ! curl -sL "${NUX_REPO}/${f}" -o "${temp_dir}/${f}" 2>/dev/null; then
                download_ok=false
                break
            fi
        done

        if [[ "$download_ok" == true ]]; then
            # Replace scripts (never touches user data)
            cp -rf "$temp_dir"/* "$nux_install_dir/" 2>/dev/null
            chmod +x "$nux_install_dir"/commands/*.sh 2>/dev/null
            chmod +x "$nux_install_dir"/install.sh 2>/dev/null
            success "Nux scripts updated to v${latest_version}."
        else
            warn "Failed to download updates. Skipping script update."
        fi

        rm -rf "$temp_dir"
    else
        success "Nux scripts are up to date (v${NUX_VERSION})."
    fi

    echo ""

    # ── Part 2: System package update ──
    info "Updating Ubuntu system packages..."
    echo ""

    run_in_ubuntu bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq 2>/dev/null
        apt-get upgrade -y 2>/dev/null
    " 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qP '^\w'; then
            printf "\r  ${DIM}%s${RESET}%*s" "$(echo "$line" | head -c 55)" 25 ""
        fi
    done

    echo ""
    success "System packages updated."

    echo ""
    echo -e "  ${GREEN}Update complete.${RESET}"
    echo ""
}

main "$@"
