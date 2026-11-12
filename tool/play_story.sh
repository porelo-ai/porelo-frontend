#!/usr/bin/env bash
# Plays one story through the real window as a person would, the window running in a local VM under a virtual display
# against that VM's own porelo, never on this computer's.
#
#   tool/play_story.sh check --vm USER@VM --vm-key FILE --story NAME [--report DIR]
#   tool/play_story.sh run   --vm USER@VM --vm-key FILE --story NAME --report DIR [--expect PART=ISSUE]... [--budget-minutes 60]
#
# NAME is a story of the `case` below: integration_test/NAME.feature and its generated NAME_test.dart. A step names in
# its line the part of Porelo it leans on beyond what every story has, as `[PART]`; `--expect PART=ISSUE` says that
# part is still missing, so a failure of such a step is reported EXPECTED, waiting on ISSUE, and is no fault of the run.
#
# `check` validates the arguments and says what the VM lacks: it reads the VM over ssh and changes nothing there. `run`
# checks first, copies this checkout's HEAD to the VM, runs the story's test there through tool/e2e.sh under xvfb-run
# inside dbus-run-session, the window and the story's scripts on the VM itself (no ssh to it from itself), and writes
# the report into DIR: steps.txt with one line per step of the feature (`OK`, `FAIL` with what was asked and got,
# `EXPECTED` with the issue it waits on, `NOT RUN`) and one closing `STORY` line (passed, failed at a step, or waiting
# on the issues named); a picture of the window where a step failed, in pictures/; the HTML and JUnit report and the
# test's own output. It exits 0 when the story passed, 2 when it waits only on issues expected, 1 otherwise. Every
# ending takes the run's copy away; what the story made on the VM, its own steps remove.
set -euo pipefail

usage() {
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 64
}

[ $# -ge 1 ] || usage
mode=$1
shift
vm='' vm_key='' story='' report='' budget=60 expects=()
while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || usage
    case "$1" in
    --vm) vm=$2 ;;
    --vm-key) vm_key=$2 ;;
    --story) story=$2 ;;
    --report) report=$2 ;;
    --expect) expects+=("$2") ;;
    --budget-minutes) budget=$2 ;;
    *) usage ;;
    esac
    shift 2
done
case "$mode" in check | run) ;; *) usage ;; esac
[ -n "$vm" ] && [ -n "$vm_key" ] && [ -n "$story" ] || usage
[ "$mode" = check ] || [ -n "$report" ] || usage
case "$budget" in '' | *[!0-9]*) echo "play: --budget-minutes is a whole number of minutes" >&2 && exit 64 ;; esac
# Every value goes into a command line on the VM, so each is held to what it can be: no quote, no space, no option.
shaped() {
    [ -z "$2" ] || printf '%s\n' "$2" | grep -Eqx "$3" || {
        echo "play: $1 is not of the form it takes" >&2
        exit 64
    }
}
shaped --vm "$vm" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
shaped --story "$story" '[a-z0-9][a-z0-9_]*'
for each in "${expects[@]}"; do shaped --expect "$each" '[a-z][a-z0-9-]*=[A-Za-z0-9][A-Za-z0-9#._/-]*'; done
[ -r "$vm_key" ] || {
    echo "play: --vm-key $vm_key is no readable file" >&2
    exit 64
}

# What each story needs of the VM beyond what every story needs: tools, by name.
case "$story" in
a_terminal_and_live_list)
    # The work's session is read in its container, and the clearance question raised from there.
    needs='podman'
    ;;
*)
    echo "play: no story $story here; tool/play_story.sh names each in its case" >&2
    exit 64
    ;;
esac

here=$(cd "$(dirname "$0")/.." && pwd)
for each in "integration_test/$story.feature" "integration_test/${story}_test.dart"; do
    [ -f "$here/$each" ] || {
        echo "play: $each is missing; a story is a feature with its generated test" >&2
        exit 1
    }
done
flutter_version=$(sed -n 's/^ *flutter: *\([0-9][0-9.]*\) *$/\1/p' "$here/pubspec.yaml" | head -1)
[ -n "$flutter_version" ] || {
    echo "play: pubspec.yaml names no flutter version" >&2
    exit 1
}
flutter_dir=".cache/porelo-frontend/flutter-$flutter_version"

# The VM is reached with its own key alone: never the operator's agent, never a password asked, no display forwarded.
on_vm() {
    env -u SSH_AUTH_SOCK SSH_ASKPASS_REQUIRE=never ssh -x -o BatchMode=yes -o IdentitiesOnly=yes -i "$vm_key" "$vm" \
        "$(in_the_login_shell "$@")"
}

# In the account's login shell, or a command meets the machine-wide porelo instead of the account's own.
in_the_login_shell() {
    printf 'exec bash -lc %q' "$*"
}

# What the run needs on the VM, each named; a missing one is said with the line that installs it. Reads only.
check() {
    local missing
    # shellcheck disable=SC2016 # expanded on the VM, not here
    missing=$(on_vm 'for t in xvfb-run dbus-run-session systemd-run clang cmake ninja pkg-config git curl xz python3 porelo '"$needs"'; do
            command -v "$t" >/dev/null || echo "tool $t"
        done
        for p in libgtk-3-dev libsecret-1-dev; do dpkg -s "$p" >/dev/null 2>&1 || echo "package $p"; done
        [ -S "/run/user/$(id -u)/porelo/porelod.sock" ] || echo "no porelod answering in this account: its socket is missing"
        for d in "$HOME"/play/*/; do [ ! -d "$d" ] || echo "a play left in $d: take it away first"; done' </dev/null) || {
        echo "play: $vm cannot be reached with $vm_key" >&2
        return 1
    }
    if [ -n "$missing" ]; then
        echo "play: $vm lacks:" >&2
        printf '%s\n' "$missing" | sed 's/^/  /' >&2
        local packages
        packages=$(printf '%s\n' "$missing" | sed -n 's/^package //p; s/^tool xvfb-run$/xvfb/p; s/^tool \(clang\|cmake\|git\|curl\|podman\)$/\1/p;
            s/^tool ninja$/ninja-build/p; s/^tool pkg-config$/pkg-config/p; s/^tool xz$/xz-utils/p; s/^tool dbus-run-session$/dbus/p' | tr '\n' ' ')
        [ -z "$packages" ] || echo "  the operator installs them there with: sudo apt install $packages" >&2
        return 1
    fi
    echo "play: $vm has what $story needs; Flutter $flutter_version is fetched into ~/$flutter_dir if missing"
}

if [ "$mode" = check ]; then
    check
    exit
fi

check
[ -z "$(git -C "$here" status --porcelain --untracked-files=no)" ] || echo "play: runs HEAD; changes not committed are not in it" >&2
commit=$(git -C "$here" rev-parse --short HEAD)
run="play/$(date -u +%Y%m%dT%H%M%SZ)-$commit"
mkdir -p "$report"
# A report left from an earlier run would be read as this one's.
rm -f "$report/results.json" "$report/run.log" "$report/report.html" "$report/results.xml" "$report/scenarios.txt" \
    "$report/noted.txt" "$report/steps.txt"
rm -rf "$report/pictures"

# Taken away on every ending: what still runs of the window's part, and the run's copy.
# shellcheck disable=SC2329 # run by the trap on EXIT
cleanup() {
    on_vm "if [ -f ~/$run/pid ]; then kill -TERM -- -\$(cat ~/$run/pid) 2>/dev/null || true; sleep 2; fi; rm -rf ~/$run
        rmdir ~/play 2>/dev/null || true" </dev/null || {
        echo "play: the run's copy ~/$run is left on $vm; take it away there" >&2
        exit 1
    }
}
trap cleanup EXIT

echo "play: $story at $commit to $vm:~/$run"
git -C "$here" archive --format=tar HEAD | on_vm "mkdir -p ~/$run && tar -x -C ~/$run"

on_vm "set -e
    if [ ! -x ~/$flutter_dir/bin/flutter ]; then
        mkdir -p ~/.cache/porelo-frontend && cd ~/.cache/porelo-frontend
        listed=\$(curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)
        line=\$(printf '%s' \"\$listed\" | python3 -I -c 'import json,sys
d=json.load(sys.stdin)
r=[r for r in d[\"releases\"] if r[\"version\"]==\"$flutter_version\" and r[\"channel\"]==\"stable\"]
print(r[0][\"archive\"], r[0][\"sha256\"]) if r else None')
        [ -n \"\$line\" ] || { echo 'play: Flutter $flutter_version is not listed' >&2; exit 1; }
        set -- \$line
        curl -fsSL -o flutter.tar.xz \"https://storage.googleapis.com/flutter_infra_release/releases/\$1\"
        echo \"\$2  flutter.tar.xz\" | sha256sum -c --quiet
        rm -rf flutter-$flutter_version.part && mkdir flutter-$flutter_version.part
        tar -xJf flutter.tar.xz -C flutter-$flutter_version.part && rm flutter.tar.xz
        rm -rf ~/$flutter_dir && mv flutter-$flutter_version.part/flutter ~/$flutter_dir && rmdir flutter-$flutter_version.part
    fi" </dev/null

echo "play: the window plays $story, at most $budget minutes"
status=0
# In a session of its own whose number is kept, so an ending here takes the whole of it down there too; in a scope of
# the account's user manager, as a window on a desktop is, so a podman exec of the story may move into the work's
# cgroup. The window reaches this VM's own porelod, in the account's runtime directory and with the account's
# settings: the story's scripts run in place, and the porelo they call reads what porelod reads.
on_vm "cd ~/$run && exec systemd-run --user --scope --quiet setsid sh -c 'echo \$\$ >pid; exec \"\$@\"' play env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
        PATH=\$HOME/$flutter_dir/bin:\$PATH \
        PORELO_E2E_HOST=localhost PORELO_E2E_REMOTE_SOCKET=/run/user/\$(id -u)/porelo/porelod.sock \
        PORELO_E2E_ACCOUNT_RUNTIME=1 XDG_RUNTIME_DIR=/run/user/\$(id -u) PORELO_E2E_OWN_SETTINGS=1 \
        PORELO_STORY_STEPS=\$HOME/$run/noted.txt PORELO_REHEARSAL_SHOTS=\$HOME/$run/pictures \
        timeout --signal=TERM ${budget}m dbus-run-session -- \
        tool/e2e.sh --machine integration_test/${story}_test.dart" \
    </dev/null >"$report/results.json" 2>"$report/run.log" || status=$?
# The steps and the pictures, before the run's copy is taken away.
on_vm "cat ~/$run/noted.txt 2>/dev/null" </dev/null >"$report/noted.txt" || true
if on_vm "[ -d ~/$run/pictures ]" </dev/null; then on_vm "tar -C ~/$run -c pictures" </dev/null | tar -x -C "$report" || true; fi
[ "$status" -ne 124 ] || echo "play: the window's part ran out its $budget minutes and was stopped" | tee -a "$report/run.log" >&2

(cd "$here" && dart tool/test_report.dart "$report/results.json" "$report/report.html" "$report/results.xml" \
    --heading="The story $story played in the window" --against="$vm" --lines="$report/scenarios.txt") || true

# One line per step of the feature, from what the steps noted, the scenario's result for a step that noted nothing,
# and the parts expected missing; then the closing line. Its exit is the run's.
played=0
python3 -I - "$here/integration_test/$story.feature" "$report/noted.txt" "$report/scenarios.txt" "$story" \
    "${expects[@]}" >"$report/steps.txt" <<'EOF' || played=$?
import re, sys

feature, noted_file, scenarios_file, story = sys.argv[1:5]
expected = dict(each.split("=", 1) for each in sys.argv[5:])
steps = [m.group(2) for m in (re.match(r"\s*(Given|When|Then|And|But)\s+(.*)", line) for line in open(feature)) if m]
noted = {}
for line in open(noted_file, encoding="utf-8", errors="replace"):
    m = re.match(r"(OK|FAIL) (\d+) (?:\[([a-z0-9-]+)\] )?(.*)", line.rstrip("\n"))
    if m:
        noted[int(m.group(2))] = (m.group(1), m.group(3), m.group(4))
try:
    scenarios = [line.rstrip("\n") for line in open(scenarios_file, encoding="utf-8", errors="replace")]
except FileNotFoundError:
    scenarios = []
held = bool(scenarios) and all(line.startswith("OK ") for line in scenarios)
why = next((line.split(None, 1)[1] for line in scenarios if line.startswith("FAIL ")), "no result; see run.log")
last = max(noted, default=0)
failed, waiting, unexplained = [], [], None
for number, sentence in enumerate(steps, 1):
    if number in noted:
        result, part, words = noted[number]
        if result == "OK":
            print(f"OK {number} {words}")
        elif part in expected:
            head, _, reason = words.partition(": ")
            print(f"EXPECTED {number} {head}: waits on {expected[part]}; {reason}")
            waiting.append(expected[part])
        else:
            print(f"FAIL {number} {words}")
            failed.append(number)
    elif number < last or held:
        print(f"OK {number} {sentence}")
    elif unexplained is None:
        print(f"FAIL {number} {sentence}: {why}")
        failed.append(number)
        unexplained = number
    else:
        print(f"NOT RUN {number} {sentence}")
if failed:
    print(f"STORY {story}: failed at step {failed[0]}")
    sys.exit(1)
if not held and not waiting:
    print(f"STORY {story}: failed after its steps: {why}")
    sys.exit(1)
if waiting:
    print(f"STORY {story}: waiting on {', '.join(dict.fromkeys(waiting))}")
    sys.exit(2)
print(f"STORY {story}: passed")
EOF
cat "$report/steps.txt"
exit "$played"
