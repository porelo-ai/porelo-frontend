#!/usr/bin/env bash
# Fetches one pinned collection: a release `<x.y.z>` from its release, a snapshot `<x.y.z>-snapshot.<run>` from the
# rolling `snapshot` pre-release, both checked alike. A local source directory permits an offline build check.
set -eu

fail() {
    printf 'fetch-collection: %s\n' "$*" >&2
    exit 65
}

[ "$#" -ge 3 ] && [ "$#" -le 4 ] || fail 'usage: fetch_collection.sh <version> <sha256> <out-dir> [file-name]'
version=$1
expected=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
out=$3
file=${4:-porelo-host-$version.tar.gz}
# The whole value, not line by line: a second line would pass a line-wise match.
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    tag=v$version
elif [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+-snapshot\.[0-9]+$ ]]; then
    tag=snapshot
else
    fail "invalid collection version: $version"
fi
printf '%s\n' "$expected" | LC_ALL=C grep -Eq '^[0-9a-f]{64}$' || fail 'SHA-256 must contain 64 hexadecimal digits'
case "$file" in
'' | [!a-zA-Z0-9]* | *[!a-zA-Z0-9._-]* | *..*) fail "invalid release file name: $file" ;;
*.tar.gz) ;;
*) fail 'the release asset must be a .tar.gz file' ;;
esac
[ -n "$out" ] || fail 'the output directory must not be empty'

named_digest() { # <SHA256SUMS>: the one digest it names for $file
    awk -v name="$file" '
        $2 == name || $2 == "*" name { count++; digest = tolower($1) }
        END { if (count != 1) exit 1; print digest }
    ' "$1"
}
names_file() { named_digest "$1" >/dev/null; }

mkdir -p -- "$out"
stage=$(mktemp -d "$out/.collection.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -n "${PORELO_COLLECTION_SOURCE:-}" ]; then
    [ -d "$PORELO_COLLECTION_SOURCE" ] || fail 'PORELO_COLLECTION_SOURCE must name a local directory'
    cp -- "$PORELO_COLLECTION_SOURCE/$file" "$stage/$file"
    cp -- "$PORELO_COLLECTION_SOURCE/SHA256SUMS" "$stage/SHA256SUMS"
else
    release="https://github.com/porelo-ai/porelo-host/releases/download/$tag"
    # The one rule by which every pinned download here is tried again (porelo-buildtools doc/pinned-downloads.md).
    # shellcheck source=../.github/actions/pinned-jdk/pinned.sh
    . "$(dirname -- "$0")/../.github/actions/pinned-jdk/pinned.sh"
    # A cache directory, the build's, keeps both files by the pinned digest: a file already there is taken only when
    # it matches the digest, and either way both are checked below as after a download.
    cache=${PORELO_COLLECTION_CACHE:-$stage/.fetched}
    pinned_fetch "$release/$file" "$expected" "$cache/$file" || fail "$file could not be fetched"
    # The snapshot's SHA256SUMS moves with every snapshot, so one kept that does not name this file is fetched anew.
    if [ ! -s "$cache/SHA256SUMS" ] || [ -L "$cache/SHA256SUMS" ] || ! names_file "$cache/SHA256SUMS"; then
        rm -f -- "$cache/SHA256SUMS"
        # SHA256SUMS has no pinned digest of its own: it is tried again by the same pauses and then must agree.
        pinned_retry 'SHA256SUMS' curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 30 \
            --max-time 600 -o "$cache/SHA256SUMS" "$release/SHA256SUMS"
    fi
    cp -- "$cache/$file" "$stage/$file"
    cp -- "$cache/SHA256SUMS" "$stage/SHA256SUMS"
fi

named=$(named_digest "$stage/SHA256SUMS") || fail "SHA256SUMS must name $file exactly once"
[ "$named" = "$expected" ] || fail "SHA256SUMS for $file: expected $expected; got $named"
actual=$(sha256sum -- "$stage/$file")
actual=${actual%% *}
[ "$actual" = "$expected" ] || fail "$file: expected SHA-256 $expected; got $actual"
(cd -- "$stage" && printf '%s  %s\n' "$expected" "$file" | sha256sum -c -)
# A download lands in a mktemp file, mode 0600; the package installs it as it stands, and the window reads it as any
# account, so it is made readable by all before it is handed on.
chmod 0644 -- "$stage/$file"
mv -- "$stage/$file" "$out/$file"
