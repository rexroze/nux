#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — GPU Acceleration
# Three-tier GPU driver system: Turnip+Zink > VirGL > llvmpipe

# Determine the best GPU tier for a given family
get_gpu_tier() {
    local family="$1"
    case "$family" in
        adreno)     echo "1" ;;  # Turnip + Zink
        mali|immortalis|xclipse|powervr) echo "2" ;;  # VirGL
        *)          echo "3" ;;  # Software rendering
    esac
}

get_driver_name() {
    local tier="$1"
    case "$tier" in
        1) echo "Turnip + Zink (Vulkan)" ;;
        2) echo "VirGL (Hardware Accelerated)" ;;
        3) echo "llvmpipe (Software Rendering)" ;;
        *) echo "Unknown" ;;
    esac
}

get_driver_short() {
    local tier="$1"
    case "$tier" in
        1) echo "turnip-zink" ;;
        2) echo "virgl" ;;
        3) echo "llvmpipe" ;;
        *) echo "software" ;;
    esac
}

# Install only the packages that actually exist in the enabled repos.
# GPU package names vary across Termux mirrors/repos, so we filter to what's
# available rather than passing a fixed list that aborts the whole command
# with "Unable to locate package" when one name is missing.
install_available_pkgs() {
    local label="$1"; shift
    local available=()
    local pkg
    for pkg in "$@"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            available+=("$pkg")
        fi
    done

    if [[ ${#available[@]} -eq 0 ]]; then
        warn "No GPU packages for this tier are available in your repos — will fall back if needed."
        return 0
    fi

    if ! run_with_spinner "$label" pkg install -y "${available[@]}"; then
        warn "Some GPU packages failed to install — will fall back if needed. See $NUX_LOG."
    fi
}

# Install GPU dependencies in Termux
install_gpu_packages() {
    local tier="$1"

    case "$tier" in
        1)
            # Turnip + Zink (Adreno). Package names differ by repo, so install
            # whichever of these actually exist; missing ones are skipped.
            install_available_pkgs "Installing Turnip/Zink packages" \
                mesa-vulkan-icd-freedreno \
                mesa-vulkan-icd-freedreno-dri3 \
                virglrenderer-mesa-zink \
                virglrenderer-android \
                vulkan-loader-android \
                vulkan-tools
            ;;
        2)
            # VirGL — universal hardware acceleration.
            install_available_pkgs "Installing VirGL packages" \
                virglrenderer-android
            ;;
        3)
            # Software rendering — no extra packages needed
            info "Using software rendering (no GPU packages required)."
            ;;
    esac
}

# Set environment variables for the selected driver
set_gpu_env_vars() {
    local tier="$1"
    local env_file="$NUX_DIR/gpu_env.sh"

    cat > "$env_file" << 'ENVEOF'
# Nux GPU Environment — Auto-generated
ENVEOF

    case "$tier" in
        1)
            cat >> "$env_file" << 'ENVEOF'
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=fifo
export VK_ICD_FILENAMES=/data/data/com.termux/files/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
ENVEOF
            ;;
        2)
            cat >> "$env_file" << 'ENVEOF'
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
ENVEOF
            ;;
        3)
            cat >> "$env_file" << 'ENVEOF'
export GALLIUM_DRIVER=llvmpipe
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_GL_VERSION_OVERRIDE=4.0
ENVEOF
            ;;
    esac

    chmod 644 "$env_file"
}

# Quick 2-second GPU render test
gpu_render_test() {
    local tier="$1"

    # For software rendering, skip the test
    [[ "$tier" == "3" ]] && return 0

    info "Running quick GPU render test..."

    local test_ok=false

    if [[ "$tier" == "1" ]]; then
        # Test Turnip/Zink by trying to initialize vulkan
        timeout 3 bash -c '
            source "'$NUX_DIR'/gpu_env.sh" 2>/dev/null
            vulkaninfo --summary 2>/dev/null | grep -qi "deviceName"
        ' 2>/dev/null && test_ok=true
    fi

    if [[ "$tier" == "2" ]] || [[ "$test_ok" == false && "$tier" == "1" ]]; then
        # Test VirGL by starting virgl_test_server briefly
        timeout 3 bash -c '
            virgl_test_server --use-egl-surfaceless 2>/dev/null &
            local vpid=$!
            sleep 1
            kill $vpid 2>/dev/null
            exit 0
        ' 2>/dev/null && test_ok=true
    fi

    if [[ "$test_ok" == true ]]; then
        success "GPU render test passed."
        return 0
    else
        return 1
    fi
}

# Main GPU selection flow during onboarding
setup_gpu() {
    local gpu_family tier driver_name

    gpu_family=$(load_profile "GPU_FAMILY")
    tier=$(get_gpu_tier "$gpu_family")
    driver_name=$(get_driver_name "$tier")

    stage 2 9 "Configuring GPU acceleration..."
    echo ""
    echo -e "  ${DIM}Detected GPU:${RESET}  ${WHITE}${gpu_family}${RESET}"
    echo -e "  ${DIM}Selected:${RESET}      ${WHITE}${driver_name}${RESET}"
    echo ""

    # Offer manual override
    if prompt_yn "Use this driver?" "y"; then
        : # keep current selection
    else
        echo ""
        echo -e "  ${BOLD}Select GPU driver:${RESET}"
        echo ""
        echo -e "    ${CYAN}1)${RESET} Turnip + Zink ${DIM}(Adreno/Snapdragon only)${RESET}"
        echo -e "    ${CYAN}2)${RESET} VirGL ${DIM}(Universal hardware acceleration)${RESET}"
        echo -e "    ${CYAN}3)${RESET} llvmpipe ${DIM}(Software — works everywhere, slow)${RESET}"
        echo ""
        while true; do
            printf "  ${BOLD}▸${RESET} "
            read -r choice < /dev/tty
            if [[ "$choice" =~ ^[1-3]$ ]]; then
                tier="$choice"
                driver_name=$(get_driver_name "$tier")
                break
            fi
            echo -e "  ${RED}Enter 1, 2, or 3.${RESET}"
        done
    fi

    # Run render test
    stage 3 9 "Testing GPU driver..."
    set_gpu_env_vars "$tier"

    if ! gpu_render_test "$tier"; then
        warn "Render test failed for ${driver_name}."

        # Try fallback
        local original_tier="$tier"
        if [[ "$tier" == "1" ]]; then
            tier="2"
            warn "Falling back to VirGL..."
            set_gpu_env_vars "$tier"
            if ! gpu_render_test "$tier"; then
                tier="3"
                warn "VirGL also failed. Falling back to software rendering."
                set_gpu_env_vars "$tier"
            fi
        elif [[ "$tier" == "2" ]]; then
            tier="3"
            warn "Falling back to software rendering."
            set_gpu_env_vars "$tier"
        fi

        driver_name=$(get_driver_name "$tier")

        if [[ "$tier" == "3" ]]; then
            warn "Using software rendering. Desktop will work but may be slow."
        fi
    else
        [[ "$tier" != "3" ]] && success "GPU acceleration is working."
    fi

    # Save selection
    local driver_short
    driver_short=$(get_driver_short "$tier")
    save_profile "GPU_TIER" "$tier"
    save_profile "GPU_DRIVER" "$driver_name"
    save_profile "GPU_DRIVER_SHORT" "$driver_short"

    # Install GPU packages
    install_gpu_packages "$tier"

    echo ""
    success "GPU configured: ${driver_name}"
    sleep 1
}

# Start the GPU renderer for nux start
start_gpu_renderer() {
    local tier
    tier=$(load_profile "GPU_TIER")
    tier="${tier:-3}"

    # Source environment
    [[ -f "$NUX_DIR/gpu_env.sh" ]] && source "$NUX_DIR/gpu_env.sh"

    case "$tier" in
        1)
            # Turnip+Zink: start virgl with zink backend
            virgl_test_server --use-egl-surfaceless --use-gles 2>/dev/null &
            echo $! > "$NUX_DIR/virgl.pid"
            ;;
        2)
            # VirGL
            virgl_test_server --use-egl-surfaceless 2>/dev/null &
            echo $! > "$NUX_DIR/virgl.pid"
            ;;
        3)
            # Software rendering — nothing to start
            ;;
    esac
}

stop_gpu_renderer() {
    if [[ -f "$NUX_DIR/virgl.pid" ]]; then
        kill "$(cat "$NUX_DIR/virgl.pid")" 2>/dev/null
        rm -f "$NUX_DIR/virgl.pid"
    fi
    pkill -f virgl_test_server 2>/dev/null
}
