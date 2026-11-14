#!/usr/bin/env bash
# Names the porelo-host collection a build of one channel carries, as one line `<version> <sha256> <file> <source>`.
#
#   releases   the release porelo-host pins (`--collection-info` without defines); its source is the tag `v<version>`.
#   snapshots  the newest snapshot, read once from `latest.json`, the pointer porelo-host's rolling `snapshot`
#              pre-release uploads last; its source is the commit the snapshot was built from.
#
# Only the pointer is read here; tool/fetch_collection.sh fetches the collection and checks it against the digest and
# SHA256SUMS. PORELO_COLLECTION_SOURCE names a local directory holding latest.json, for a build without the network.
set -euo pipefail

fail() {
    printf 'host-collection: %s\n' "$*" >&2
    exit 65
}

[ "$#" -eq 1 ] || fail 'usage: host_collection.sh <releases|snapshots>'
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
snapshot=https://github.com/porelo-ai/porelo-host/releases/download/snapshot

# The whole string the pointer holds under <key>, into $got; trailing newlines are kept, so the checks below see them.
field() {
    got=$(jq -ej --arg key "$1" 'if type == "object" then .[$key] | strings else empty end' "$pointer" && printf .) ||
        fail "latest.json holds no string $1"
    got=${got%.}
}

case $1 in
releases)
    line=$(cd -- "$here" && dart packages/porelo_host/bin/porelo_host.dart --collection-info) ||
        fail 'porelo-host names no collection'
    read -r version sha256 file rest <<<"$line"
    [ -z "${rest:-}" ] || fail "porelo-host names more than a collection: $line"
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "a release carries a released collection, not $version"
    source=v$version
    ;;
snapshots)
    command -v jq >/dev/null || fail 'jq is needed to read latest.json'
    pointer=$(mktemp)
    trap 'rm -f -- "$pointer"' EXIT
    if [ -n "${PORELO_COLLECTION_SOURCE:-}" ]; then
        [ -d "$PORELO_COLLECTION_SOURCE" ] || fail 'PORELO_COLLECTION_SOURCE must name a local directory'
        cp -- "$PORELO_COLLECTION_SOURCE/latest.json" "$pointer"
    else
        # A 4xx says the pointer is not there, which waiting does not change; anything else is tried again by the one
        # rule for pinned downloads.
        code=$(curl -sS -L --proto '=https' --proto-redir '=https' --connect-timeout 30 --max-time 120 \
            -o "$pointer" -w '%{http_code}' "$snapshot/latest.json") || code=000
        case $code in
        200) ;;
        4??) fail "$snapshot/latest.json answered HTTP $code" ;;
        *)
            # shellcheck source=../.github/actions/pinned-jdk/pinned.sh
            . "$here/.github/actions/pinned-jdk/pinned.sh"
            pinned_retry 'latest.json' curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 30 \
                --max-time 120 -o "$pointer" "$snapshot/latest.json" || fail "$snapshot/latest.json could not be read"
            ;;
        esac
    fi
    field version && version=$got
    field file && file=$got
    field sha256 && sha256=$got
    field commit && source=$got
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+-snapshot\.[0-9]+$ ]] || fail "latest.json names no snapshot version: $version"
    [ "$file" = "porelo-host-$version.tar.gz" ] || fail "latest.json names $file, not porelo-host-$version.tar.gz"
    [[ $sha256 =~ ^[0-9a-f]{64}$ ]] || fail 'latest.json names no SHA-256 of 64 lower-case hexadecimal digits'
    [[ $source =~ ^[0-9a-f]{40}$ ]] || fail 'latest.json names no commit of 40 lower-case hexadecimal digits'
    ;;
*) fail "unknown channel: $1" ;;
esac

printf 'host-collection: carrying porelo-host collection %s, SHA-256 %s, from %s\n' "$version" "$sha256" "$source" >&2
printf '%s %s %s %s\n' "$version" "$sha256" "$file" "$source"
