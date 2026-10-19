#!/usr/bin/env bash
# The secret store's tests on Linux, against a Secret Service of their own: a session bus and a
# GNOME Keyring started for the run, in a home and a runtime directory made for it and removed
# after. The person's own keyring is never touched.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
# A Dart that runs as a plain program: the snap's wrapper cannot start inside a session of its own,
# so a machine with the snap names the SDK's own binary in DART.
dart="${DART:-$(command -v dart)}"
if [ -z "${DART:-}" ] && [ "$dart" = /snap/bin/dart ] && [ -x "$HOME/snap/flutter/common/flutter/bin/cache/dart-sdk/bin/dart" ]; then
    dart="$HOME/snap/flutter/common/flutter/bin/cache/dart-sdk/bin/dart"
fi
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -m 700 "$scratch/home" "$scratch/runtime"

# The inner shell expands its own `$1` and `$2`, the package's directory and the Dart to run.
# shellcheck disable=SC2016
env -i PATH="$PATH" HOME="$scratch/home" XDG_RUNTIME_DIR="$scratch/runtime" \
    XDG_DATA_HOME="$scratch/home/.local/share" PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}" \
    dbus-run-session -- bash -c '
        set -euo pipefail
        # A login keyring made and opened with a passphrase only this run knows.
        head -c 24 /dev/urandom | base64 | gnome-keyring-daemon --unlock --components=secrets >/dev/null
        cd "$1" && "$2" test --tags keystore --reporter expanded
    ' bash "$here" "$dart"
