#!/usr/bin/env bash
# Starts a host admin's sprint walk: checks the test collection's digests where a folder is given, builds porelo-host
# from this checkout into ~/.porelo/walk/porelo-host (or $PORELO_WALK), builds the Linux debug bundle and starts it with
# --roles host-admin, directly rather than through flutter run so snap confinement does not block wg-quick.
# It starts invisibly on a private X display unless --visible is given; only the operator walking it passes --visible,
# so an agent's rehearsal never opens a window on the operator's desktop.
# Usage, from anywhere in this checkout:
#   bash tool/start_host_walk.sh [--visible] <walk number> [<folder holding the test collection and its SHA256SUMS>]
set -eu
set -o pipefail

cd -- "$(dirname -- "$0")/.."
visible=false
if [ "${1:-}" = --visible ]; then
    visible=true
    shift
fi
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || ! printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9]+$'; then
    echo 'usage: bash tool/start_host_walk.sh [--visible] <walk number> [<collection folder>]' >&2
    exit 64
fi
walk_file=$(find doc/walks -maxdepth 1 -name "$1-*.json" | head -n 1)
if [ ! -f "$walk_file" ]; then
    echo "start-host-walk: no doc/walks/$1-*.json" >&2
    exit 64
fi
if [ "$#" -eq 2 ]; then
    echo "start-host-walk: checking the test collection in $2"
    (cd -- "$2" && sha256sum -c SHA256SUMS) || {
        echo "start-host-walk: step 0-1 failed: the test collection does not match its SHA256SUMS" >&2
        exit 1
    }
fi
walk=${PORELO_WALK:-$HOME/.porelo/walk}
mkdir -p "$walk"
cp -- "$walk_file" "$walk/walk.json"
echo 'start-host-walk: building porelo-host from this checkout'
(cd packages/porelo_host && dart compile exe bin/porelo_host.dart -o "$walk/porelo-host") || {
    echo 'start-host-walk: step 0-1 failed: porelo-host did not build' >&2
    exit 1
}
echo 'start-host-walk: building the Linux debug bundle'
flutter build linux --debug || {
    echo 'start-host-walk: step 0-1 failed: the interface did not build' >&2
    exit 1
}
bundle=build/linux/x64/debug/bundle/porelo_frontend
if [ "$visible" = true ]; then
    PORELO_HOST_STANDIN=$walk/porelo-host PORELO_WALK=$walk exec "$bundle" --roles host-admin
fi
# GTK finds the session's default Wayland socket even without WAYLAND_DISPLAY; x11 on a private display keeps it hidden.
exec env -u DISPLAY -u WAYLAND_DISPLAY GDK_BACKEND=x11 PORELO_HOST_STANDIN="$walk/porelo-host" PORELO_WALK="$walk" \
    xvfb-run -a -s '-screen 0 1280x800x24' dbus-run-session -- "$bundle" --roles host-admin
