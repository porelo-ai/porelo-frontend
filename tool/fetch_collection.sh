#!/usr/bin/env bash
# Fetches one pinned release asset; a local source directory permits an offline build check.
set -eu

fail() { printf 'fetch-collection: %s\n' "$*" >&2; exit 65; }

[ "$#" -ge 3 ] && [ "$#" -le 4 ] || fail 'usage: fetch_collection.sh <version> <sha256> <out-dir> [file-name]'
version=$1
expected=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
out=$3
file=${4:-porelo-host-$version.tar.gz}
printf '%s\n' "$version" | LC_ALL=C grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "invalid release version: $version"
printf '%s\n' "$expected" | LC_ALL=C grep -Eq '^[0-9a-f]{64}$' || fail 'SHA-256 must contain 64 hexadecimal digits'
case "$file" in
    ''|[!a-zA-Z0-9]*|*[!a-zA-Z0-9._-]*|*..*) fail "invalid release file name: $file" ;;
    *.tar.gz) ;;
    *) fail 'the release asset must be a .tar.gz file' ;;
esac
[ -n "$out" ] || fail 'the output directory must not be empty'
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
    release="https://github.com/porelo-ai/porelo-host/releases/download/v$version"
    curl -fsSL -o "$stage/$file" "$release/$file"
    curl -fsSL -o "$stage/SHA256SUMS" "$release/SHA256SUMS"
fi

named=$(awk -v name="$file" '
    $2 == name || $2 == "*" name { count++; digest = tolower($1) }
    END { if (count != 1) exit 1; print digest }
' "$stage/SHA256SUMS") || fail "SHA256SUMS must name $file exactly once"
[ "$named" = "$expected" ] || fail "SHA256SUMS for $file: expected $expected; got $named"
actual=$(sha256sum -- "$stage/$file")
actual=${actual%% *}
[ "$actual" = "$expected" ] || fail "$file: expected SHA-256 $expected; got $actual"
(cd -- "$stage" && printf '%s  %s\n' "$expected" "$file" | sha256sum -c -)
mv -- "$stage/$file" "$out/$file"
