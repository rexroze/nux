#!/data/data/com.termux/files/usr/bin/bash
# Nux Droid — Locale and Timezone Sync

detect_locale() {
    local lang timezone

    # Get language from Android
    lang=$(getprop persist.sys.locale 2>/dev/null || getprop ro.product.locale 2>/dev/null)
    lang="${lang:-en_US.UTF-8}"
    # Normalize: en-US → en_US
    lang=$(echo "$lang" | sed 's/-/_/')
    [[ "$lang" != *.* ]] && lang="${lang}.UTF-8"

    # Get timezone from Android
    timezone=$(getprop persist.sys.timezone 2>/dev/null)
    timezone="${timezone:-UTC}"

    save_profile "LOCALE" "$lang"
    save_profile "TIMEZONE" "$timezone"
}

configure_locale_in_ubuntu() {
    local lang timezone
    lang=$(load_profile "LOCALE")
    timezone=$(load_profile "TIMEZONE")
    lang="${lang:-en_US.UTF-8}"
    timezone="${timezone:-UTC}"

    { echo ""; echo "\$ configure locale ${lang} / timezone ${timezone}"; } >> "$NUX_LOG"
    run_in_ubuntu bash -c "
        # Set timezone
        ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
        echo '${timezone}' > /etc/timezone

        # Generate locale
        sed -i 's/# ${lang}/${lang}/' /etc/locale.gen
        locale-gen
        echo 'LANG=${lang}' > /etc/default/locale
    " >> "$NUX_LOG" 2>&1 || warn "Locale setup had issues (continuing). See $NUX_LOG."

    success "Locale: ${lang} | Timezone: ${timezone}"
}

setup_locale() {
    detect_locale
    configure_locale_in_ubuntu
}
