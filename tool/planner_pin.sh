#!/usr/bin/env bash
# Says, as a build warning, when the planning screen this window pins is not porelo-planner's main, so a planner change
# does not wait unseen until somebody finds it live. It fails nothing: a pin may stand behind on purpose for a day.
#
#   tool/planner_pin.sh [pubspec.yaml]
#
# Reads the `porelo_planning` git dependency's url and ref from the pubspec and the url's main with `git ls-remote`.
set -uo pipefail
pubspec=${1:-pubspec.yaml}
# The url and ref under `porelo_planning:` in the dependencies, taken by indentation, not by guessing at YAML.
read -r url ref < <(awk '
    /^    porelo_planning:/ { inside = 1; next }
    inside && /^    [^ ]/ { inside = 0 }
    inside && $1 == "url:" { url = $2 }
    inside && $1 == "ref:" { ref = $2 }
    END { print url, ref }
' "$pubspec")
if [ -z "${url:-}" ] || [ -z "${ref:-}" ]; then
    echo "::warning::$pubspec names no git url and ref for porelo_planning, so its pin cannot be compared with main"
    exit 0
fi
main=$(git ls-remote "$url" refs/heads/main 2>/dev/null | awk '{ print $1; exit }')
if [ -z "$main" ]; then
    echo "::warning::porelo-planner's main could not be read from $url, so the planning screen's pin $ref is unchecked"
    exit 0
fi
if [ "$main" != "$ref" ]; then
    echo "::warning::the planning screen is pinned at $ref, but porelo-planner's main is $main: raise the pin in pubspec.yaml"
fi
