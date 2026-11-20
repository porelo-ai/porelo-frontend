#!/usr/bin/env bash
# Pub can keep a failed solver derivation when it fetches a missing git commit during resolution,
# dropping that package's transitive dependencies on the first pub get. Fill existing mirrors
# before the solver starts; a repository with no mirror is cloned fresh by pub.
set -euo pipefail

fail() {
    printf 'fetch-pinned-git: %s\n' "$*" >&2
    exit 1
}

[ "$#" -eq 0 ] || fail 'takes no arguments; run from the repository root'

# Pub writes a block mapping with scalar git descriptions; reject incomplete pins before any fetch.
pins=$(awk '
    function scalar(value, quote) {
        sub(/^[^:]*:[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        quote = substr(value, 1, 1)
        if (quote == "\"" || quote == "\047") {
            if (substr(value, length(value), 1) != quote) exit 1
            value = substr(value, 2, length(value) - 2)
        }
        return value
    }
    function emit() {
        if (source == "git") {
            if (url == "" || ref == "") exit 1
            print url "\t" ref
        }
        source = url = ref = ""
        description = 0
    }
    /^packages:[[:space:]]*$/ { packages = found = 1; next }
    packages && /^[^[:space:]#]/ { emit(); packages = 0 }
    packages && /^  [^[:space:]#][^:]*:[[:space:]]*$/ { emit(); next }
    packages && /^    [^[:space:]#]/ {
        description = ($0 ~ /^    description:[[:space:]]*$/)
        if ($0 ~ /^    source:/) source = scalar($0)
    }
    packages && description && /^      url:/ { url = scalar($0) }
    packages && description && /^      resolved-ref:/ { ref = scalar($0) }
    END { if (!found) exit 1; if (packages) emit() }
' pubspec.lock) || fail 'cannot read git pins from pubspec.lock'

case "${OSTYPE:-}" in
msys* | cygwin* | win32*)
    cache=${PUB_CACHE:-${LOCALAPPDATA:?LOCALAPPDATA is required}/Pub/Cache}
    cache=$(cygpath -u "$cache")
    ;;
*) cache=${PUB_CACHE:-${HOME:?HOME is required}/.pub-cache} ;;
esac

while IFS=$'\t' read -r url ref; do
    [ -n "$url" ] || continue
    [[ $ref =~ ^([0-9a-fA-F]{40}|[0-9a-fA-F]{64})$ ]] || fail "invalid resolved-ref for $url"
    for mirror in "$cache"/git/cache/*; do
        [ -d "$mirror" ] || continue
        origin=$(git --git-dir="$mirror" config --get remote.origin.url) || continue
        [ "$origin" = "$url" ] || continue
        [ "$(git --git-dir="$mirror" rev-parse --is-bare-repository)" = true ] || continue
        if ! git --git-dir="$mirror" cat-file -e "$ref^{commit}" 2>/dev/null; then
            GIT_TERMINAL_PROMPT=0 git --git-dir="$mirror" fetch --quiet origin || fail "fetch failed for $url at $ref"
            git --git-dir="$mirror" cat-file -e "$ref^{commit}" 2>/dev/null || fail "missing commit $ref for $url after fetch"
            printf 'fetch-pinned-git: fetched %s for %s\n' "$url" "$ref"
        fi
    done
done <<<"$pins"
