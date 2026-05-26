#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Audio (PulseAudio)

install_audio() {
    if ! run_with_spinner "Installing PulseAudio" pkg install -y pulseaudio; then
        warn "PulseAudio failed to install — audio may not work. See $NUX_LOG."
    fi
}

configure_audio() {
    # Create a minimal PulseAudio config for proot passthrough
    local pa_conf="$NUX_DIR/pulse_config"
    mkdir -p "$pa_conf"

    cat > "$pa_conf/default.pa" << 'EOF'
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
load-module module-sles-sink
load-module module-null-sink sink_name=nux_null
.ifexists module-native-protocol-unix.so
load-module module-native-protocol-unix
.endif
EOF

    cat > "$pa_conf/daemon.conf" << 'EOF'
exit-idle-time = -1
flat-volumes = yes
daemonize = yes
EOF
}

start_audio() {
    # Kill any existing PulseAudio
    pulseaudio --kill 2>/dev/null
    sleep 0.5

    local pa_conf="$NUX_DIR/pulse_config"
    if [[ -d "$pa_conf" ]]; then
        pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>/dev/null
    else
        pulseaudio --start 2>/dev/null
    fi

    # Export for proot environment
    export PULSE_SERVER=127.0.0.1
}

stop_audio() {
    pulseaudio --kill 2>/dev/null
}

setup_audio() {
    install_audio
    configure_audio
    save_profile "AUDIO" "pulseaudio"
    success "Audio configured."
}
