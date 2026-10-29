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

visible=false
if [ "${1:-}" = --visible ]; then
    visible=true
    shift
fi
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || ! printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9]+$'; then
    echo 'usage: bash tool/start_host_walk.sh [--visible] <walk number> [<collection folder>]' >&2
    exit 64
fi
# The collection folder and the walk folder are taken from where the script was called, before it moves to the checkout.
collection=${2:+$(realpath -- "$2")}
walk=$(realpath -m -- "${PORELO_WALK:-$HOME/.porelo/walk}")
cd -- "$(dirname -- "$0")/.."
walk_file=$(find doc/walks -maxdepth 1 -name "$1-*.json" | head -n 1)
if [ ! -f "$walk_file" ]; then
    echo "start-host-walk: no doc/walks/$1-*.json" >&2
    exit 64
fi
if [ -n "$collection" ]; then
    echo "start-host-walk: checking the test collection in $collection"
    (cd -- "$collection" && sha256sum -c SHA256SUMS) || {
        echo "start-host-walk: step 0-1 failed: the test collection does not match its SHA256SUMS" >&2
        exit 1
    }
fi
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
# Hidden, the run has a home of its own under the walk folder: its own runtime, settings and state, so it neither
# reaches an interface open on the desktop nor writes into the person's settings, and a throwaway keyring unlocked on
# its own D-Bus session, whose password is invented here. GTK finds the session's default Wayland socket even without
# WAYLAND_DISPLAY; x11 on a private display keeps it hidden.
hidden=$walk/hidden
# The runtime folder holds unix sockets, whose paths may not pass 107 bytes; it is kept and used again by the next run.
runtime=$hidden/run
if [ "${#runtime}" -gt 80 ]; then
    echo "start-host-walk: $runtime is too long for the interface's sockets; set a shorter PORELO_WALK" >&2
    exit 64
fi
mkdir -p "$hidden/config" "$hidden/state" "$hidden/data" "$runtime"
chmod 700 "$runtime"
# shellcheck disable=SC2016
exec env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u GNOME_KEYRING_CONTROL GDK_BACKEND=x11 \
    XDG_RUNTIME_DIR="$runtime" XDG_CONFIG_HOME="$hidden/config" XDG_STATE_HOME="$hidden/state" \
    XDG_DATA_HOME="$hidden/data" PORELO_HOST_STANDIN="$walk/porelo-host" PORELO_WALK="$walk" \
    xvfb-run -a -s '-screen 0 1280x800x24' dbus-run-session -- bash -eu -c '
        printf %s walk-keyring-only |
            gnome-keyring-daemon --foreground --unlock --components=secrets \
                --control-directory="$XDG_RUNTIME_DIR/keyring" >"$PORELO_WALK/keyring.log" 2>&1 &
        timeout 20s gdbus wait --session --timeout 15 org.freedesktop.secrets
        exec "$0" --roles host-admin' "$bundle"
