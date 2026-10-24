#!/usr/bin/env bash
# Runs only the local host walk; its daemons, keys, keyring and settings belong to this run.
set -eu
set -o pipefail

cd -- "$(dirname -- "$0")/.."
for command in flutter ssh-keygen timeout setsid xvfb-run dbus-run-session gnome-keyring-daemon gdbus; do
    command -v "$command" >/dev/null || {
        echo "walk-e2e: missing command: $command" >&2
        exit 1
    }
done

# Snap wrappers resolve the SDK relative to HOME, which this run isolates below.
if ! sdk=$(flutter sdk-path) || [ ! -x "$sdk/bin/flutter" ] || [ ! -x "$sdk/bin/cache/dart-sdk/bin/dart" ]; then
    echo 'walk-e2e: cannot resolve a usable Flutter SDK with flutter sdk-path' >&2
    exit 1
fi
export sdk

walk=$(mktemp -d /tmp/pw.XXXXXX)
echo "walk-e2e: walk folder: $walk"
groups=()
# Shellcheck does not follow trap callbacks.
# shellcheck disable=SC2329
cleanup() {
    local status=$? pid attempt
    trap - EXIT INT TERM
    echo 'walk-e2e: stopping this run and removing its walk folder'
    for pid in "${groups[@]}"; do
        kill -TERM -- "-$pid" 2>/dev/null || true
    done
    for attempt in {1..50}; do
        local alive=false
        for pid in "${groups[@]}"; do
            if kill -0 -- "-$pid" 2>/dev/null; then alive=true; fi
        done
        if [ "$alive" = false ]; then break; fi
        sleep 0.1
    done
    for pid in "${groups[@]}"; do
        kill -KILL -- "-$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    if [ "$status" -ne 0 ]; then
        for log in "$walk"/*.log; do
            if [ -f "$log" ]; then
                echo "walk-e2e: $log" >&2
                cat -- "$log" >&2
            fi
        done
    fi
    rm -rf -- "$walk"
    if [ -e "$walk" ]; then
        echo "walk-e2e: could not remove $walk" >&2
        status=1
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
umask 077
mkdir -p "$walk/bin" "$walk/config" "$walk/run/keyring" "$walk/home/.ssh" "$walk/tresor" "$walk/tmp"

echo 'walk-e2e: compiling the host and SSH stand-ins (duration unmeasured)'
"$sdk/bin/cache/dart-sdk/bin/dart" compile exe tool/host_standin.dart -o "$walk/porelo-host"
"$sdk/bin/cache/dart-sdk/bin/dart" compile exe tool/ssh_standin.dart -o "$walk/bin/ssh"
printf '%s\n' '{"situation":"stop","state":"new"}' >"$walk/host-standin.json"
cp doc/walks/17-the-host-flow.json "$walk/walk.json"
printf '#!/bin/sh\nexit 0\n' >"$walk/bin/notify-send"
chmod 755 "$walk/bin/notify-send"

echo 'walk-e2e: creating an invented signing/SSH key pair in the private HOME'
ssh-keygen -q -t ed25519 -N '' -C 'local host walk only' -f "$walk/home/.ssh/id_ed25519"
# Preserve the fetched packages when HOME changes; no dependency resolution runs below.
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
export HOME="$walk/home" PATH="$walk/bin:$PATH" TMPDIR="$walk/tmp"
export XDG_CONFIG_HOME="$walk/config" XDG_RUNTIME_DIR="$walk/run"
export XDG_DATA_HOME="$walk/home/.local/share" XDG_STATE_HOME="$walk/home/.local/state"
export XDG_CACHE_HOME="$walk/home/.cache"
export PORELO_WALK="$walk" PORELO_HOST_STANDIN="$walk/porelo-host"
export PORELO_WALK_HOST_SOCKET="$walk/host.sock" PORELO_SOCKET="$walk/first.sock"
export GDK_BACKEND=x11 FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
unset WAYLAND_DISPLAY GNOME_KEYRING_CONTROL GNOME_KEYRING_PID

echo 'walk-e2e: starting work and host mocks, each with a 15-minute deadline'
mkfifo "$walk/first.in" "$walk/host.in"
# A writer held by this shell prevents EOF without sending a key to either mock.
exec 3<>"$walk/first.in"
exec 4<>"$walk/host.in"
setsid timeout --kill-after=5s 15m "$sdk/bin/cache/dart-sdk/bin/dart" tool/mock_daemon.dart work "$walk/first.sock" \
    <"$walk/first.in" >"$walk/first.log" 2>&1 &
groups+=("$!")
setsid timeout --kill-after=5s 15m "$sdk/bin/cache/dart-sdk/bin/dart" tool/mock_daemon.dart host "$walk/host.sock" \
    <"$walk/host.in" >"$walk/host.log" 2>&1 &
groups+=("$!")
ready=false
attempt=0
while [ "$attempt" -lt 300 ]; do
    attempt=$((attempt + 1))
    for pid in "${groups[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo 'walk-e2e: a mock exited before both sockets were ready' >&2
            exit 1
        fi
    done
    if [ -S "$walk/first.sock" ] && [ -S "$walk/host.sock" ]; then
        ready=true
        break
    fi
    sleep 0.1
done
if [ "$ready" = false ]; then
    echo 'walk-e2e: waited 30 seconds for first.sock and host.sock; both must be sockets' >&2
    exit 1
fi

echo 'walk-e2e: running the headless host walk (duration unmeasured, 12-minute deadline)'
# The real dialog uses the Secret Service. Give this bus an encrypted throwaway keyring whose
# password is invented, supplied on stdin, and never taken from the desktop account.
# Expansion belongs to the shell inside the isolated D-Bus session.
# shellcheck disable=SC2016
setsid timeout --kill-after=5s 12m \
    xvfb-run -a -s '-screen 0 1280x800x24' dbus-run-session -- bash -eu -o pipefail -c '
        keyring=""
        test_pid=""
        cleanup_session() {
            if [ -n "$test_pid" ]; then kill "$test_pid" 2>/dev/null || true; fi
            if [ -n "$keyring" ]; then
                kill "$keyring" 2>/dev/null || true
                wait "$keyring" 2>/dev/null || true
            fi
        }
        trap cleanup_session EXIT
        trap "exit 130" INT
        trap "exit 143" TERM
        echo "walk-e2e: opening the isolated Secret Service keyring"
        printf %s local-walk-keyring-only |
            gnome-keyring-daemon --foreground --unlock --components=secrets \
                --control-directory="$XDG_RUNTIME_DIR/keyring" >"$PORELO_WALK/keyring.log" 2>&1 &
        keyring=$!
        if ! timeout 20s gdbus wait --session --timeout 15 org.freedesktop.secrets; then
            echo "walk-e2e: the isolated Secret Service did not take its bus name within 20 seconds" >&2
            exit 1
        fi
        ready=false
        for attempt in {1..100}; do
            if ! kill -0 "$keyring" 2>/dev/null; then
                echo "walk-e2e: the isolated keyring exited" >&2
                exit 1
            fi
            if timeout 1s gdbus call --session --dest org.freedesktop.secrets \
                --object-path /org/freedesktop/secrets --method org.freedesktop.Secret.Service.ReadAlias default \
                >"$PORELO_WALK/keyring-alias.log" 2>/dev/null; then
                if grep -q /org/freedesktop/secrets/collection/ "$PORELO_WALK/keyring-alias.log"; then
                    ready=true
                    break
                fi
            fi
            sleep 0.1
        done
        if [ "$ready" = false ]; then
            echo "walk-e2e: the Secret Service did not provide a default keyring before its deadline" >&2
            exit 1
        fi
        "$sdk/bin/flutter" test --no-pub -d linux integration_test/host_walk_test.dart &
        test_pid=$!
        status=0
        wait "$test_pid" || status=$?
        test_pid=""
        exit "$status"
    ' &
groups+=("$!")
status=0
wait "${groups[2]}" || status=$?
exit "$status"
