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
    # The loop's last `[[..]] && echo` returns 1 when the final registry entry
    # doesn't match $cat_id, which would trip the install's `set -e` ERR trap at
    # every call site. This is a query helper — a no-match is not an error.
    return 0
}

# Browse-loop app picker: enter a category to toggle apps, return to the
# category list, repeat across as many categories as you like, then finish with
# 'd'. Selections persist across categories so nothing is lost when you go back.
show_app_picker() {
    local is_post_install="${1:-false}"

    if [[ "$is_post_install" == "false" ]]; then
        stage 6 9 "Select your apps"
    else
        echo ""
        echo -e "  ${BOLD}${WHITE}Nux App Installer${RESET}"
    fi

    echo ""
    echo -e "  ${DIM}Core apps (Firefox, Thunar, Terminal) are always installed.${RESET}"
    echo -e "  ${DIM}Open a category, toggle apps, then come back for more.${RESET}"

    # Selected app ids kept as a space-padded set (" id1 id2 ") — easy to test
    # membership and toggle, and safe under `set -e` (no bare ((x++))).
    local selected=" "

    # In post-install mode, pre-select whatever was chosen before so reopening
    # `nux apps` shows prior picks and you only add to them.
    if [[ "$is_post_install" == "true" ]]; then
        local prev pid
        prev=$(load_profile "SELECTED_APPS")
        IFS=',' read -ra prev_ids <<< "$prev"
        for pid in "${prev_ids[@]}"; do
            [[ -z "$pid" || "$pid" == "core" ]] && continue
            [[ "$selected" == *" $pid "* ]] || selected+="$pid "
        done
    fi

    while true; do
        echo ""
        separator
        echo ""
        echo -e "  ${BOLD}Categories:${RESET} ${DIM}(enter a number to browse)${RESET}"
        echo ""

        local i
        for i in "${!CATEGORIES[@]}"; do
            local cat_id cat_name app_count sel_count entry eid
            cat_id=$(echo "${CATEGORIES[$i]}" | cut -d'|' -f1)
            cat_name=$(echo "${CATEGORIES[$i]}" | cut -d'|' -f2)
            app_count=0; sel_count=0
            while IFS= read -r entry; do
                [[ -z "$entry" ]] && continue
                app_count=$((app_count + 1))
                eid=$(echo "$entry" | cut -d'|' -f1)
                # Use `if` (returns 0 when false) not `[[..]] &&` — the latter as
                # a loop's last statement makes the while return 1 and trips the
                # install's ERR trap under `set -e`.
                if [[ "$selected" == *" $eid "* ]]; then sel_count=$((sel_count + 1)); fi
            done <<< "$(get_apps_by_category "$cat_id")"

            if ((sel_count > 0)); then
                printf "    ${CYAN}%d)${RESET} %-14s ${GREEN}%d selected${RESET} ${DIM}of %d${RESET}\n" \
                    "$((i+1))" "$cat_name" "$sel_count" "$app_count"
            else
                printf "    ${CYAN}%d)${RESET} %-14s ${DIM}%d apps${RESET}\n" \
                    "$((i+1))" "$cat_name" "$app_count"
            fi
        done

        echo ""
        local total_sel; total_sel=$(echo "$selected" | wc -w)
        if ((total_sel > 0)); then
            echo -e "  ${GREEN}✔ ${total_sel} app(s) selected.${RESET}"
            echo ""
        fi
        echo -e "    ${CYAN}d)${RESET} ${BOLD}Done${RESET} ${DIM}— finish and install${RESET}"
        echo -e "    ${CYAN}0)${RESET} ${DIM}Skip all (core apps only)${RESET}"
        echo ""
        printf "  ${BOLD}▸${RESET} "
        local choice; read -r choice < /dev/tty

        case "$choice" in
            d|D) break ;;
            0)   selected=" "; break ;;
            *)
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#CATEGORIES[@]})); then
                    echo -e "  ${RED}Enter a category number, 'd' to finish, or 0 to skip.${RESET}"
                    continue
                fi
                _pick_category_apps "$((choice-1))"
                ;;
        esac
    done

    # Persist: turn the " id1 id2 " set into "core,id1,id2".
    local app_list
    app_list=$(echo "$selected" | tr -s ' ' ' ' | sed 's/^ //; s/ $//' | tr ' ' ',')
    if [[ -n "$app_list" ]]; then
        save_profile "SELECTED_APPS" "core,${app_list}"
        echo ""
        success "Selected $(echo "$selected" | wc -w) optional app(s)."
    else
        save_profile "SELECTED_APPS" "core"
        echo ""
        info "Only core apps will be installed."
    fi
    echo ""
    sleep 1
}

# Helper for show_app_picker: list one category's apps and toggle them. Reads
# and writes the caller's `selected` set (a name-ref keeps the set string in
# sync across calls). $1 is the zero-based category index.
_pick_category_apps() {
    local cat_index="$1"
    local -n sel_ref="selected"   # operate on show_app_picker's $selected

    local cat_entry cat_id cat_name
    cat_entry="${CATEGORIES[$cat_index]}"
    cat_id=$(echo "$cat_entry" | cut -d'|' -f1)
    cat_name=$(echo "$cat_entry" | cut -d'|' -f2)

    while true; do
        local cat_apps=() idx=1 entry
        echo ""
        echo -e "  ${BOLD}${cat_name}${RESET} ${DIM}(✔ = selected; enter numbers to toggle)${RESET}"
        echo ""
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            cat_apps+=("$entry")
            local name size_mb eid mark
            eid=$(echo "$entry" | cut -d'|' -f1)
            name=$(echo "$entry" | cut -d'|' -f2)
            size_mb=$(echo "$entry" | cut -d'|' -f4)
            if [[ "$sel_ref" == *" $eid "* ]]; then mark="${GREEN}✔${RESET}"; else mark=" "; fi
            printf "    ${CYAN}%d)${RESET} %b %-33s ${DIM}~%dMB${RESET}\n" "$idx" "$mark" "$name" "$size_mb"
            idx=$((idx + 1))
        done <<< "$(get_apps_by_category "$cat_id")"

        echo ""
        echo -e "    ${CYAN}a)${RESET} ${DIM}Select all${RESET}    ${CYAN}n)${RESET} ${DIM}Clear all${RESET}    ${CYAN}b)${RESET} ${DIM}Back to categories${RESET}"
        echo ""
        echo -e "  ${DIM}Toggle with numbers (e.g. 1 3), or a / n / b:${RESET}"
        printf "  ${BOLD}▸${RESET} "
        local app_choices; read -r app_choices < /dev/tty

        case "$app_choices" in
            b|B|"") return ;;
            a|A)
                for entry in "${cat_apps[@]}"; do
                    local eid; eid=$(echo "$entry" | cut -d'|' -f1)
                    [[ "$sel_ref" == *" $eid "* ]] || sel_ref+="$eid "
                done ;;
            n|N)
                for entry in "${cat_apps[@]}"; do
                    local eid; eid=$(echo "$entry" | cut -d'|' -f1)
                    sel_ref="${sel_ref// $eid / }"
                done ;;
            *)
                local app_num
                for app_num in $app_choices; do
                    if [[ "$app_num" =~ ^[0-9]+$ ]] && ((app_num >= 1 && app_num <= ${#cat_apps[@]})); then
                        local eid; eid=$(echo "${cat_apps[$((app_num-1))]}" | cut -d'|' -f1)
                        if [[ "$sel_ref" == *" $eid "* ]]; then
                            sel_ref="${sel_ref// $eid / }"   # toggle off
                        else
                            sel_ref+="$eid "                  # toggle on
                        fi
                    fi
                done ;;
        esac
    done
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
    # Modern Ubuntu ships Firefox only as a snap; the firefox-esr/firefox debs
    # are unavailable (or snap stubs) and snapd doesn't run in proot, hence
    # "Package 'firefox-esr' has no installation candidate". Pull a real .deb
    # from the Mozilla Team PPA, pinned above the snap transitional package.
    # A browser failure is non-fatal — the desktop is already installed, so we
    # warn and continue rather than aborting the whole setup.
    info "Setting up Firefox (Mozilla Team PPA)..."
    if run_with_spinner "Installing Firefox" run_in_ubuntu bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends software-properties-common
        add-apt-repository -y ppa:mozillateam/ppa
        printf "Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n" \
            > /etc/apt/preferences.d/mozilla-firefox
        apt-get update
        apt-get install -y --no-install-recommends firefox-esr \
            || apt-get install -y --no-install-recommends firefox
    '; then
        success "Firefox installed."
    else
        warn "Firefox failed to install — skipping. The desktop is ready; you can"
        warn "retry later with 'nux apps'. See $NUX_LOG for the apt error."
    fi
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
                    # Special handling for code-server (installed via its script)
                    if run_with_spinner "Installing ${ename}" run_in_ubuntu bash -c "
                        export DEBIAN_FRONTEND=noninteractive
                        apt-get install -y curl
                        curl -fsSL https://code-server.dev/install.sh | sh
                    "; then
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
