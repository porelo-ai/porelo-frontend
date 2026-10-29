#!/usr/bin/env bash
# Walk 23, laptop B, as the developer: unpacks the interface handed over beside this script into
# ~/.porelo/walk23, after checking every file against SHA256SUMS, and starts it with --roles developer, visibly on
# this desktop, which the operator walks. It refuses loudly and may be run again: an unpacked bundle of the same
# digest is kept, any other is replaced.
# Usage, logged in as the developer, from the unpacked hand-over: bash laptop-b-start.sh
set -euo pipefail
current=
step() { current=$1; printf '\n== %s: %s\n' "$1" "$2"; }
refuse() { printf '%s refused: %s\n' "${current:-laptop-b-start}" "$*" >&2; exit 1; }
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
here=$(cd "$(dirname "$0")" && pwd)
developer=${PORELO_WALK_DEVELOPER:-walkdev}
walk=$HOME/.porelo/walk23

step b-start.1 "this runs as $developer on a desktop"
[ "$(id -un)" = "$developer" ] || refuse "log in as $developer; this is $(id -un)"
[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || refuse "no desktop here; run it in a terminal on $developer's desktop"
for tool in sha256sum tar porelo wg keepassxc-cli; do
    command -v "$tool" > /dev/null || refuse "$tool is missing; run laptop-b-make.sh as root first"
done
echo "ok: $developer on a desktop, tools present"

step b-start.2 "every handed-over file is the one handed over"
(cd "$here" && sha256sum --quiet --strict -c SHA256SUMS) || refuse "the hand-over in $here does not match its SHA256SUMS"
[ -f "$here/porelo-frontend-bundle.tar.gz" ] || refuse "no porelo-frontend-bundle.tar.gz beside this script"
digest=$(sha256sum "$here/porelo-frontend-bundle.tar.gz" | cut -d' ' -f1)
echo "ok: interface bundle $digest"

step b-start.3 "the interface is unpacked in $walk"
umask 077
mkdir -p "$walk"
if [ "$(cat "$walk/bundle.sha256" 2> /dev/null || true)" = "$digest" ] && [ -x "$walk/bundle/porelo_frontend" ]; then
    echo "ok: unpacked already"
else
    rm -rf -- "$walk/bundle" "$walk/bundle.sha256"
    mkdir "$walk/bundle"
    tar -xzf "$here/porelo-frontend-bundle.tar.gz" -C "$walk/bundle" --no-same-owner
    [ -x "$walk/bundle/porelo_frontend" ] || refuse "the bundle holds no porelo_frontend"
    printf '%s\n' "$digest" > "$walk/bundle.sha256"
    echo "ok: unpacked"
fi

step b-start.4 "the interface starts with --roles developer"
echo "starting it; close its window to end this script"
exec "$walk/bundle/porelo_frontend" --roles developer
