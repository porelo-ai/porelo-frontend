#!/usr/bin/env bash
# Says ahead when the stub agent the scenarios pin is about to leave its folder on Artifactory, which keeps the
# newest 20 versions: from 15 newer ones on, the pin is named to move. It never stops a run, and the step's own
# refusal stays the last word where the pin is gone.
#
#   tool/stub_pin.sh [listing.json]
#
# A listing given is read instead of the folder's own (the tests); without one the folder's listing is read
# anonymously, and one that cannot be read is said and stops nothing.
set -euo pipefail

step="$(cd "$(dirname "$0")/.." && pwd)/integration_test/step/the_test_machine_has_porelos_stub_agent.dart"
folder=https://fuinorg.jfrog.io/artifactory/api/storage/porelo-dist-test/porelo-agent-stub
warn_at=15

pin=$(sed -n "s/^  version: '\([^']*\)',\$/\1/p" "$step")
if [ -z "$pin" ]; then
    echo "stub pin: $step names no version" >&2
    exit 0
fi
if [ $# -gt 0 ]; then
    listing=$(cat "$1")
elif ! listing=$(curl -fsS -m 20 "$folder" 2>/dev/null); then
    echo "stub pin $pin: the folder's listing could not be read, so whether it still holds the pin is not said" >&2
    exit 0
fi
versions=$(printf '%s\n' "$listing" | grep -o '"uri" *: *"/[^"]*"' | sed 's/.*"\/\([^"]*\)"$/\1/')

if ! printf '%s\n' "$versions" | grep -qxF -- "$pin"; then
    echo "stub pin $pin: its folder no longer holds it; move the pin in $step to a version it holds" >&2
    exit 0
fi
# By version, not by letters: snapshot.1000 comes after snapshot.999.
newer=$(printf '%s\n' "$versions" | sort -V | awk -v pin="$pin" 'seen { n++ } $0 == pin { seen = 1 } END { print n + 0 }')
if [ "$newer" -ge "$warn_at" ]; then
    echo "stub pin $pin: $newer newer versions in its folder, which keeps the newest 20; move the pin in $step before it falls out" >&2
fi
