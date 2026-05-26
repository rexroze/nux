#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Display Auto-Detection

detect_display() {
    local resolution density width height dpi

    # Get display size from Android
    # Trailing `|| true`: when neither pattern matches, the `$( )` would exit
    # non-zero and the assignment would trip `set -e`. The `[[ -z ]]` below
    # already supplies a default for the empty case.
    resolution=$(wm size 2>/dev/null | grep -oP 'Override size: \K.*' || wm size 2>/dev/null | grep -oP 'Physical size: \K.*' || true)
    if [[ -z "$resolution" ]]; then
        resolution="1920x1080"
        warn "Could not detect display resolution. Using default: ${resolution}"
    fi

    width=$(echo "$resolution" | cut -d'x' -f1)
    height=$(echo "$resolution" | cut -d'x' -f2)

    # Get display density
    density=$(wm density 2>/dev/null | grep -oP 'Override density: \K.*' || wm density 2>/dev/null | grep -oP 'Physical density: \K.*' || true)
    dpi="${density:-160}"

    save_profile "DISPLAY_WIDTH" "$width"
    save_profile "DISPLAY_HEIGHT" "$height"
    save_profile "DISPLAY_DPI" "$dpi"
    save_profile "DISPLAY_RESOLUTION" "${width}x${height}"

    success "Display: ${width}x${height} @ ${dpi}dpi"
}

get_display_env() {
    local width height
    width=$(load_profile "DISPLAY_WIDTH")
    height=$(load_profile "DISPLAY_HEIGHT")
    width="${width:-1920}"
    height="${height:-1080}"

    export DISPLAY=:0
    export PULSE_SERVER=127.0.0.1
}
