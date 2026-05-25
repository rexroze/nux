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

    run_in_ubuntu bash -c "
        # Set timezone
        ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime 2>/dev/null
        echo '${timezone}' > /etc/timezone 2>/dev/null

        # Generate locale
        sed -i 's/# ${lang}/${lang}/' /etc/locale.gen 2>/dev/null
        locale-gen 2>/dev/null
        echo 'LANG=${lang}' > /etc/default/locale 2>/dev/null

        # Export
        export LANG=${lang}
        export TZ=${timezone}
    " 2>/dev/null

    success "Locale: ${lang} | Timezone: ${timezone}"
}

setup_locale() {
    detect_locale
    configure_locale_in_ubuntu
}
