#!/usr/bin/env bash
# Starts a host admin's sprint walk: checks the test collection's digests where a folder is given, builds porelo-host
# from this checkout into ~/.porelo/walk/porelo-host (or $PORELO_WALK), builds the Linux debug bundle and starts it with
# --roles host-admin, directly rather than through flutter run so snap confinement does not block wg-quick.
# It starts invisibly on a private X display unless --visible is given; only the operator walking it passes --visible,
# so an agent's rehearsal never opens a window on the operator's desktop. Hidden, its walk folder defaults to
# ~/.porelo/walk-hidden, so a rehearsal never touches the operator's walk.
# Usage, from anywhere in this checkout:
#   bash tool/start_host_walk.sh [--visible] <walk number> [<folder holding the test collection and its SHA256SUMS>]
set -eu
set -o pipefail

visible=false
if [ "${1:-}" = --visible ]; then
    visible=true
    shift
fi
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || { [ "$#" -eq 2 ] && [ -z "$2" ]; } || ! printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9]+$'; then
    echo 'usage: bash tool/start_host_walk.sh [--visible] <walk number> [<collection folder>]' >&2
    exit 64
fi
# The collection folder and the walk folder are taken from where the script was called, before it moves to the checkout.
collection=${2:+$(realpath -- "$2")}
if [ "$visible" = true ]; then
    walk=$(realpath -m -- "${PORELO_WALK:-$HOME/.porelo/walk}")
else
    walk=$(realpath -m -- "${PORELO_WALK:-$HOME/.porelo/walk-hidden}")
    # Neither the operator's walk folder, of the account's own home whatever HOME says, nor a folder in or around it.
    home=$(getent passwd "$(id -un)" | cut -d: -f6)
    if [ -z "$home" ] || [ "$walk" = / ]; then
        echo "start-host-walk: the account's home is unknown or PORELO_WALK is /; a hidden start refuses" >&2
        exit 64
    fi
    operator_walk=$(realpath -m -- "$home/.porelo/walk")
    case "$walk/" in
    "$operator_walk"/*)
        echo "start-host-walk: $walk is or lies in the operator's walk folder; a hidden start takes another PORELO_WALK" >&2
        exit 64
        ;;
    esac
    case "$operator_walk/" in
    "$walk"/*)
        echo "start-host-walk: $walk holds the operator's walk folder; a hidden start takes another PORELO_WALK" >&2
        exit 64
        ;;
    esac
fi
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
# The walk folder holds the walk's sockets, screenshots and keys; nobody else reads it.
umask 077
mkdir -p "$walk"
chmod 700 "$walk"
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
# Hidden, the run has a home of its own under the walk folder: its own HOME, settings, state, data and cache, so the
# interface neither reads nor writes the person's secrets file or settings, and a throwaway keyring unlocked on its own
# D-Bus session, whose password is invented here. The person's ssh agent is not passed on, and the daemon socket names
# a file nobody listens at. ssh itself still reads ~/.ssh of the account's passwd home, whatever HOME says, so a
# rehearsal goes only as far as the walk's stand-ins answer; the steps that call /usr/bin/ssh by path are not run. GTK finds the session's default Wayland socket even without WAYLAND_DISPLAY;
# x11 on a private display keeps it hidden.
hidden=$walk/hidden
# The runtime folder holds unix sockets, whose paths may not pass 107 bytes, a tunnel's with a host name of up to 63
# bytes after it; so it lies in the person's own runtime folder under a short name, apart from an interface open there.
runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pwh
if [ "$(printf %s "$runtime" | LC_ALL=C wc -c)" -gt 24 ]; then
    echo "start-host-walk: $runtime is too long for the interface's sockets" >&2
    exit 64
fi
mkdir -p "$hidden/home" "$hidden/config" "$hidden/state" "$hidden/data" "$hidden/cache" "$runtime"
chmod 700 "$runtime"
# shellcheck disable=SC2016
exec env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u GNOME_KEYRING_CONTROL -u SSH_AUTH_SOCK \
    PORELO_SOCKET="$runtime/no-daemon.sock" GDK_BACKEND=x11 HOME="$hidden/home" XDG_RUNTIME_DIR="$runtime" XDG_CONFIG_HOME="$hidden/config" \
    XDG_STATE_HOME="$hidden/state" XDG_DATA_HOME="$hidden/data" XDG_CACHE_HOME="$hidden/cache" \
    PORELO_HOST_STANDIN="$walk/porelo-host" PORELO_WALK="$walk" \
    xvfb-run -a -s '-screen 0 1280x800x24' dbus-run-session -- bash -eu -c '
        printf %s walk-keyring-only |
            gnome-keyring-daemon --foreground --unlock --components=secrets \
                --control-directory="$XDG_RUNTIME_DIR/keyring" >"$PORELO_WALK/keyring.log" 2>&1 &
        keyring=$!
        trap "kill $keyring 2>/dev/null || true" EXIT
        timeout 20s gdbus wait --session --timeout 15 org.freedesktop.secrets
        "$0" --roles host-admin' "$bundle"
