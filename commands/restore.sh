#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — nux restore
# Restores a full Nux environment from a backup archive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

main() {
    echo ""
    echo -e "  ${CYAN}${BOLD}Nux Restore${RESET}"
    echo ""

    local archive="$1"

    # If no argument, look for backups
    if [[ -z "$archive" ]]; then
        if [[ -d "$NUX_BACKUP_DIR" ]]; then
            local backups
            backups=$(ls -1t "$NUX_BACKUP_DIR"/nux_backup_*.tar.gz 2>/dev/null)
            if [[ -n "$backups" ]]; then
                echo -e "  ${BOLD}Available backups:${RESET}"
                echo ""
                local i=1
                local backup_list=()
                while IFS= read -r f; do
                    local fname fsize
                    fname=$(basename "$f")
                    fsize=$(du -sm "$f" 2>/dev/null | awk '{print $1}')
                    echo -e "    ${CYAN}${i})${RESET} ${fname} ${DIM}(${fsize}MB)${RESET}"
                    backup_list+=("$f")
                    ((i++))
                done <<< "$backups"

                echo ""
                printf "  ${BOLD}Select backup (or enter a file path):${RESET} "
                read -r choice < /dev/tty

                if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#backup_list[@]})); then
                    archive="${backup_list[$((choice-1))]}"
                else
                    archive="$choice"
                fi
            else
                echo -e "  ${DIM}No backups found in ${NUX_BACKUP_DIR}${RESET}"
                echo ""
                printf "  ${BOLD}Enter path to backup archive:${RESET} "
                read -r archive < /dev/tty
            fi
        else
            printf "  ${BOLD}Enter path to backup archive:${RESET} "
            read -r archive < /dev/tty
        fi
    fi

    # Validate archive
    if [[ ! -f "$archive" ]]; then
        die "File not found: ${archive}"
    fi

    if ! file "$archive" | grep -qiE "gzip|tar"; then
        die "Not a valid backup archive: ${archive}"
    fi

    local archive_size
    archive_size=$(du -sm "$archive" 2>/dev/null | awk '{print $1}')
    info "Archive: $(basename "$archive") (${archive_size}MB)"

    # Warn about hardware differences
    echo ""
    warn "If restoring to a different device, GPU drivers may need re-detection."
    echo ""

    if ! prompt_yn "Restore from this backup? This will replace your current installation."; then
        info "Restore cancelled."
        return
    fi

    echo ""

    # Stop running session
    "$SCRIPT_DIR/commands/stop.sh" 2>/dev/null

    # Remove existing proot distro
    if [[ -d "$NUX_PROOT_DIR" ]]; then
        run_with_spinner "Removing current installation" \
            proot-distro remove "$NUX_DISTRO" 2>/dev/null
    fi

    # Extract backup
    info "Extracting backup... (this may take a while)"
    tar xzf "$archive" -C "$(dirname "$NUX_PROOT_DIR")/" 2>/dev/null &
    spinner $! "Restoring environment"

    # Restore profile
    if tar tzf "$archive" 2>/dev/null | grep -q ".nux/"; then
        tar xzf "$archive" -C "$HOME/" ".nux" 2>/dev/null
    fi

    echo ""
    success "Restore complete!"
    echo -e "  ${DIM}Run ${GREEN}nux start${RESET}${DIM} to launch your restored desktop.${RESET}"
    echo ""
}

main "$@"
