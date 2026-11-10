#!/usr/bin/env bash
# Captures every screen of the window as pictures, for a reading of how they look and whether they make sense.
#
#   tool/capture_screens.sh [FOLDER] [SITUATION...]
#
# FOLDER defaults to /var/tmp/porelo-screens; SITUATION is any of `full` (the mock's machine with work on it and the
# organization of the contract's example), `empty` (the mock's machine with no work, and no organization) and `lost`
# (the full one, whose machine stops answering), all three by default. Each runs the window once, headless under
# Xvfb in a D-Bus session of its own, against the mock in its process, with config, state, data, cache and runtime
# folders of its own, so nothing of the person's is read or written, and a stand-in for Porelo's command line. Every screen is captured at 390x844, 1024x768 and 1920x1080, light and
# dark, into FOLDER/SITUATION, beside `missing.txt` (what could not be reached, and why), `finder-words.txt` (what
# the finder lists) and `porelo-asked.txt` (what the window asked Porelo's command line).
#
# The dialogs captured are the finder's commands named one per line in tool/capture_screens.dialogs.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
into=${1:-/var/tmp/porelo-screens}
shift || true
situations=("$@")
[ ${#situations[@]} -gt 0 ] || situations=(full empty lost)

command -v xvfb-run >/dev/null || {
    echo "xvfb-run is missing: sudo apt install xvfb" >&2
    exit 1
}
command -v dbus-run-session >/dev/null || {
    echo "dbus-run-session is missing: sudo apt install dbus" >&2
    exit 1
}

# The SDK's own flutter rather than a snap's wrapper, which cannot start inside a D-Bus session of its own.
flutter_root=$(flutter --version --machine 2>/dev/null | jq -r .flutterRoot)
[ -x "$flutter_root/bin/flutter" ] || {
    echo "capture: flutter names no SDK it runs from" >&2
    exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
# The app's notifications would reach the person's desktop.
printf '#!/bin/sh\nexit 0\n' >"$work/bin/notify-send"
chmod 755 "$work/bin/notify-send"

for situation in "${situations[@]}"; do
    case "$situation" in full | empty | lost) ;; *) echo "capture: no situation $situation" >&2 && exit 64 ;; esac
    run=$work/$situation
    mkdir -p "$run/run" "$run/config" "$run/state" "$run/data" "$run/cache" "$into/$situation"
    chmod 700 "$run/run"
    # Porelo's command line, standing in: the organization of the contract's example, or none in the empty
    # situation; anything else is refused as unanswered, and every question is noted.
    cat >"$work/bin/porelo" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>'$into/$situation/porelo-asked.txt'
if [ "\$1" = org ] && [ "\$2" = --json ]; then
    if [ '$situation' = empty ]; then
        echo '{"reason":"no-organization","words":"This computer belongs to no organization yet."}'
        exit 65
    fi
    cat '$here/tool/capture_screens.organization.json'
    exit 0
fi
echo '{"words":"The capture stand-in answers only the organization."}'
exit 69
EOF
    chmod 755 "$work/bin/porelo"
    rm -f "$into/$situation"/*.png "$into/$situation"/*.txt
    (
        cd "$here"
        env -u DISPLAY -u WAYLAND_DISPLAY GDK_BACKEND=x11 \
            XDG_RUNTIME_DIR="$run/run" XDG_CONFIG_HOME="$run/config" XDG_STATE_HOME="$run/state" \
            XDG_DATA_HOME="$run/data" XDG_CACHE_HOME="$run/cache" PATH="$work/bin:$PATH" \
            PORELO_SOCKET="$run/run/laptop" PORELO_CAPTURE_SITUATION="$situation" \
            PORELO_CAPTURE_INTO="$into/$situation" \
            PORELO_CAPTURE_DIALOGS="$(grep -v '^#' "$here/tool/capture_screens.dialogs" || true)" \
            dbus-run-session -- xvfb-run -a -s '-screen 0 1920x1080x24' \
            "$flutter_root/bin/flutter" test -d linux integration_test/every_screen_capture.dart
    )
    echo "capture: $(find "$into/$situation" -name '*.png' | wc -l) pictures in $into/$situation"
done
