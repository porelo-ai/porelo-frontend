#!/usr/bin/env bash
# Walks one sprint walk as the operator does: the real interface on a hidden display, the real keepassxc-cli, this
# computer's Porelo and the test machine, with a home, settings and secrets file of this run's own. Usage:
#   tool/walk_on_this_laptop.sh <walk number>, as 18 for doc/walks/18-*.json and integration_test/walk_18_test.dart
set -eu
set -o pipefail

cd -- "$(dirname -- "$0")/.."
if [ "$#" -ne 1 ] || ! printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9]+$'; then
    echo 'usage: tool/walk_on_this_laptop.sh <walk number>' >&2
    exit 64
fi
number=$1
walk_file=$(find doc/walks -maxdepth 1 -name "$number-*.json" | head -n 1)
test_file=integration_test/walk_${number}_test.dart
if [ ! -f "$walk_file" ] || [ ! -f "$test_file" ]; then
    echo "walk-$number: no doc/walks/$number-*.json or no $test_file" >&2
    exit 64
fi
for command in flutter ssh-keygen ssh-agent ssh-add timeout setsid xvfb-run dbus-run-session gnome-keyring-daemon gdbus; do
    command -v "$command" >/dev/null || {
        echo "walk-$number: missing command: $command" >&2
        exit 1
    }
done
[ -x /usr/bin/keepassxc-cli ] || {
    echo "walk-$number: keepassxc-cli is missing: sudo apt install keepassxc-minimal" >&2
    exit 1
}
key=${PORELO_WALK_KEY:-$HOME/.claude/.ssh/claude_key}
local_socket=${PORELO_WALK_SOCKET:-/run/user/$(id -u)/porelo/porelod.sock}
[ -S "$local_socket" ] || {
    echo "walk-$number: this computer's Porelo does not serve $local_socket" >&2
    exit 1
}
if ! sdk=$(flutter sdk-path) || [ ! -x "$sdk/bin/flutter" ]; then
    echo "walk-$number: cannot resolve a usable Flutter SDK with flutter sdk-path" >&2
    exit 1
fi
export sdk

walk=$(mktemp -d "/tmp/pw$number.XXXXXX")
echo "walk-$number: walk folder: $walk"
agent=''
# shellcheck disable=SC2329
cleanup() {
    local status=$?
    trap - EXIT INT TERM
    if [ -n "$agent" ]; then kill "$agent" 2>/dev/null || true; fi
    # What the interface raised in this run's folder, its ssh forwards above all, ends with the run.
    pkill -TERM -f -- "$walk/" 2>/dev/null || true
    rm -rf -- "$walk"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
umask 077
mkdir -p "$walk/bin" "$walk/config/porelo" "$walk/run/keyring" "$walk/home" "$walk/keys" "$walk/tmp"

cp "$walk_file" "$walk/walk.json"
ssh-keygen -q -t ed25519 -N '' -C "walk-$number-invented" -f "$walk/keys/walk_ed25519"
# Only the provider key's check stands in: nothing in this walk rents, and the key is not this run's to read.
printf '%s\n' '#!/bin/sh' '[ "$*" = "key check scaleway" ] && { echo accepted; exit 0; }' \
    'echo "walk stand-in: only key check scaleway" >&2; exit 64' >"$walk/bin/porelo-host"
chmod 700 "$walk/bin/porelo-host"
# ssh reads ~/.ssh/config from the account's real home, not $HOME: this run's ssh reads the one the wizard writes.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' '[ -f "$HOME/.ssh/config" ] && exec /usr/bin/ssh -F "$HOME/.ssh/config" "$@"' \
    'exec /usr/bin/ssh "$@"' >"$walk/bin/ssh"
chmod 700 "$walk/bin/ssh"
printf '#!/bin/sh\nexit 0\n' >"$walk/bin/notify-send"
chmod 755 "$walk/bin/notify-send"
printf '{"machines":[{"name":"this machine","socket":"%s"}]}\n' "$local_socket" >"$walk/config/porelo/frontend.json"

# The test machine's key in an agent of this run: ssh offers it first, as the walk's ssh lines make it. On the test
# machine itself the key stays on the laptop: the run takes the agent forwarded to it.
if [ -r "$key" ]; then
    eval "$(ssh-agent -s -a "$walk/agent.sock")" >/dev/null
    agent=$SSH_AGENT_PID
    ssh-add -q "$key"
elif ! ssh-add -l >/dev/null 2>&1; then
    echo "walk-$number: no key at $key and no forwarded agent holding one" >&2
    exit 1
fi

export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
export HOME="$walk/home" PATH="$walk/bin:$PATH" TMPDIR="$walk/tmp"
export XDG_CONFIG_HOME="$walk/config" XDG_RUNTIME_DIR="$walk/run"
export XDG_DATA_HOME="$walk/home/.local/share" XDG_STATE_HOME="$walk/home/.local/state"
export XDG_CACHE_HOME="$walk/home/.cache"
export PORELO_WALK="$walk" test_file PORELO_HOST_STANDIN="$walk/bin/porelo-host"
export PORELO_WALK_PROJECT=${PORELO_WALK_PROJECT:-sprint5}
export PORELO_WALK_KEY="$key" PORELO_WALK_WORK_USER=${PORELO_WALK_WORK_USER:-walkdrive}
export PORELO_WALK_SCALEWAY_PROJECT=${PORELO_WALK_SCALEWAY_PROJECT:-5075079b-230c-41ea-8e71-1627ff0c8f08}
export PORELO_WALK_SIGNING_KEY=${PORELO_WALK_SIGNING_KEY:-/home/michi/.porelo/handover/porelo-host-scaleway-test/wg/signer.pub}
export GDK_BACKEND=x11 FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
unset WAYLAND_DISPLAY GNOME_KEYRING_CONTROL GNOME_KEYRING_PID

echo "walk-$number: walking it on a hidden display (25-minute deadline)"
# shellcheck disable=SC2016
setsid timeout --kill-after=5s 26m \
    xvfb-run -a -s '-screen 0 1600x1000x24' dbus-run-session -- bash -eu -o pipefail -c '
        printf %s walk-keyring-only |
            gnome-keyring-daemon --foreground --unlock --components=secrets \
                --control-directory="$XDG_RUNTIME_DIR/keyring" >"$PORELO_WALK/keyring.log" 2>&1 &
        keyring=$!
        trap "kill $keyring 2>/dev/null || true" EXIT
        timeout 20s gdbus wait --session --timeout 15 org.freedesktop.secrets
        "$sdk/bin/flutter" test --no-pub -d linux "$test_file"
    '
