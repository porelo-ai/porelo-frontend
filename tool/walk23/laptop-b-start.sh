#!/usr/bin/env bash
# Walk 23, laptop B, as the developer: unpacks the interface handed over beside this script into ~/.porelo/walk23,
# after checking SHA256SUMS against the digest the walk shows and every file against SHA256SUMS, and starts it with
# --roles developer, visibly on this desktop, which the operator walks. It refuses loudly and may be run again: an
# unpacked bundle of the same digest is kept, any other replaced, never while it runs.
# Usage, logged in as the developer, from the unpacked hand-over: bash laptop-b-start.sh <SHA-256 of SHA256SUMS>
set -euo pipefail
current=
step() {
    current=$1
    printf '\n== %s: %s\n' "$1" "$2"
}
refuse() {
    printf '%s refused: %s\n' "${current:-laptop-b-start}" "$*" >&2
    exit 1
}
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
developer=${PORELO_WALK_DEVELOPER:-walkdev}
walk=$HOME/.porelo/walk23
bundle=porelo-frontend-bundle.tar.gz

step b-start.1 "this runs as $developer on a desktop"
if [ "$#" -ne 1 ] || ! [[ $1 =~ ^[0-9a-f]{64}$ ]]; then
    refuse "give the SHA-256 of SHA256SUMS the walk shows as the one argument"
fi
[ "$(id -un)" = "$developer" ] || refuse "log in as $developer; this is $(id -un)"
[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || refuse "no desktop here; run it in a terminal on $developer's desktop"
for tool in sha256sum awk tar pgrep porelo wg keepassxc-cli; do
    command -v "$tool" >/dev/null || refuse "$tool is missing; run laptop-b-make.sh as root first"
done
echo "ok: $developer on a desktop, tools present"

step b-start.2 "every handed-over file is the one handed over"
[ "$(sha256sum <"$here/SHA256SUMS" | cut -d' ' -f1)" = "$1" ] || refuse "SHA256SUMS in $here is not the one the walk names"
(cd "$here" && sha256sum --quiet --strict -c SHA256SUMS) || refuse "the hand-over in $here does not match its SHA256SUMS"
awk -v name="$bundle" '{ file = substr($0, 67); sub(/^\*/, "", file); sub(/^\.\//, "", file); if (file == name) found = 1 } END { exit !found }' \
    "$here/SHA256SUMS" || refuse "$bundle is not named in SHA256SUMS"
digest=$(sha256sum "$here/$bundle" | cut -d' ' -f1)
echo "ok: interface bundle $digest"

step b-start.3 "the interface is unpacked in $walk"
pgrep -u "$(id -u)" -f "$walk/bundle/porelo_frontend" >/dev/null && refuse "the interface from $walk runs already; close it first"
umask 077
mkdir -p "$walk"
if [ "$(cat "$walk/bundle.sha256" 2>/dev/null || true)" = "$digest" ] && [ -x "$walk/bundle/porelo_frontend" ]; then
    echo "ok: unpacked already"
else
    echo "unpacking it, replacing any earlier one in $walk/bundle"
    rm -rf -- "$walk/bundle" "$walk/bundle.sha256"
    mkdir "$walk/bundle"
    tar -xzf "$here/$bundle" -C "$walk/bundle" --no-same-owner
    [ -x "$walk/bundle/porelo_frontend" ] || refuse "the bundle holds no porelo_frontend"
    printf '%s\n' "$digest" >"$walk/bundle.sha256"
    echo "ok: unpacked"
fi

step b-start.4 "the interface starts with --roles developer"
echo "starting it; close its window to end this script"
exec "$walk/bundle/porelo_frontend" --roles developer
