#!/usr/bin/env bash
# Walk 23, laptop A, by the agent: builds the hand-over for laptop B from this checkout's committed HEAD. That is
# the interface's Linux bundle, the porelo package given, laptop B's three scripts and SHA256SUMS over them, in
# ~/.porelo/handover/porelo-frontend/walk23, with SHA256SUMS.sha256 beside it naming the digest the walk shows. The
# folder is fixed, so the replacement deletes nothing but an earlier hand-over. It refuses a checkout with changes, so the bundle is what a commit holds, and replaces
# an earlier hand-over.
# Usage: bash tool/walk23/hand-over.sh <porelo_*_amd64.deb>
set -euo pipefail
current=
step() {
    current=$1
    printf '\n== %s: %s\n' "$1" "$2"
}
refuse() {
    printf '%s refused: %s\n' "${current:-hand-over}" "$*" >&2
    exit 1
}
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
checkout=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
out=$HOME/.porelo/handover/porelo-frontend/walk23

step hand-over.1 "the package and the checkout"
[ "$#" -eq 1 ] || refuse "give the porelo package as the one argument"
deb=$(realpath -- "$1")
[[ $(basename -- "$deb") =~ ^porelo_[^/]+_amd64\.deb$ ]] || refuse "$1 is not a porelo_*_amd64.deb"
[ "$(dpkg-deb -f "$deb" Package)" = porelo ] || refuse "$1 is not the porelo package"
cd "$checkout"
changes=$(git status --porcelain)
[ -z "$changes" ] || refuse "the checkout has changes or untracked files; commit or remove them first"
[ ! -L "$out" ] || refuse "$out is a symbolic link; remove it first"
commit=$(git rev-parse --short HEAD)
echo "ok: porelo $(dpkg-deb -f "$deb" Version), interface from $commit"

step hand-over.2 "the interface's Linux bundle"
bundle=build/linux/x64/debug/bundle
rm -rf -- "$bundle"
flutter build linux --debug
[ -x "$bundle/porelo_frontend" ] || refuse "the build left no $bundle/porelo_frontend"
echo "ok: built"

step hand-over.3 "the hand-over in $out"
mkdir -p -- "$(dirname -- "$out")"
staging=$(mktemp -d "$(dirname -- "$out")/walk23.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
tar -czf "$staging/porelo-frontend-bundle.tar.gz" -C "$bundle" .
cp -- "$deb" "$staging/"
cp -- tool/walk23/laptop-b-make.sh tool/walk23/laptop-b-start.sh tool/walk23/laptop-b-remove.sh "$staging/"
(cd "$staging" && sha256sum -- porelo-frontend-bundle.tar.gz "$(basename -- "$deb")" laptop-b-*.sh >SHA256SUMS)
sha256sum <"$staging/SHA256SUMS" | cut -d' ' -f1 >"$staging/SHA256SUMS.sha256"
printf '%s\n' "$commit" >"$staging/COMMIT"
chmod -R go-w "$staging"
rm -rf -- "$out"
mv -- "$staging" "$out"
trap - EXIT
echo "ok: $(wc -l <"$out/SHA256SUMS") files from $commit"
printf '\nhand-over passed: the walk names SHA256SUMS digest %s\n' "$(cat "$out/SHA256SUMS.sha256")"
