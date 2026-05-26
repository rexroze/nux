#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Desktop Environment Installer

setup_desktop_environment() {
    local ram_mb de_choice de_pkg de_session de_name
    ram_mb=$(load_profile "RAM_MB")
    ram_mb="${ram_mb:-4096}"

    stage 5 9 "Choose your desktop environment"
    echo ""

    # RAM-based recommendations
    if ((ram_mb < 4000)); then
        warn "Your device has less than 4GB RAM."
        echo -e "  ${DIM}XFCE or LXDE recommended for best performance.${RESET}"
        echo ""
    fi

    echo -e "    ${CYAN}1)${RESET} ${BOLD}XFCE4${RESET}       ${DIM}Lightweight, best performance (recommended)${RESET}"
    echo -e "    ${CYAN}2)${RESET} ${BOLD}KDE Plasma${RESET}   ${DIM}Feature-rich, heavier${RESET}"
    echo -e "    ${CYAN}3)${RESET} ${BOLD}LXDE${RESET}         ${DIM}Ultra-lightweight${RESET}"
    echo -e "    ${CYAN}4)${RESET} ${BOLD}MATE${RESET}         ${DIM}Traditional desktop feel${RESET}"
    echo ""

    if ((ram_mb < 4000)); then
        echo -e "  ${YELLOW}⚠ KDE may be slow on your device.${RESET}"
        echo ""
    fi

    while true; do
        printf "  ${BOLD}▸${RESET} "
        read -r de_choice < /dev/tty
        de_choice="${de_choice:-1}"
        case "$de_choice" in
            1) de_name="XFCE4";      de_pkg="xfce4 xfce4-goodies xfce4-terminal";  de_session="startxfce4"; break ;;
            2) de_name="KDE Plasma";  de_pkg="kde-plasma-desktop";                   de_session="startplasma-x11"; break ;;
            3) de_name="LXDE";        de_pkg="lxde";                                 de_session="startlxde"; break ;;
            4) de_name="MATE";        de_pkg="mate-desktop-environment-core";        de_session="mate-session"; break ;;
            *) echo -e "  ${RED}Enter 1-4.${RESET}" ;;
        esac
    done

    save_profile "DE" "$de_name"
    save_profile "DE_PKG" "$de_pkg"
    save_profile "DE_SESSION" "$de_session"

    success "Selected: ${de_name}"
    echo ""
    sleep 1
}

install_desktop_environment() {
    local de_name de_pkg
    de_name=$(load_profile "DE")
    de_pkg=$(load_profile "DE_PKG")

    info "Installing ${de_name}... This may take several minutes."

    # run_logged animates a spinner while apt works and aborts (with the log
    # tail) on failure — base desktop install is fatal, so this is correct.
    run_logged "Installing ${de_name} desktop" run_in_ubuntu bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y --no-install-recommends ${de_pkg} dbus-x11
    "
}

# ── Desktop repair / self-heal ──────────────────────────────────────────────
# Installing extra apps inside proot can leave the XFCE panel unable to start
# (a corrupt saved session, a stale menu cache that crashes a panel plugin, or
# an autostart entry that hangs with no systemd/dbus-system bus). Nux never
# edits panel config itself, so we make the desktop deterministic instead:
#   - guarantee a valid xfce4-panel.xml exists,
#   - stop XFCE saving/restoring sessions,
#   - hide autostart entries that misbehave under proot,
#   - (full) rebuild the menu/desktop caches.
#
# Modes:  ensure  → deploy the panel layout only if it's missing (run on every
#                   `nux start`, so user customisations survive).
#         full    → re-assert the layout and rebuild caches (run after an
#                   install, i.e. exactly when the panel tends to break).
repair_xfce_desktop() {
    local mode="${1:-ensure}"
    local de_session user home asset

    de_session=$(load_profile "DE_SESSION"); de_session="${de_session:-startxfce4}"
    # Only XFCE is handled for now; other DEs simply skip (no-op, never fatal).
    [[ "$de_session" == "startxfce4" ]] || return 0

    user=$(load_profile "USERNAME"); user="${user:-nuxdroid}"
    home="$NUX_PROOT_DIR/home/$user"
    [[ -d "$home" ]] || return 0

    info "Tidying up the desktop..."

    # Stage the bundled panel layout inside the user's home so the in-distro
    # step can install it *as the user* (correct ownership). $PREFIX is not
    # mounted inside proot, so the asset must be copied to the rootfs first.
    asset="$NUX_SHARE_DIR/assets/xfce4/xfce4-panel.xml"
    [[ -s "$asset" ]] && cp -f "$asset" "$home/.nux-panel.xml" 2>/dev/null

    # The repair body runs inside proot as the user. A quoted heredoc keeps it
    # free of escaping — $HOME etc. resolve in the guest, $1 carries the mode.
    cat > "$home/.nux-repair.sh" <<'REPAIR'
#!/bin/bash
set +e
mode="${1:-ensure}"
cfg="$HOME/.config"
xfconf="$cfg/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$xfconf" "$cfg/autostart" "$HOME/.cache"

# 1. Guarantee a valid panel layout. Prefer the distro's own stock default
#    (version-matched, and what worked on the core-only first run); fall back
#    to the bundled layout only if that's missing. On `full` always re-assert;
#    on `ensure` only if the user's copy is missing.
panel="$xfconf/xfce4-panel.xml"
if [ "$mode" = "full" ] || [ ! -s "$panel" ]; then
    if [ -s /etc/xdg/xfce4/panel/default.xml ]; then
        cp -f /etc/xdg/xfce4/panel/default.xml "$panel"
    elif [ -s "$HOME/.nux-panel.xml" ]; then
        cp -f "$HOME/.nux-panel.xml" "$panel"
    fi
fi

# 2. Never save/restore a session — a crashed app in a saved session is a
#    common reason the panel doesn't come back on the next launch.
cat > "$xfconf/xfce4-session.xml" <<'XSESS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="SaveOnExit" type="bool" value="false"/>
    <property name="AutoSave" type="bool" value="false"/>
  </property>
</channel>
XSESS
rm -rf "$HOME/.cache/sessions"/* 2>/dev/null

# 3. Hide autostart entries that hang or error under proot (no systemd/udev,
#    no system dbus). A user-level Hidden override is reversible & harmless.
for app in xfce4-power-manager light-locker xfce4-screensaver xscreensaver \
           blueman nm-applet update-notifier xfce-polkit \
           polkit-gnome-authentication-agent-1 pulseaudio snap-userd-autostart \
           at-spi-dbus-bus org.gnome.SettingsDaemon.Power; do
    printf '[Desktop Entry]\nHidden=true\n' > "$cfg/autostart/$app.desktop"
done

# 4. Rebuild menu/desktop caches so a corrupt cache can't crash the panel.
if [ "$mode" = "full" ]; then
    rm -rf "$HOME/.cache/menus"/* "$HOME/.cache/xfce4"/* 2>/dev/null
    command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
fi
exit 0
REPAIR

    run_in_ubuntu_user bash "/home/$user/.nux-repair.sh" "$mode" >> "$NUX_LOG" 2>&1 || true
    rm -f "$home/.nux-repair.sh" "$home/.nux-panel.xml" 2>/dev/null

    success "Desktop ready."
}
