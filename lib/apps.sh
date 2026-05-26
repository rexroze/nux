#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — App Selection (Two-Level Picker)

# App registry: "id|name|package|size_mb|category"
declare -a APP_REGISTRY=(
    # Core (always installed)
    "firefox|Firefox|firefox-esr|200|core"
    "thunar|Thunar|thunar|15|core"
    "xterm|Terminal|xfce4-terminal|5|core"

    # Creative
    "gimp|GIMP (Image Editor)|gimp|250|creative"
    "inkscape|Inkscape (Vector Graphics)|inkscape|180|creative"
    "blender|Blender (3D Modeling)|blender|500|creative"

    # Dev Tools
    "vscode|VS Code (code-server)|code-server-placeholder|350|dev"
    "git|Git|git|30|dev"
    "nodejs|Node.js|nodejs npm|80|dev"
    "python|Python 3|python3 python3-pip|120|dev"

    # Office
    "libreoffice|LibreOffice (Full Suite)|libreoffice|600|office"

    # Media
    "vlc|VLC (Media Player)|vlc|120|media"
    "audacity|Audacity (Audio Editor)|audacity|100|media"

    # Utilities
    "htop|htop (System Monitor)|htop|2|utilities"
    "neofetch|neofetch (System Info)|neofetch|1|utilities"
)

# Category metadata: "id|display_name"
declare -a CATEGORIES=(
    "creative|Creative"
    "dev|Dev Tools"
    "office|Office"
    "media|Media"
    "utilities|Utilities"
)

get_apps_by_category() {
    local cat_id="$1"
    for entry in "${APP_REGISTRY[@]}"; do
        local category
        category=$(echo "$entry" | cut -d'|' -f5)
        [[ "$category" == "$cat_id" ]] && echo "$entry"
    done
}

show_app_picker() {
    local is_post_install="${1:-false}"
    local selected_apps=()

    if [[ "$is_post_install" == "false" ]]; then
        stage 6 9 "Select your apps"
    else
        echo ""
        echo -e "  ${BOLD}${WHITE}Nux App Installer${RESET}"
    fi

    echo ""
    echo -e "  ${DIM}Core apps (Firefox, Thunar, Terminal) are always installed.${RESET}"
    echo -e "  ${DIM}Choose optional categories, then pick individual apps.${RESET}"
    echo ""
    separator

    # Step 1: Category selection
    echo ""
    echo -e "  ${BOLD}Select categories to browse:${RESET}"
    echo ""

    local selected_categories=()
    for i in "${!CATEGORIES[@]}"; do
        local cat_id cat_name
        cat_id=$(echo "${CATEGORIES[$i]}" | cut -d'|' -f1)
        cat_name=$(echo "${CATEGORIES[$i]}" | cut -d'|' -f2)

        # Count apps and total size in category
        local app_count=0 cat_size=0
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            ((app_count++))
            cat_size=$((cat_size + $(echo "$entry" | cut -d'|' -f4)))
        done <<< "$(get_apps_by_category "$cat_id")"

        printf "    ${CYAN}%d)${RESET} %-14s ${DIM}%d apps, ~%dMB total${RESET}\n" \
            "$((i+1))" "$cat_name" "$app_count" "$cat_size"
    done

    echo ""
    echo -e "    ${CYAN}0)${RESET} ${DIM}Skip — install only core apps${RESET}"
    echo ""
    echo -e "  ${DIM}Enter numbers separated by spaces (e.g. 1 2 4):${RESET}"
    printf "  ${BOLD}▸${RESET} "
    read -r cat_choices < /dev/tty

    if [[ "$cat_choices" == "0" || -z "$cat_choices" ]]; then
        info "Skipping optional apps. Only core apps will be installed."
        save_profile "SELECTED_APPS" "core"
        echo ""
        return
    fi

    # Step 2: Per-category app selection
    for cat_num in $cat_choices; do
        if ! [[ "$cat_num" =~ ^[0-9]+$ ]] || ((cat_num < 1 || cat_num > ${#CATEGORIES[@]})); then
            continue
        fi

        local cat_entry="${CATEGORIES[$((cat_num-1))]}"
        local cat_id cat_name
        cat_id=$(echo "$cat_entry" | cut -d'|' -f1)
        cat_name=$(echo "$cat_entry" | cut -d'|' -f2)

        echo ""
        separator
        echo ""
        echo -e "  ${BOLD}${cat_name}:${RESET}"
        echo ""

        local cat_apps=()
        local idx=1
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            cat_apps+=("$entry")
            local name size_mb
            name=$(echo "$entry" | cut -d'|' -f2)
            size_mb=$(echo "$entry" | cut -d'|' -f4)
            printf "    ${CYAN}%d)${RESET} %-35s ${DIM}~%dMB${RESET}\n" "$idx" "$name" "$size_mb"
            ((idx++))
        done <<< "$(get_apps_by_category "$cat_id")"

        echo ""
        echo -e "    ${CYAN}a)${RESET} ${DIM}All${RESET}    ${CYAN}0)${RESET} ${DIM}None${RESET}"
        echo ""
        echo -e "  ${DIM}Enter numbers separated by spaces, 'a' for all, or 0 to skip:${RESET}"
        printf "  ${BOLD}▸${RESET} "
        read -r app_choices < /dev/tty

        if [[ "$app_choices" == "0" ]]; then
            continue
        elif [[ "$app_choices" == "a" || "$app_choices" == "A" ]]; then
            for entry in "${cat_apps[@]}"; do
                selected_apps+=("$(echo "$entry" | cut -d'|' -f1)")
            done
        else
            for app_num in $app_choices; do
                if [[ "$app_num" =~ ^[0-9]+$ ]] && ((app_num >= 1 && app_num <= ${#cat_apps[@]})); then
                    selected_apps+=("$(echo "${cat_apps[$((app_num-1))]}" | cut -d'|' -f1)")
                fi
            done
        fi
    done

    # Save selections
    if [[ ${#selected_apps[@]} -gt 0 ]]; then
        local app_list
        app_list=$(IFS=','; echo "${selected_apps[*]}")
        save_profile "SELECTED_APPS" "core,${app_list}"
    else
        save_profile "SELECTED_APPS" "core"
    fi

    echo ""
    success "Selected ${#selected_apps[@]} optional app(s)."
    echo ""
    sleep 1
}

show_confirmation() {
    local selected de username gpu_driver storage_mb total_size=0

    selected=$(load_profile "SELECTED_APPS")
    de=$(load_profile "DE")
    username=$(load_profile "USERNAME")
    gpu_driver=$(load_profile "GPU_DRIVER")
    storage_mb=$(load_profile "STORAGE_MB")

    stage 7 9 "Review your selections"
    echo ""
    echo -e "  ${BOLD}Configuration Summary${RESET}"
    echo ""
    echo -e "    ${DIM}Username:${RESET}  ${WHITE}${username}${RESET}"
    echo -e "    ${DIM}Desktop:${RESET}   ${WHITE}${de}${RESET}"
    echo -e "    ${DIM}GPU:${RESET}       ${WHITE}${gpu_driver}${RESET}"
    echo ""

    # Calculate total install size
    local base_size=2048  # ~2GB for Ubuntu base
    total_size=$base_size

    echo -e "  ${BOLD}Apps to install:${RESET}"
    echo ""

    # Always show core
    echo -e "    ${GREEN}✔${RESET} Firefox, Thunar, Terminal ${DIM}(core)${RESET}"

    # Show selected optional apps
    IFS=',' read -ra app_ids <<< "$selected"
    for app_id in "${app_ids[@]}"; do
        [[ "$app_id" == "core" ]] && continue
        for entry in "${APP_REGISTRY[@]}"; do
            local eid ename esize
            eid=$(echo "$entry" | cut -d'|' -f1)
            ename=$(echo "$entry" | cut -d'|' -f2)
            esize=$(echo "$entry" | cut -d'|' -f4)
            if [[ "$eid" == "$app_id" ]]; then
                echo -e "    ${GREEN}✔${RESET} ${ename} ${DIM}(~${esize}MB)${RESET}"
                total_size=$((total_size + esize))
            fi
        done
    done

    echo ""
    separator
    echo ""
    echo -e "  ${BOLD}Estimated total size:${RESET} ${WHITE}~$((total_size / 1024))GB${RESET} ${DIM}(${total_size}MB)${RESET}"
    echo -e "  ${DIM}Available storage: ${storage_mb}MB${RESET}"
    echo ""

    if ((total_size > storage_mb)); then
        warn "Install size may exceed available storage!"
    fi

    if ! prompt_yn "Proceed with installation?"; then
        die "Installation cancelled."
    fi

    echo ""
}

install_core_apps() {
    run_logged "Installing Firefox" run_in_ubuntu bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends firefox-esr
    "
    success "Firefox installed."
}

install_selected_apps() {
    local selected
    selected=$(load_profile "SELECTED_APPS")
    IFS=',' read -ra app_ids <<< "$selected"

    for app_id in "${app_ids[@]}"; do
        [[ "$app_id" == "core" ]] && continue

        for entry in "${APP_REGISTRY[@]}"; do
            local eid ename epkg ecat
            eid=$(echo "$entry" | cut -d'|' -f1)
            ename=$(echo "$entry" | cut -d'|' -f2)
            epkg=$(echo "$entry" | cut -d'|' -f3)
            ecat=$(echo "$entry" | cut -d'|' -f5)

            if [[ "$eid" == "$app_id" ]]; then
                # Optional apps are non-fatal: a single failure warns and moves on.
                if [[ "$eid" == "vscode" ]]; then
                    # Special handling for code-server
                    info "Installing VS Code (code-server)..."
                    { echo ""; echo "\$ install code-server"; } >> "$NUX_LOG"
                    if run_in_ubuntu bash -c "
                        export DEBIAN_FRONTEND=noninteractive
                        apt-get install -y curl
                        curl -fsSL https://code-server.dev/install.sh | sh
                    " >> "$NUX_LOG" 2>&1; then
                        success "${ename} installed."
                    else
                        warn "${ename} failed to install — skipping. See $NUX_LOG."
                    fi
                else
                    if run_with_spinner "Installing ${ename}" \
                        run_in_ubuntu bash -c \
                        "export DEBIAN_FRONTEND=noninteractive; apt-get install -y --no-install-recommends ${epkg}"; then
                        success "${ename} installed."
                    else
                        warn "${ename} failed to install — skipping. See $NUX_LOG."
                    fi
                fi
            fi
        done
    done
}
