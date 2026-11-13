#!/usr/bin/env bash
# Plays one story through the real window as a person would: on Linux in a local VM under a virtual display against
# that VM's own porelo, on Windows in the desktop session of a Windows machine; never on this computer.
#
#   tool/play_story.sh check --story NAME [--vm USER@VM --vm-key FILE] [--packages DIR] [--report DIR]
#   tool/play_story.sh run   --story NAME --report DIR [--vm USER@VM --vm-key FILE] [--packages DIR]
#                            [--expect PART=ISSUE]... [--budget-minutes 60]
#                            [--org ORG] [--seed DIR] [--issue-repo REPO]... [--porelo-project NAME] [--planner DIR]
#   each also with [--vm-known-hosts FILE] [--vm-jump USER@HOST [--vm-jump-known-hosts FILE]], as tool/walk_idea.sh
#
# NAME is a story of the `case` below: integration_test/NAME.feature and its generated NAME_test.dart, played on the
# machine the case names, and the Windows builds it names, read on GitHub from here. A step names in its line the part
# of Porelo it leans on beyond what every story has, as `[PART]`; `--expect PART=ISSUE` says that part is still
# missing, so a failure of such a step is reported EXPECTED, waiting on ISSUE, and is no fault of the run.
#
# `check` validates the arguments and says what the machine lacks: it reads the machine over ssh, and GitHub, and
# changes nothing anywhere. `run` checks first, copies this checkout's HEAD to the machine and plays the story's test
# there. On Linux: through tool/e2e.sh under xvfb-run inside dbus-run-session, the window and the story's scripts on
# the VM itself (no ssh to it from itself). On Windows: the window's MSIX installed, started and removed again and
# porelo-planner's Windows ZIP unpacked, both from --packages DIR as the Build publishes them, checked against its
# SHA256SUMS; then `flutter test -d windows` started in the person's desktop session by tool/play_story_windows.ps1. A
# Windows story run without --vm plays only what runs from here and names its steps on the machine as waiting on it.
#
# The report goes into DIR: steps.txt with one line per step, the driver's own and the feature's (`OK`, `FAIL` with what
# was asked and got, `EXPECTED` with the issue it waits on, `WAITING` on a machine or a login, `NOT RUN`), and one
# closing `STORY` line (passed, failed at a step, or waiting on what it names); a picture of the window where a step
# failed, in pictures/; the HTML and JUnit report and the test's own output. It exits 0 when the story passed, 2 when it
# waits only on issues expected or a machine, 1 otherwise. Every ending takes the run's copy and what it installed away;
# what the story made, its own steps remove.
#
# A Windows build is read from main's latest Build, its Windows job. Where the Build has none, the repository's
# `Windows trial` (windows.yml) is what there is: with PLAY_GITHUB_TOKEN naming a program that prints a GitHub token
# allowed to run workflows, a trial of main is started and waited for; without it, the step says it needs that login
# and names the latest trial run as it stands. The token reaches curl on its standard input alone.
#
# A story the `case` hands to tool/walk_idea.sh is played by it on its Linux VM, with its forge, vault and seed: --org,
# --seed, --issue-repo and --porelo-project go to it as they are, the last two naming templates the walk copies into
# repositories of the story's own name (tasks-results-foo-1), its test is the story's and its project goes without
# mail, and its environment is the walk's own (SSH_AUTH_SOCK holding the test person's key, WALK_FORGE_TOKEN,
# WALK_PROVIDER_KEY_FILE; tool/walk_idea.sh says what each is). Its report, in DIR/walk, becomes this one's; a run it
# kept after a red step is taken up or away with tool/walk_idea.sh, as it says. The walk numbers its own steps, one
# number for a doing and its reading, so its lines are taken in order for the feature's steps that note one: every
# step but `the interface is running`.
set -euo pipefail

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 64
}

[ $# -ge 1 ] || usage
mode=$1
shift
vm='' vm_key='' vm_jump='' vm_known_hosts='' vm_jump_known_hosts='' story='' report='' packages='' budget=60 expects=() walk=()
while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || usage
    case "$1" in
    --vm) vm=$2 ;;
    --vm-key) vm_key=$2 ;;
    --vm-jump) vm_jump=$2 ;;
    --vm-known-hosts) vm_known_hosts=$2 ;;
    --vm-jump-known-hosts) vm_jump_known_hosts=$2 ;;
    --story) story=$2 ;;
    --report) report=$2 ;;
    --packages) packages=$2 ;;
    --expect) expects+=("$2") ;;
    --budget-minutes) budget=$2 ;;
    --org | --seed | --issue-repo | --porelo-project | --planner) walk+=("$1" "$2") ;;
    *) usage ;;
    esac
    shift 2
done
case "$mode" in check | run) ;; *) usage ;; esac
[ -n "$story" ] || usage
[ "$mode" = check ] || [ -n "$report" ] || usage
case "$budget" in '' | *[!0-9]*) echo "play: --budget-minutes is a whole number of minutes" >&2 && exit 64 ;; esac
# Every value goes into a command line on the machine, so each is held to what it can be: no quote, no space, no option.
shaped() {
    [ -z "$2" ] || printf '%s\n' "$2" | grep -Eqx "$3" || {
        echo "play: $1 is not of the form it takes" >&2
        exit 64
    }
}
shaped --vm "$vm" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
shaped --vm-jump "$vm_jump" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
[ -n "$vm_jump" ] || [ -z "$vm_jump_known_hosts" ] || usage
shaped --story "$story" '[a-z0-9][a-z0-9_]*'
for each in "${expects[@]}"; do shaped --expect "$each" '[a-z][a-z0-9-]*=[A-Za-z0-9][A-Za-z0-9#._/-]*'; done

# Each story: the machine it is played on, what it needs there beyond what every story needs (tools, by name), and the
# repositories whose Windows build it reads, each `owner/repository[=PART]`; or that tool/walk_idea.sh plays it, and the
# part of Porelo a failure of its test leans on where a step does not say.
builds='' handed='' leans_on=''
case "$story" in
a_terminal_and_live_list)
    # The work's session is read in its container, and the clearance question raised from there.
    machine=linux needs='podman'
    ;;
the_window_and_the_planner_on_windows)
    machine=windows needs=''
    builds='porelo-ai/porelo-frontend porelo-ai/porelo-planner=planner-windows'
    ;;
forwarding_to_a_branch)
    # The forge's seed, token and branches are the walk's; forwarding to a chosen branch at GitHub is what it measures.
    machine=linux needs='' handed=walk leans_on='forward-github'
    ;;
the_planner_moves_work_on)
    # The idea walk with two issue repositories to the end of its builders, the second seeded with a fault its reader
    # blocks on; from there only the planner and the window move the work, and a task fails on a refused key.
    machine=linux needs='' handed=walk leans_on='idea-walk'
    ;;
a_tasks_results_land)
    # The idea walk up to its reading, on a seed the reader finds fault with; then the findings the planner shows, the
    # rework chosen for them and the reading that finds them worked off, and the idea a task brought back.
    machine=linux needs='' handed=walk leans_on='idea-walk'
    ;;
*)
    echo "play: no story $story here; tool/play_story.sh names each in its case" >&2
    exit 64
    ;;
esac
# A Linux story needs its VM; a Windows story is played without one as far as it goes from here.
if [ "$machine" = linux ] || [ -n "$vm" ]; then
    [ -n "$vm" ] && [ -n "$vm_key" ] || usage
    [ -r "$vm_key" ] || {
        echo "play: --vm-key $vm_key is no readable file" >&2
        exit 64
    }
fi
[ "$machine" = windows ] || [ -z "$packages" ] || usage
if [ "$machine" = windows ] && [ -n "$vm" ] && [ "$mode" = run ] && [ -z "$packages" ]; then usage; fi
if [ -n "$packages" ] && [ ! -r "$packages/SHA256SUMS" ]; then
    echo "play: --packages $packages holds no SHA256SUMS" >&2
    exit 64
fi
[ -z "$handed" ] || [ "$mode" = check ] || [ ${#walk[@]} -gt 0 ] || usage
[ -n "$handed" ] || [ ${#walk[@]} -eq 0 ] || usage

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
work=$(mktemp -d)

# The machine is reached with its own key alone: never the operator's agent, never a password asked, no display
# forwarded. Where given, through the hop --vm-jump with the same key, each with its pinned host key alone; the same
# options go on to tool/walk_idea.sh.
reach=()
for each in vm_known_hosts vm_jump_known_hosts; do
    [ -n "${!each}" ] || continue
    [ -r "${!each}" ] && [ -f "${!each}" ] || {
        echo "play: --${each//_/-} ${!each} is no readable file" >&2
        exit 64
    }
    reach+=("--${each//_/-}" "${!each}")
done
[ -z "$vm_jump" ] || reach+=(--vm-jump "$vm_jump")
ssh_options=(-o BatchMode=yes -o IdentitiesOnly=yes -i "$vm_key")
[ -z "$vm_known_hosts" ] ||
    ssh_options+=(-o "UserKnownHostsFile=$vm_known_hosts" -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes)
if [ -n "$vm_jump" ]; then
    # Read by a shell as the hop's command line: every path in it plain, no space, no quote.
    for each in "$vm_key" "$vm_jump_known_hosts"; do shaped "the path $each" "$each" '[A-Za-z0-9_./+~-]+'; done
    hop="ssh -x -o BatchMode=yes -o IdentitiesOnly=yes -o ForwardAgent=no -i $vm_key"
    [ -z "$vm_jump_known_hosts" ] ||
        hop+=" -o UserKnownHostsFile=$vm_jump_known_hosts -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes"
    ssh_options+=(-o "ProxyCommand=$hop -W %h:%p $vm_jump")
fi
on_vm() {
    env -u SSH_AUTH_SOCK SSH_ASKPASS_REQUIRE=never ssh -x "${ssh_options[@]}" "$vm" "$(in_the_login_shell "$@")"
}

# In the account's login shell, or a command meets the machine-wide porelo instead of the account's own.
in_the_login_shell() {
    printf 'exec bash -lc %q' "$*"
}

# PowerShell 7 on the Windows machine, the script handed over encoded, so no shell of either side takes it apart.
on_win() {
    local encoded
    encoded=$(printf "\$ErrorActionPreference = 'Stop'; %s" "$1" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)
    env -u SSH_AUTH_SOCK SSH_ASKPASS_REQUIRE=never ssh -x "${ssh_options[@]}" "$vm" \
        "pwsh -NoProfile -NonInteractive -EncodedCommand $encoded"
}

to_win() {
    env -u SSH_AUTH_SOCK SSH_ASKPASS_REQUIRE=never scp -q "${ssh_options[@]}" "$@"
}

# What a Linux run needs on the VM, each named; a missing one is said with the line that installs it. Reads only.
check_linux() {
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

# What a Windows run needs on the machine, each named. Reads only.
check_windows() {
    local missing
    # shellcheck disable=SC2016 # expanded on the Windows machine, not here
    missing=$(on_win '$m = @()
        foreach ($t in "tar", "git") { if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { $m += "the tool $t" } }
        $vs = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
        if (-not (Test-Path $vs) -or -not (& $vs -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)) {
            $m += "Visual Studio with the C++ desktop tools, which flutter test -d windows builds with" }
        $me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $m += "an elevated account: installing the MSIX trusts its certificate for the whole machine" }
        if (-not ((quser 2>$null) -match [regex]::Escape($env:USERNAME))) { $m += "no desktop session of $env:USERNAME: the window runs in it" }
        if (powershell.exe -NoProfile -Command "Get-AppxPackage -Name ai.porelo.frontend") { $m += "the window installed already: the play installs and removes its own" }
        foreach ($d in @(Get-ChildItem (Join-Path $HOME "play") -ErrorAction SilentlyContinue)) { $m += "a play left in $($d.FullName): take it away first" }
        $m' </dev/null) || {
        echo "play: $vm cannot be reached with $vm_key, or has no pwsh (PowerShell 7)" >&2
        return 1
    }
    missing=$(printf '%s\n' "$missing" | tr -d '\r' | sed '/^$/d')
    if [ -n "$missing" ]; then
        echo "play: $vm lacks:" >&2
        printf '%s\n' "$missing" | sed 's/^/  /' >&2
        return 1
    fi
    echo "play: $vm has what $story needs; Flutter $flutter_version is fetched there if missing"
}

# The packages given, checked here against their SHA256SUMS; what the Windows story will miss among them, said.
check_packages() {
    [ -n "$packages" ] || return 0
    (cd "$packages" && sha256sum --strict --quiet --ignore-missing -c SHA256SUMS) || {
        echo "play: what $packages holds is not what its SHA256SUMS names" >&2
        return 1
    }
    local pattern
    for pattern in 'porelo-frontend*.msix' '*.cer' 'porelo-planner*windows*.zip'; do
        compgen -G "$packages/$pattern" >/dev/null || echo "play: $packages holds no $pattern; its install step will fail" >&2
    done
}

# One call of GitHub's API, as nobody or, with the token read, as its person: the token reaches curl on its standard
# input as a config line. Prints the status; the answer's body is in $work/answer.
token=''
github() {
    local path=$1 method=${2:-GET} data=${3:-} code
    code=$({ [ -z "$token" ] || printf 'header = "Authorization: Bearer %s"\n' "$token"; } |
        curl -sS -K - -X "$method" -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' \
            ${data:+--data "$data"} -o "$work/answer" -w '%{http_code}' --max-time 60 "https://api.github.com$path") || true
    printf '%s\n' "${code:-000}"
}

# Reads a field path of the last answer, `-` where it is missing.
answered() {
    python3 -I -c 'import json, sys
try:
    value = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    value = None
for key in sys.argv[2:]:
    try:
        value = value[int(key)] if isinstance(value, list) else value[key]
    except (KeyError, IndexError, ValueError, TypeError):
        value = "-"
        break
print(value)' "$work/answer" "$@"
}

check_github() {
    [ -n "$builds" ] || return 0
    [ "$(github /rate_limit)" = 200 ] || {
        echo "play: GitHub's API does not answer from here" >&2
        return 1
    }
    echo "play: GitHub answers; $(answered resources core remaining) calls are left this hour"
}

check() {
    check_packages
    check_github
    if [ -n "$vm" ]; then
        if [ "$machine" = linux ]; then check_linux; else check_windows; fi
    else
        echo "play: no $machine machine given: the story's steps there will be named as waiting on one"
    fi
}

if [ "$mode" = check ] && [ -n "$handed" ]; then
    rm -rf "$work"
    exec "$here/tool/walk_idea.sh" check --vm "$vm" --vm-key "$vm_key" "${reach[@]}"
fi
if [ "$mode" = check ]; then
    check
    rm -rf "$work"
    exit
fi

# A story handed to the walk is checked by it.
[ -n "$handed" ] || check
[ -z "$(git -C "$here" status --porcelain --untracked-files=no)" ] || echo "play: runs HEAD; changes not committed are not in it" >&2
commit=$(git -C "$here" rev-parse --short HEAD)
stamp="$(date -u +%Y%m%dT%H%M%SZ)-$commit"
run="play/$stamp"
mkdir -p "$report"
# A report left from an earlier run would be read as this one's.
rm -f "$report/results.json" "$report/run.log" "$report/report.html" "$report/results.xml" "$report/scenarios.txt" \
    "$report/noted.txt" "$report/steps.txt" "$report/before.txt" "$report/after.txt"
rm -rf "$report/pictures" "$report/walk"
: >"$report/noted.txt"
: >"$report/before.txt"
: >"$report/after.txt"
if [ -n "${PLAY_GITHUB_TOKEN:-}" ]; then
    [ -x "$PLAY_GITHUB_TOKEN" ] && token=$("$PLAY_GITHUB_TOKEN") && [[ $token =~ ^[[:graph:]]+$ && $token != *'"'* && $token != *\\* ]] || {
        token=''
        echo "play: PLAY_GITHUB_TOKEN names no program printing a token a header can carry" >&2
        rm -rf "$work"
        exit 1
    }
fi

# Taken away on every ending: what still runs of the play on the machine, what it installed there, the run's copy.
started=''
# shellcheck disable=SC2329 # run by the trap on EXIT
cleanup() {
    local left=''
    token=''
    if [ -n "$started" ] && [ "$machine" = linux ]; then
        on_vm "if [ -f ~/$run/pid ]; then kill -TERM -- -\$(cat ~/$run/pid) 2>/dev/null || true; sleep 2; fi; rm -rf ~/$run
            rmdir ~/play 2>/dev/null || true" </dev/null || left="the run's copy ~/$run on $vm"
    elif [ -n "$started" ]; then
        on_win "if (Test-Path (Join-Path \$HOME 'play\\$stamp.ps1')) {
                & (Join-Path \$HOME 'play\\$stamp.ps1') -Mode clean -Run (Join-Path \$HOME 'play\\$stamp')
                Remove-Item (Join-Path \$HOME 'play\\$stamp.ps1') }
            Remove-Item (Join-Path \$HOME 'play') -ErrorAction SilentlyContinue" </dev/null >&2 ||
            left="the play on $vm (play\\$stamp under the account's home, its scheduled task porelo-play-$stamp, the window's package)"
    fi
    rm -rf "$work"
    if [ -n "$left" ]; then
        echo "play: the clean-up left $left; take it away there" >&2
        exit 1
    fi
}
trap cleanup EXIT

# A step of the driver's own, before the feature's or after it: `OK`, `FAIL [PART]` or `WAITING`, its words, and after
# a failure what was asked and got.
before() { printf '%s\n' "$*" | tr -d '\r' | tr '\n' ' ' | sed 's/ *$//' >>"$report/before.txt" && echo >>"$report/before.txt"; }
after() { printf '%s\n' "$*" | tr -d '\r' | tr '\n' ' ' | sed 's/ *$//' >>"$report/after.txt" && echo >>"$report/after.txt"; }

play_linux() {
    started=yes
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
    local status=0
    # In a session of its own whose number is kept, so an ending here takes the whole of it down there too; in a scope
    # of the account's user manager, as a window on a desktop is, so a podman exec of the story may move into the work's
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
}

# The story played by tool/walk_idea.sh; its report, in DIR/walk, taken up as this one's.
play_walk() {
    local status=0
    "$here/tool/walk_idea.sh" run --vm "$vm" --vm-key "$vm_key" "${reach[@]}" --report "$report/walk" --test "$story" --mail drop \
        --budget-minutes "$budget" "${walk[@]}" || status=$?
    echo "play: tool/walk_idea.sh ended with $status"
    cp "$report/walk/scenarios.txt" "$report/scenarios.txt" 2>/dev/null || true
    cp "$report/walk/steps.txt" "$report/noted.txt" 2>/dev/null || : >"$report/noted.txt"
    [ ! -d "$report/walk/pictures" ] || cp -R "$report/walk/pictures" "$report/pictures"
}

# One mode of tool/play_story_windows.ps1 on the Windows machine, its output kept in $work/guest.
guest() {
    on_win "& (Join-Path \$HOME 'play\\$stamp.ps1') -Mode $1 -Run (Join-Path \$HOME 'play\\$stamp') -Story $story \
        -Flutter $flutter_version -Minutes $budget" </dev/null >"$work/guest" 2>&1
}

said() { tail -n 3 "$work/guest" | tr -d '\r' | tr '\n' ' '; }

play_windows() {
    started=yes
    echo "play: $story at $commit to $vm, play\\$stamp under the account's home"
    git -C "$here" archive --format=zip -o "$work/src.zip" HEAD
    git -C "$here" show HEAD:tool/play_story_windows.ps1 >"$work/play.ps1"
    on_win "New-Item -ItemType Directory -Force -Path (Join-Path \$HOME 'play\\$stamp\\packages') | Out-Null" </dev/null
    to_win "$work/play.ps1" "$vm:play/$stamp.ps1"
    to_win "$work/src.zip" "$vm:play/$stamp/src.zip"
    # Only what SHA256SUMS names, with it, and checked again there.
    local files=() name
    while read -r _ name; do
        name=${name#\*}
        [ ! -f "$packages/$name" ] || files+=("$packages/$name")
    done <"$packages/SHA256SUMS"
    to_win "$packages/SHA256SUMS" "${files[@]}" "$vm:play/$stamp/packages/"
    if ! guest prepare; then
        before "FAIL the play is prepared on the Windows machine: $(said)"
        return
    fi
    if guest window; then
        before "OK the window's MSIX installs, starts and is removed again"
    else
        before "FAIL the window's MSIX installs, starts and is removed again: $(said)"
    fi
    if guest planner; then
        before "OK porelo-planner's Windows package is installed"
    else
        before "FAIL [planner-windows] porelo-planner's Windows package is installed: $(said)"
    fi
    echo "play: the window plays $story in the desktop session of $vm, at most $budget minutes"
    guest play || echo "play: the play on $vm ended badly: $(said)" >&2
    cat "$work/guest" >&2
    local each
    for each in results.json run.log noted.txt; do
        to_win "$vm:play/$stamp/$each" "$report/$each" 2>/dev/null || true
    done
    tr -d '\r' <"$report/noted.txt" >"$work/noted" && mv "$work/noted" "$report/noted.txt" || true
    to_win -r "$vm:play/$stamp/pictures" "$report/" 2>/dev/null || true
}

# The Windows build of [repository] as GitHub has it: main's latest Build and its Windows job, or, where the Build has
# none, its Windows trial.
windows_build() {
    local repository=${1%%=*} part='' code run sha url job
    [ "$1" = "$repository" ] || part="[${1#*=}] "
    local words="the Windows build of $repository is green"
    code=$(github "/repos/$repository/actions/workflows/build.yml/runs?branch=main&status=completed&per_page=1")
    [ "$code" = 200 ] || {
        after "FAIL $part$words: asked GitHub for main's latest Build; got HTTP $code"
        return
    }
    run=$(answered workflow_runs 0 id) sha=$(answered workflow_runs 0 head_sha) url=$(answered workflow_runs 0 html_url)
    code=$(github "/repos/$repository/actions/runs/$run/jobs?per_page=100")
    [ "$code" = 200 ] || {
        after "FAIL $part$words: asked GitHub for the jobs of $url; got HTTP $code"
        return
    }
    job=$(python3 -I -c 'import json, sys
jobs = [j for j in json.load(open(sys.argv[1]))["jobs"] if j["name"].split(" ")[0] == "Windows"]
print(" ".join(str(jobs[0][k]) for k in ("conclusion", "html_url")) if jobs else "")' "$work/answer")
    if [ -n "$job" ]; then
        if [ "${job%% *}" = success ]; then
            after "OK $words: the Windows job of main's Build at ${sha:0:8} (${job#* })"
        else
            after "FAIL $part$words: asked for the Windows job of main's Build at ${sha:0:8} green; got ${job%% *} (${job#* })"
        fi
        return
    fi
    windows_trial "$repository" "$part" "$words" "main's Build at ${sha:0:8} has no Windows job"
}

# The Windows trial of [repository]: one of main started and waited for where a token is given, the latest one read
# where none is.
windows_trial() {
    local repository=$1 part=$2 words=$3 why=$4 code since by
    if [ -z "$token" ]; then
        code=$(github "/repos/$repository/actions/workflows/windows.yml/runs?status=completed&per_page=1")
        local latest='no Windows trial on GitHub'
        [ "$code" != 200 ] || [ "$(answered total_count)" = 0 ] ||
            latest="its latest Windows trial ran on $(answered workflow_runs 0 head_branch) at $(answered workflow_runs 0 head_sha | cut -c1-8): $(answered workflow_runs 0 conclusion) ($(answered workflow_runs 0 html_url))"
        # A part missing is the story's to name; a login missing is this run's.
        if [ -n "$part" ]; then
            after "FAIL $part$words: $why; a Windows trial of main needs a GitHub login (PLAY_GITHUB_TOKEN), not given; $latest"
        else
            after "WAITING $words: $why; $latest; a Windows trial of main is started with PLAY_GITHUB_TOKEN: on a GitHub login"
        fi
        return
    fi
    since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    code=$(github "/repos/$repository/actions/workflows/windows.yml/dispatches" POST '{"ref":"main"}')
    [ "$code" = 204 ] || {
        after "FAIL $part$words: $why; asked GitHub to start a Windows trial of main; got HTTP $code"
        return
    }
    by=$(($(date +%s) + 3600))
    while :; do
        sleep 30
        code=$(github "/repos/$repository/actions/workflows/windows.yml/runs?event=workflow_dispatch&branch=main&per_page=1")
        if [ "$code" = 200 ] && [[ "$(answered workflow_runs 0 created_at)" > "$since" || "$(answered workflow_runs 0 created_at)" = "$since" ]] &&
            [ "$(answered workflow_runs 0 status)" = completed ]; then
            break
        fi
        [ "$(date +%s)" -lt "$by" ] || {
            after "FAIL $part$words: $why; the Windows trial of main started at $since did not end within 60 minutes"
            return
        }
    done
    if [ "$(answered workflow_runs 0 conclusion)" = success ]; then
        after "OK $words: $why; its Windows trial of main is green ($(answered workflow_runs 0 html_url))"
    else
        after "FAIL $part$words: $why; asked for its Windows trial of main green; got $(answered workflow_runs 0 conclusion) ($(answered workflow_runs 0 html_url))"
    fi
}

waiting_on=''
if [ -n "$handed" ]; then
    play_walk
elif [ "$machine" = linux ]; then
    play_linux
elif [ -n "$vm" ]; then
    play_windows
else
    waiting_on='a Windows test machine'
    before "WAITING the window's MSIX installs, starts and is removed again: on $waiting_on"
    before "WAITING porelo-planner's Windows package is installed: on $waiting_on"
fi
for each in $builds; do windows_build "$each"; done

if [ -z "$waiting_on" ] && [ -z "$handed" ]; then
    (cd "$here" && dart tool/test_report.dart "$report/results.json" "$report/report.html" "$report/results.xml" \
        --heading="The story $story played in the window" --against="$vm" --lines="$report/scenarios.txt") || true
fi

# One line per step, the driver's own before and after the feature's: from what the steps noted, each scenario's result
# for a step that noted nothing, and the parts expected missing; then the closing line. Its exit is the run's.
played=0
python3 -I - "$here/integration_test/$story.feature" "$report/noted.txt" "$report/scenarios.txt" "$story" \
    "$report/before.txt" "$report/after.txt" "$waiting_on" "$leans_on" "$handed" "${expects[@]}" >"$report/steps.txt" \
    <<'EOF' || played=$?
import re, sys

feature, noted_file, scenarios_file, story, before_file, after_file, machine, leans_on, in_order = sys.argv[1:10]
expected = dict(each.split("=", 1) for each in sys.argv[10:])
# The steps, numbered through the whole feature, each with the scenario it is in.
steps, scenario = [], ""
for line in open(feature, encoding="utf-8"):
    if m := re.match(r"\s*Scenario:\s*(.*)", line):
        scenario = m.group(1).strip()
    elif m := re.match(r"\s*(Given|When|Then|And|But)\s+(.*)", line):
        steps.append((scenario, m.group(2)))
line_shape = re.compile(r"(OK|FAIL|WAITING) (?:\[([a-z0-9-]+)\] )?(.*)")


def driver(path):
    return [m.groups() for m in (line_shape.match(line.rstrip("\n")) for line in open(path, encoding="utf-8")) if m]


before, after = driver(before_file), driver(after_file)
lines = [
    m
    for m in (
        re.match(r"(OK|FAIL|SKIPPED) (\d+) (?:\[([a-z0-9-]+)\] )?(.*)", line.rstrip("\n"))
        for line in open(noted_file, encoding="utf-8", errors="replace")
    )
    if m
]
if in_order:
    # A step taken up again from a later one was passed by an earlier attempt.
    noting = [n for n, (_, sentence) in enumerate(steps, 1) if sentence != "the interface is running"]
    # Said in the feature's words where it held; in the walk's, with what was asked and got, where it failed.
    noted = {
        n: ("OK", m[3], steps[n - 1][1]) if m[1] != "FAIL" else (m[1], m[3], m[4].removeprefix("read: "))
        for n, m in zip(noting, lines)
    }
else:
    noted = {int(m[2]): (m[1], m[3], m[4]) for m in lines if m[1] != "SKIPPED"}
try:
    results = [line.rstrip("\n") for line in open(scenarios_file, encoding="utf-8", errors="replace")]
except FileNotFoundError:
    results = []
held = bool(results) and all(line.startswith("OK ") for line in results)
why = next((line.split(None, 1)[1] for line in results if line.startswith("FAIL ")), "no result; see run.log")


# The scenario's own line of the test's result: OK, or why it failed; None where it has no line.
def result_of(name):
    for line in results:
        if name and name in line:
            return ("OK", "") if line.startswith("OK ") else ("FAIL", line.split(None, 1)[1])
    return None


failed, waiting = [], []
number = 0


# One step under the next number; a failed one EXPECTED where the part it leans on is said to be missing.
def say(result, part, words):
    global number
    number += 1
    if result == "OK":
        print(f"OK {number} {words}")
    elif result == "WAITING":
        print(f"WAITING {number} {words}")
        waiting.append(words.rsplit(": on ", 1)[1])
    elif part in expected:
        head, _, reason = words.partition(": ")
        print(f"EXPECTED {number} {head}: waits on {expected[part]}; {reason}")
        waiting.append(expected[part])
    else:
        print(f"FAIL {number} {words}")
        failed.append(number)


for each in before:
    say(*each)
for name in dict.fromkeys(scenario for scenario, _ in steps):
    numbered = [(at, sentence) for at, (s, sentence) in enumerate(steps, 1) if s == name]
    own = result_of(name) or (("OK", "") if held else ("FAIL", "no result; see run.log"))
    last = max((at for at, _ in numbered if at in noted), default=0)
    # A step that noted its failure last ended the scenario: what follows it did not run.
    unexplained = last in noted and noted[last][0] == "FAIL"
    for at, sentence in numbered:
        if machine:
            say("WAITING", None, f"{sentence}: on {machine}")
        elif at in noted:
            # A failure leans on the part its step names, or else on the story's.
            result, part, words = noted[at]
            say(result, part or leans_on, words)
        elif at < last or own[0] == "OK":
            say("OK", None, sentence)
        elif not unexplained:
            say("FAIL", leans_on, f"{sentence}: no step noted more, and the scenario failed here or after: {own[1]}")
            unexplained = True
        else:
            number += 1
            print(f"NOT RUN {number} {sentence}")
for each in after:
    say(*each)
if failed:
    print(f"STORY {story}: failed at step {failed[0]}")
    sys.exit(1)
if not machine and not held and not waiting:
    print(f"STORY {story}: failed after its steps: {why}")
    sys.exit(1)
if waiting:
    print(f"STORY {story}: waiting on {', '.join(dict.fromkeys(waiting))}")
    sys.exit(2)
print(f"STORY {story}: passed")
EOF
cat "$report/steps.txt"
exit "$played"
