#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Device Profiler
# Detects GPU family, RAM, storage, and Android version

detect_gpu_family() {
    local gpu_info=""
    local gpu_family="unknown"

    # Try getprop first (most reliable)
    gpu_info=$(getprop ro.hardware 2>/dev/null)
    local board=$(getprop ro.board.platform 2>/dev/null)
    local soc=$(getprop ro.hardware.chipname 2>/dev/null)
    local renderer=$(getprop ro.hardware.egl 2>/dev/null)

    # Check /proc/cpuinfo as fallback
    local cpuinfo=""
    [[ -f /proc/cpuinfo ]] && cpuinfo=$(cat /proc/cpuinfo 2>/dev/null)

    # Adreno detection (Snapdragon)
    if echo "$gpu_info $board $soc $renderer $cpuinfo" | grep -qiE "qcom|qualcomm|snapdragon|adreno|msm|sdm|sm[0-9]|kona|lahaina|taro|kalama|pineapple"; then
        gpu_family="adreno"
    # Mali detection (MediaTek / Exynos / Tensor)
    elif echo "$gpu_info $board $soc $renderer $cpuinfo" | grep -qiE "mali|bifrost|valhall|mt[0-9]|mediatek|dimensity|exynos|universal|tensor|gs[0-9]"; then
        # Sub-detect: Xclipse (Samsung's custom Mali derivative)
        if echo "$gpu_info $board $soc $renderer" | grep -qiE "xclipse|s5e"; then
            gpu_family="xclipse"
        # Sub-detect: Immortalis (high-end Mali)
        elif echo "$renderer" | grep -qiE "immortalis"; then
            gpu_family="immortalis"
        else
            gpu_family="mali"
        fi
    # PowerVR detection (older MediaTek)
    elif echo "$gpu_info $board $soc $renderer $cpuinfo" | grep -qiE "powervr|img|rogue"; then
        gpu_family="powervr"
    fi

    echo "$gpu_family"
}

detect_ram_mb() {
    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [[ -n "$mem_kb" ]]; then
        echo $((mem_kb / 1024))
    else
        echo "0"
    fi
}

detect_storage_mb() {
    # `|| echo 0`: if df fails, `pipefail` would make this exit non-zero and trip
    # the caller's `set -e`; always emit a numeric value instead.
    df "$PREFIX" 2>/dev/null | awk 'NR==2{print int($4/1024)}' || echo 0
}

detect_android_version() {
    getprop ro.build.version.release 2>/dev/null || echo "unknown"
}

detect_device_model() {
    local manufacturer brand model
    manufacturer=$(getprop ro.product.manufacturer 2>/dev/null)
    brand=$(getprop ro.product.brand 2>/dev/null)
    model=$(getprop ro.product.model 2>/dev/null)
    echo "${brand:-$manufacturer} ${model}" | sed 's/^ //'
}

detect_arch() {
    uname -m 2>/dev/null || echo "unknown"
}

# Run full device profile and save results
run_device_profiling() {
    stage 1 9 "Scanning your device..."

    local gpu_family ram_mb storage_mb android_ver device_model arch

    gpu_family=$(detect_gpu_family) &
    local pid_gpu=$!

    ram_mb=$(detect_ram_mb)
    storage_mb=$(detect_storage_mb)
    android_ver=$(detect_android_version)
    device_model=$(detect_device_model)
    arch=$(detect_arch)

    wait $pid_gpu 2>/dev/null
    gpu_family=$(detect_gpu_family)

    # Save to profile
    save_profile "GPU_FAMILY" "$gpu_family"
    save_profile "RAM_MB" "$ram_mb"
    save_profile "STORAGE_MB" "$storage_mb"
    save_profile "ANDROID_VERSION" "$android_ver"
    save_profile "DEVICE_MODEL" "$device_model"
    save_profile "ARCH" "$arch"

    # Display results
    echo ""
    echo -e "  ${BOLD}Device Profile${RESET}"
    echo ""
    echo -e "    ${DIM}Device:${RESET}   ${WHITE}${device_model}${RESET}"
    echo -e "    ${DIM}Android:${RESET}  ${WHITE}${android_ver}${RESET}"
    echo -e "    ${DIM}Arch:${RESET}     ${WHITE}${arch}${RESET}"
    echo -e "    ${DIM}GPU:${RESET}      ${WHITE}${gpu_family}${RESET}"
    echo -e "    ${DIM}RAM:${RESET}      ${WHITE}$((ram_mb / 1024))GB${RESET} ${DIM}(${ram_mb}MB)${RESET}"
    echo -e "    ${DIM}Storage:${RESET}  ${WHITE}${storage_mb}MB available${RESET}"
    echo ""

    # Warnings
    if ((ram_mb < 3000)); then
        warn "Low RAM detected. Lighter desktop environments recommended."
    fi
    if ((storage_mb < 4000)); then
        warn "Low storage. Consider freeing space before installing many apps."
    fi
    if [[ "$gpu_family" == "unknown" ]]; then
        warn "GPU not identified. Software rendering will be used."
    fi

    success "Device scan complete."
    echo ""
    sleep 1
}
