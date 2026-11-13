#!/usr/bin/env bash
# Walks a real idea through the real window to its story Finished, the window running in a local VM under a virtual
# display against that VM's own porelo and the planner given, never on this computer's.
#
#   tool/walk_idea.sh check --vm USER@VM --vm-key FILE [--planner DIR]
#   tool/walk_idea.sh prepare --vm USER@VM --vm-key FILE [--planner DIR] [--porelo DIR] [--identity DIR --organization FILE]
#                             [--known-hosts FILE]
#   tool/walk_idea.sh run   --vm USER@VM --vm-key FILE --planner DIR --seed DIR --org ORG --report DIR \
#                           [--porelo-project foo-project] [--mail drop|keep] [--project NAME] [--issue-repo foo-1]... [--budget-minutes 180]
#                           [--porelo DIR] [--test walking_an_idea|a_tasks_results_land|the_planner_moves_work_on|forwarding_to_a_branch]
#                           [--snapshot NAME --revert-hook PROGRAM]
#   tool/walk_idea.sh resume --vm USER@VM --vm-key FILE --report DIR --from N
#   tool/walk_idea.sh clean  --vm USER@VM --vm-key FILE --report DIR
#   each also with [--vm-known-hosts FILE] [--vm-jump USER@HOST [--vm-jump-known-hosts FILE]]
#
# A red step keeps the run: nothing is cleaned up, the VM's state stays for a repair by hand, and the report DIR holds
# the run's state. `resume` copies this checkout's HEAD there again and walks on from step N (step 1, which opens the
# planning, always runs); `clean` takes the kept run away as a run's own ending does.
#
# `check` says what the VM lacks and changes nothing. `run` checks first, then makes the story's own repositories in ORG
# and seeds them. --porelo-project, --issue-repo and the seed's folders name templates in ORG (foo-project, foo-1,
# foo-2); the run works in repositories named for its story instead, the short form of --test before the template's name
# (tasks-results-foo-1): idea-walk for walking_an_idea, tasks-results for a_tasks_results_land, moves-on for
# the_planner_moves_work_on, forwarding for forwarding_to_a_branch. Each is made new as a copy of its template's default
# branch, for the porelo project's template, the issue repositories, the seeded ones and every repository the porelo
# project's project.yml names; in the porelo project's copy every template's name is the story's from then on, in the
# seed too. Two runs of one story never run at once: where a story's repository is in ORG already, left by a run that
# failed, or the organization lists the story's porelo project already, the run refuses to start and names it. porelo
# knows a project by the organization's entry alone: the story's porelo project is added to the organization with the
# test person as its first admin, its repository given its first commit by `porelo project create-repository` and the
# template's tree put over that, and the entry taken out again on every ending, touching no other project's. The seed
# holds one directory per repository, named for its template, whose files are written over that repository's at the same
# paths and pushed as one commit, after each repository's tip was noted as T0. A top-level <name>.diff whose first line
# is `--- <repository>/<file>` is applied to that file as it is at T0 instead of copying it, and the run stops before
# any push where it does not apply. The porelo project's repository is signed anew as the person (`porelo project sign`)
# on the pushed tip. The planner's project is the porelo project (--project defaults to the story's porelo project),
# whose own repository is the one of that name. It copies this checkout's HEAD to the VM, puts the planner of DIR first
# on the window's path and runs integration_test/walking_an_idea_test.dart there through tool/e2e.sh, and writes the
# report into DIR: one line per step (`OK` or `FAIL` with what was asked and got), a picture of the window where it
# failed, the HTML and JUnit report, and the test's own output, and probe.log: every call of the planner's probe, its
# arguments, exit code and whole output, OK or not, never a token.
#
# A VM behind another machine is reached through it: --vm-jump names that hop, reached with the same --vm-key, and
# every ssh of the run goes through it, the test person's agent forwarded to the VM alone, never to the hop.
# --vm-known-hosts and --vm-jump-known-hosts each name a file holding the pinned host key of the VM and of the hop,
# which is then the only key taken (StrictHostKeyChecking=yes). Nothing of the run needs sudo on the VM; what it lacks
# there, check says with the line an operator installs it with.
#
# `prepare` sets up what a run needs on the VM once per package state, for a snapshot of the VM to keep: porelo and
# porelod of --porelo in ~/.local/bin (the ones there kept beside as *.walk-kept), Flutter, and the pub cache of this
# checkout's pubspec.lock; with --identity DIR (the test person's card and key.pub, as porelo keeps them in
# ~/.config/porelo/identity) and --organization FILE (the organization.yml porelo follows), those two put where the VM's
# porelo reads them, never over another card; with --known-hosts FILE (github.com's host key lines), each line not there
# yet added to ~/.local/state/porelo/known_hosts, where porelo reads the forge's host key, not ~/.ssh/known_hosts. It
# names no repository, places no project and declares nothing. The package state is one short id hashed from the porelo
# of --porelo (its COMMIT and SHA256SUMS) or else the VM's own (`porelo --version`), the planner's SHA256SUMS, the
# Flutter version and pubspec.lock; it is written to ~/.walk-prepared/STATE on the VM and named in the snapshot prepare
# asks for, walk-prepared-<id>: whoever keeps the VM's snapshots takes it, the VM shut down. `run --snapshot NAME`
# starts a scenario from that snapshot: the program of --revert-hook (or WALK_REVERT_HOOK) is called with NAME alone and
# takes the VM back to it, the run then waits for the VM, and starts only where the VM's STATE is this run's package
# state, so it is given the --porelo and --planner its prepare had; nothing is installed again, porelo is not swapped.
# Everything that names the story's repositories (the project placed, the vault, the declaration, the planner's state)
# is made by the run after the revert. A `resume` never reverts: it goes on with the kept VM as it is.
#
# --mail drop, the default, applies the porelo project without its mail section; keep applies it as it is, which only a
# VM whose porelo applies a project's mail section takes: until the VM's porelo does, a walk goes without mail.
#
# --test names the integration test the window runs: walking_an_idea (the default), a_tasks_results_land and
# the_planner_moves_work_on need --planner and --seed; forwarding_to_a_branch needs neither. It has a task of the first
# --issue-repo push to its gate and the person forward it upstream at GitHub, onto a branch the script made at the
# default branch's tip and onto a new one typed: both are named for the run, so its ending deletes them; the window
# reaches GitHub with the run's token from the run's vault.
#
# DIR of --porelo, where given, holds porelo and porelod, a SHA256SUMS naming both and a COMMIT naming what they were
# built from: for the run they stand in the person's ~/.local/bin on the VM, the ones there kept beside them as
# *.walk-kept and put back on every ending, porelod restarted each time; the report names the commit. DIR of --planner
# holds porelo-planner, planner-probe.sh and SHA256SUMS naming both; nothing unchecked is copied. The test person's key
# never enters the VM: SSH_AUTH_SOCK must name an agent holding it (a throwaway one, never the operator's), forwarded
# for the run alone. WALK_FORGE_TOKEN names a program that prints the test identity's token for the forge, allowed to
# make and delete ORG's repositories: it goes on standard input alone into a vault of the run's own on the VM, and to
# GitHub's API as a curl config on standard input, never on a command line. WALK_PROVIDER_KEY_FILE names the file
# holding the OpenRouter key the tasks' agent pi signs in with: it goes from that file on standard input alone into the
# same vault, never read into this shell. Every ending takes away what the run made: the story's repositories, deleted
# whole with their branches and pull requests, the run's vault and copy on the VM; it exits non-zero naming what it
# left, a repository with the command that deletes it.
set -euo pipefail

usage() {
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 64
}

[ $# -ge 1 ] || usage
mode=$1
shift
test=walking_an_idea from=1 vm='' vm_key='' vm_jump='' vm_known_hosts='' vm_jump_known_hosts='' porelo_dir='' planner='' seed='' org='' project='' issue_repos=() porelo_project=foo-project mail=drop report='' budget=180 snapshot='' revert_hook=${WALK_REVERT_HOOK:-} identity='' organization='' known_hosts=''
while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || usage
    case "$1" in
    --vm) vm=$2 ;;
    --vm-key) vm_key=$2 ;;
    --vm-jump) vm_jump=$2 ;;
    --vm-known-hosts) vm_known_hosts=$2 ;;
    --vm-jump-known-hosts) vm_jump_known_hosts=$2 ;;
    --planner) planner=$2 ;;
    --porelo) porelo_dir=$2 ;;
    --from) from=$2 ;;
    --test) test=$2 ;;
    --seed) seed=$2 ;;
    --org) org=$2 ;;
    --project) project=$2 ;;
    --porelo-project) porelo_project=$2 ;;
    --mail) mail=$2 ;;
    --issue-repo) issue_repos+=("$2") ;;
    --report) report=$2 ;;
    --budget-minutes) budget=$2 ;;
    --snapshot) snapshot=$2 ;;
    --identity) identity=$2 ;;
    --organization) organization=$2 ;;
    --known-hosts) known_hosts=$2 ;;
    --revert-hook) revert_hook=$2 ;;
    *) usage ;;
    esac
    shift 2
done
case "$mode" in check | prepare | run | resume | clean) ;; *) usage ;; esac
shaped() {
    [ -z "$2" ] || printf '%s\n' "$2" | grep -Eqx "$3" || {
        echo "walk: $1 is not of the form it takes" >&2
        exit 64
    }
}
# The person's card and organization come with a prepare alone, both or neither.
if [ -n "$identity$organization" ]; then
    [ "$mode" = prepare ] && [ -n "$identity" ] && [ -n "$organization" ] || usage
    [ -s "$identity/card" ] && [ -s "$identity/key.pub" ] && [ -f "$organization" ] && [ -s "$organization" ] || {
        echo "walk: --identity names no folder holding card and key.pub, or --organization no file" >&2
        exit 64
    }
fi
if [ -n "$known_hosts" ]; then
    [ "$mode" = prepare ] || usage
    # Host key lines alone, at least one: they reach the VM's command line read by a shell as data.
    if [ ! -f "$known_hosts" ] || ! grep -Eqv '^[[:space:]]*(#|$)' "$known_hosts" ||
        grep -Ev '^[[:space:]]*(#|$)' "$known_hosts" |
        grep -Evq '^[^[:space:]]+ (ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/=]+$'; then
        echo "walk: --known-hosts names no file of host key lines alone" >&2
        exit 64
    fi
fi
# A scenario starts from the VM's snapshot only in a run, and only with the program that takes the VM back to it.
if [ -n "$snapshot" ]; then
    [ "$mode" = run ] || usage
    shaped --snapshot "$snapshot" '[A-Za-z0-9][A-Za-z0-9._-]{0,63}'
    [[ $snapshot != *$'\n'* ]] || usage
    case "$revert_hook" in '' | */*) ;; *) revert_hook=$(command -v -- "$revert_hook" || true) ;; esac
    [ -n "$revert_hook" ] && [ -x "$revert_hook" ] && [ -f "$revert_hook" ] || {
        echo "walk: --snapshot needs --revert-hook or WALK_REVERT_HOOK naming a program that takes the VM back to it" >&2
        exit 64
    }
fi
case "$from" in '' | *[!0-9]*) echo "walk: --from is a step's number" >&2 && exit 64 ;; esac
case "$mail" in keep | drop) ;; *) usage ;; esac
case "$test" in walking_an_idea | a_tasks_results_land | the_planner_moves_work_on | forwarding_to_a_branch) ;; *) usage ;; esac
[ -n "$vm" ] && [ -n "$vm_key" ] || usage
case "$budget" in '' | *[!0-9]*) echo "walk: --budget-minutes is a whole number of minutes" >&2 && exit 64 ;; esac
# Every task of the walk runs this agent and model: the discussion, the builder and the reader.
agent=${WALK_AGENT:-pi}
task_model=${WALK_TASK_MODEL:-z-ai/glm-5.3-flash}
task_minutes=${PORELO_WALK_TASK_MINUTES:-30}
# What ends the discussion's agent session, typed as the person would; the test's own default where unset.
agent_quit=${WALK_AGENT_QUIT:-}
case "$task_minutes" in '' | *[!0-9]*) echo "walk: PORELO_WALK_TASK_MINUTES is a whole number" >&2 && exit 64 ;; esac
# Every value goes into a command line on the VM or a URL, so each is held to what it can be (shaped, above).
shaped --vm "$vm" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
shaped --vm-jump "$vm_jump" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
# The VM's own key and, where given, the hop it is reached through and each one's pinned host key: every ssh of the
# run takes the same options, the agent's forwarding to the VM included; the hop is never given the agent.
reached=(--vm "$vm" --vm-key "$vm_key")
for each in vm_key vm_known_hosts vm_jump_known_hosts; do
    [ -n "${!each}" ] || continue
    [ -r "${!each}" ] && [ -f "${!each}" ] || {
        echo "walk: --${each//_/-} ${!each} is no readable file" >&2
        exit 64
    }
    printf -v "$each" '%s' "$(readlink -f -- "${!each}")"
done
ssh_options=(-o BatchMode=yes -o IdentitiesOnly=yes -i "$vm_key")
if [ -n "$vm_known_hosts" ]; then
    ssh_options+=(-o "UserKnownHostsFile=$vm_known_hosts" -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes)
    reached+=(--vm-known-hosts "$vm_known_hosts")
fi
if [ -n "$vm_jump" ]; then
    # Read by a shell as the hop's command line: each path in it absolute and plain, no space, no quote.
    for each in vm_key vm_jump_known_hosts; do shaped "--${each//_/-}" "${!each}" '/[A-Za-z0-9_./+-]+'; done
    hop="ssh -x -o BatchMode=yes -o IdentitiesOnly=yes -o ForwardAgent=no -i $vm_key"
    [ -z "$vm_jump_known_hosts" ] ||
        hop+=" -o UserKnownHostsFile=$vm_jump_known_hosts -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes"
    ssh_options+=(-o "ProxyCommand=$hop -W %h:%p $vm_jump")
    reached+=(--vm-jump "$vm_jump")
    [ -z "$vm_jump_known_hosts" ] || reached+=(--vm-jump-known-hosts "$vm_jump_known_hosts")
elif [ -n "$vm_jump_known_hosts" ]; then
    usage
fi
shaped --org "$org" '[A-Za-z0-9][A-Za-z0-9-]{0,38}'
# The planner and its probe take a project name in lower case alone.
shaped --project "$project" '[a-z0-9][a-z0-9._-]{0,99}'
shaped --porelo-project "$porelo_project" '[A-Za-z0-9][A-Za-z0-9._-]*'
# The repositories the story's issues are worked in, each with its builder and reader; foo-1 alone where none is named.
[ ${#issue_repos[@]} -gt 0 ] || issue_repos=(foo-1)
for each in "${issue_repos[@]}"; do shaped --issue-repo "$each" '[A-Za-z0-9][A-Za-z0-9._-]{0,99}'; done
# The story's own name for a template's repository: the short form of the story before it. A kept run reads the names
# it was given from its state.
case "$test" in
walking_an_idea) story='idea-walk' ;;
a_tasks_results_land) story='tasks-results' ;;
the_planner_moves_work_on) story='moves-on' ;;
*) story=forwarding ;;
esac
own() { printf '%s-%s\n' "$story" "$1"; }
porelo_template=$porelo_project issue_templates=("${issue_repos[@]}")
if [ "$mode" = run ]; then
    porelo_project=$(own "$porelo_template")
    issue_repos=()
    for each in "${issue_templates[@]}"; do issue_repos+=("$(own "$each")"); done
    for each in "$porelo_project" "${issue_repos[@]}"; do shaped "the story's repository" "$each" '[A-Za-z0-9][A-Za-z0-9._-]{0,99}'; done
fi
shaped WALK_AGENT "$agent" '[A-Za-z0-9][A-Za-z0-9._-]*'
shaped WALK_TASK_MODEL "$task_model" '[A-Za-z0-9][A-Za-z0-9._/:-]*'
shaped WALK_AGENT_QUIT "$agent_quit" '[/A-Za-z0-9._-]+'

here=$(cd "$(dirname "$0")/.." && pwd)
flutter_version=$(sed -n 's/^ *flutter: *\([0-9][0-9.]*\) *$/\1/p' "$here/pubspec.yaml" | head -1)
[ -n "$flutter_version" ] || {
    echo "walk: pubspec.yaml names no flutter version" >&2
    exit 1
}
flutter_dir=".cache/porelo-frontend/flutter-$flutter_version"

# The VM is reached with its own key alone: never the operator's agent, never a password asked.
on_vm() {
    env -u SSH_AUTH_SOCK SSH_ASKPASS_REQUIRE=never ssh -x "${ssh_options[@]}" "$vm" \
        "$(in_the_login_shell "$@")"
}

# The VM with the test person's agent forwarded, for the calls that reach the forge or the organization as that person.
as_the_person_on_vm() {
    SSH_ASKPASS_REQUIRE=never ssh -x -A "${ssh_options[@]}" "$vm" \
        "$(in_the_login_shell "$@")"
}

# In the account's login shell, or a command meets the machine-wide porelo instead of the account's own.
in_the_login_shell() {
    printf 'exec bash -lc %q' "$*"
}

# The planner and its probe as given, each against the digest SHA256SUMS names, both named there.
planner_checked() {
    [ -n "$planner" ] || return 0
    local file
    for file in porelo-planner planner-probe.sh; do
        [ -f "$planner/$file" ] || {
            echo "walk: $planner holds no $file" >&2
            return 1
        }
        grep -Eq "^[0-9a-f]{64} [ *]$file\$" "$planner/SHA256SUMS" 2>/dev/null || {
            echo "walk: $planner/SHA256SUMS names no digest of $file" >&2
            return 1
        }
    done
    (cd "$planner" && sha256sum --strict --quiet -c SHA256SUMS) || {
        echo "walk: what $planner holds is not what its SHA256SUMS names" >&2
        return 1
    }
}

porelo_checked() {
    [ -n "$porelo_dir" ] || return 0
    local file
    for file in porelo porelod; do
        grep -Eq "^[0-9a-f]{64} [ *]$file\$" "$porelo_dir/SHA256SUMS" 2>/dev/null || {
            echo "walk: $porelo_dir/SHA256SUMS names no digest of $file" >&2
            return 1
        }
    done
    grep -Eqx '[0-9a-f]{7,64}' "$porelo_dir/COMMIT" 2>/dev/null || {
        echo "walk: $porelo_dir/COMMIT names no commit" >&2
        return 1
    }
    (cd "$porelo_dir" && sha256sum --strict --quiet -c SHA256SUMS) || {
        echo "walk: what $porelo_dir holds is not what its SHA256SUMS names" >&2
        return 1
    }
}

# What the run needs on the VM, each named; a missing one is said with the line that installs it.
check() {
    local missing
    planner_checked
    porelo_checked
    # shellcheck disable=SC2016 # expanded on the VM, not here
    missing=$(on_vm 'for t in xvfb-run dbus-run-session clang cmake ninja pkg-config git curl jq xz python3 porelo; do
            command -v "$t" >/dev/null || echo "tool $t"
        done
        for p in libgtk-3-dev libsecret-1-dev; do dpkg -s "$p" >/dev/null 2>&1 || echo "package $p"; done
        c=${XDG_CONFIG_HOME:-$HOME/.config}/porelo
        [ -s "$c/identity/card" ] || echo "no porelo identity here: copy in the test person'"'"'s card"
        [ -s "$c/organization.yml" ] || echo "porelo follows no organization here: copy in its organization.yml"
        [ ! -x /usr/libexec/porelo/planner ] ||
            echo "a packaged planner at /usr/libexec/porelo/planner, which the window starts before the one on its path"') || {
        echo "walk: $vm cannot be reached with $vm_key" >&2
        return 1
    }
    if [ -n "$missing" ]; then
        echo "walk: $vm lacks:" >&2
        printf '%s\n' "$missing" | sed 's/^/  /' >&2
        local packages
        packages=$(printf '%s\n' "$missing" | sed -n 's/^package //p; s/^tool xvfb-run$/xvfb/p; s/^tool \(clang\|cmake\|git\|curl\|jq\)$/\1/p;
            s/^tool ninja$/ninja-build/p; s/^tool pkg-config$/pkg-config/p; s/^tool xz$/xz-utils/p; s/^tool dbus-run-session$/dbus/p' | tr '\n' ' ')
        [ -z "$packages" ] || echo "  the operator installs them there with: sudo apt install $packages" >&2
        return 1
    fi
    echo "walk: $vm has what the run needs; Flutter $flutter_version is fetched into ~/$flutter_dir if missing"
}

# Flutter of pubspec.yaml's version into the account's cache on the VM, where it is not there yet.
fetch_flutter() {
    on_vm "set -e
    if [ ! -x ~/$flutter_dir/bin/flutter ]; then
        mkdir -p ~/.cache/porelo-frontend && cd ~/.cache/porelo-frontend
        listed=\$(curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)
        line=\$(printf '%s' \"\$listed\" | python3 -I -c 'import json,sys
d=json.load(sys.stdin)
r=[r for r in d[\"releases\"] if r[\"version\"]==\"$flutter_version\" and r[\"channel\"]==\"stable\"]
print(r[0][\"archive\"], r[0][\"sha256\"]) if r else None')
        [ -n \"\$line\" ] || { echo 'walk: Flutter $flutter_version is not listed' >&2; exit 1; }
        set -- \$line
        curl -fsSL -o flutter.tar.xz \"https://storage.googleapis.com/flutter_infra_release/releases/\$1\"
        echo \"\$2  flutter.tar.xz\" | sha256sum -c --quiet
        rm -rf flutter-$flutter_version.part && mkdir flutter-$flutter_version.part
        tar -xJf flutter.tar.xz -C flutter-$flutter_version.part && rm flutter.tar.xz
        rm -rf ~/$flutter_dir && mv flutter-$flutter_version.part/flutter ~/$flutter_dir && rmdir flutter-$flutter_version.part
    fi" </dev/null
}

# The package state a prepared VM is of: one short id of the porelo given (its COMMIT) or else the VM's own, the
# planner's SHA256SUMS, the Flutter version and the pubspec.lock of this checkout's HEAD.
# A run from a snapshot is given the same --porelo and --planner as the prepare that made it, or its id differs.
state_id() {
    local porelo_part planner_part lock
    if [ -n "$porelo_dir" ]; then
        porelo_part=$(cat "$porelo_dir/COMMIT" "$porelo_dir/SHA256SUMS") || return 1
    else
        porelo_part=$(on_vm "porelo --version" </dev/null) || return 1
        porelo_part="installed $porelo_part"
    fi
    planner_part='no planner'
    [ -z "$planner" ] || planner_part=$(cat "$planner/SHA256SUMS") || return 1
    lock=$(git -C "$here" show HEAD:pubspec.lock) || return 1
    [ -n "$porelo_part" ] && [ -n "$planner_part" ] && [ -n "$lock" ] || return 1
    printf '%s\n' "$porelo_part" "$planner_part" "flutter $flutter_version" "$lock" | sha256sum | cut -c1-12
}

# What every run of this package state needs on the VM, set up once for a snapshot to keep.
prepare_vm() {
    local id
    id=$(state_id)
    [[ $id =~ ^[0-9a-f]{12}$ ]] || {
        echo "walk: the package state of $vm could not be told" >&2
        return 1
    }
    # A prepare that stops half way leaves no state a snapshot could be taken for.
    on_vm "rm -f ~/.walk-prepared/STATE; mkdir -p ~/.walk-prepared" </dev/null
    if [ -n "$porelo_dir" ]; then
        tar -C "$porelo_dir" -c porelo porelod SHA256SUMS | on_vm "rm -rf ~/.walk-prepared/porelo && mkdir -p ~/.walk-prepared/porelo && tar -x -C ~/.walk-prepared/porelo"
        on_vm "set -e; cd ~/.walk-prepared/porelo; sha256sum --strict --quiet -c SHA256SUMS; chmod 755 porelo porelod
        mkdir -p ~/.local/bin; cd ~/.local/bin
        for f in porelo porelod; do [ -f \$f.walk-kept ] || [ ! -f \$f ] || mv \$f \$f.walk-kept; cp ~/.walk-prepared/porelo/\$f \$f.walk-new; mv -f \$f.walk-new \$f; done
        systemctl --user restart porelod
        for _ in \$(seq 50); do [ -S /run/user/\$(id -u)/porelo/porelod.sock ] && break; sleep 0.2; done
        systemctl --user is-active --quiet porelod" </dev/null || {
            echo "walk: porelo of $(cat "$porelo_dir/COMMIT") could not be put in place on $vm" >&2
            return 1
        }
    fi
    if [ -n "$identity" ]; then
        # The card the forwarded agent's key must stand for; one there already is kept where it is the same, and
        # another refused: the VM's person is not changed by a walk.
        local there
        there=$(on_vm "cat ~/.config/porelo/identity/card 2>/dev/null" </dev/null || true)
        if [ -n "$there" ] && [ "$there" != "$(cat "$identity/card")" ]; then
            echo "walk: $vm holds another person's card already; it is left as it is" >&2
            return 1
        fi
        tar -C "$identity" -c card key.pub | on_vm "set -e; umask 077; mkdir -p ~/.config/porelo/identity
            chmod 700 ~/.config/porelo ~/.config/porelo/identity; tar -x --no-same-owner -C ~/.config/porelo/identity
            chmod 600 ~/.config/porelo/identity/card ~/.config/porelo/identity/key.pub"
        on_vm "set -e; umask 077; cat >~/.config/porelo/organization.yml.walk-new
            mv ~/.config/porelo/organization.yml.walk-new ~/.config/porelo/organization.yml" <"$organization"
        echo "walk: the card of $(sed -n 's/^login: *"\{0,1\}\([A-Za-z0-9-]*\).*/\1/p' "$identity/card" | head -1) and its organization are in place on $vm"
    fi
    if [ -n "$known_hosts" ]; then
        # porelo reads the forge's host key from its own state, not ~/.ssh/known_hosts: each line missing there added.
        grep -Ev '^[[:space:]]*(#|$)' "$known_hosts" | on_vm "set -e; umask 077; mkdir -p ~/.local/state/porelo
            f=~/.local/state/porelo/known_hosts; touch \$f
            while IFS= read -r line; do grep -qxF -- \"\$line\" \$f || printf '%s\\n' \"\$line\" >>\$f; done"
        echo "walk: the host keys of $known_hosts are in porelo's known_hosts on $vm"
    fi
    fetch_flutter
    # The pub cache of this checkout's packages, so a run's build fetches none of them.
    git -C "$here" archive --format=tar HEAD pubspec.yaml pubspec.lock packages |
        on_vm "set -e; rm -rf ~/.walk-prepared/pub; mkdir -p ~/.walk-prepared/pub; tar -x -C ~/.walk-prepared/pub
        cd ~/.walk-prepared/pub; PATH=\$HOME/$flutter_dir/bin:\$PATH flutter --suppress-analytics pub get >/dev/null
        PATH=\$HOME/$flutter_dir/bin:\$PATH flutter --suppress-analytics precache --linux >/dev/null" || {
        echo "walk: the packages of pubspec.lock could not be fetched on $vm" >&2
        return 1
    }
    on_vm "printf '%s\\n' '$id' >~/.walk-prepared/STATE" </dev/null
    echo "walk: $vm is prepared for the package state $id"
    echo "walk: take its snapshot walk-prepared-$id now, the VM shut down; a run starts from it with --snapshot walk-prepared-$id"
}

if [ "$mode" = check ]; then
    check
    exit
fi
if [ "$mode" = prepare ]; then
    # What check asks for that prepare brings is not missing for it.
    check || [ -n "$identity" ]
    prepare_vm
    check
    exit
fi

[ -n "$report" ] || usage
if [ "$mode" = run ] && { [ -z "$org" ] || { [ "$test" != forwarding_to_a_branch ] && { [ -z "$planner" ] || [ -z "$seed" ]; }; }; }; then
    usage
fi
[ "$mode" = run ] || [ -f "$report/state.sh" ] || {
    echo "walk: $report holds no kept run to $mode" >&2
    exit 1
}
# The repositories to seed, each a directory of the seed named as the repository is.
seeded=()
[ "$mode" != run ] || [ -z "$seed" ] || for each in "$seed"/*/; do
    [ -d "$each" ] || continue
    each=$(basename "$each")
    shaped "the seed's directory" "$each" '[A-Za-z0-9][A-Za-z0-9._-]{0,99}'
    seeded+=("$each")
done
[ "$mode" != run ] || [ "$test" = forwarding_to_a_branch ] || [ ${#seeded[@]} -gt 0 ] || {
    echo "walk: $seed holds no directory named for a repository to seed" >&2
    exit 1
}
[ -n "${WALK_FORGE_TOKEN:-}" ] && [ -x "$WALK_FORGE_TOKEN" ] || {
    echo "walk: WALK_FORGE_TOKEN names no program printing the forge's token" >&2
    exit 1
}
[ "$mode" != run ] || { [ -n "${WALK_PROVIDER_KEY_FILE:-}" ] && [ -r "$WALK_PROVIDER_KEY_FILE" ] && [ -s "$WALK_PROVIDER_KEY_FILE" ]; } || {
    echo "walk: WALK_PROVIDER_KEY_FILE names no readable file holding the OpenRouter key" >&2
    exit 1
}
if [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l >/dev/null 2>&1; then
    echo "walk: SSH_AUTH_SOCK names no agent holding the test person's key" >&2
    exit 1
fi
if [ -n "$snapshot" ]; then
    # The scenario starts from the prepared VM: taken back by whoever keeps its snapshots, then waited for.
    echo "walk: $vm is taken back to its snapshot $snapshot"
    # A mark the snapshot cannot hold: gone only once the VM is truly taken back, not just answering as it was.
    on_vm "mkdir -p ~/.walk-prepared && date +%s%N >~/.walk-revert-mark" </dev/null || {
        echo "walk: $vm cannot be marked before its revert" >&2
        exit 1
    }
    "$revert_hook" "$snapshot" </dev/null || {
        echo "walk: $revert_hook could not take $vm back to $snapshot" >&2
        exit 1
    }
    reverted=''
    ssh_options+=(-o ConnectTimeout=10 -o ServerAliveInterval=10)
    for _ in $(seq 60); do
        if on_vm "test ! -e ~/.walk-revert-mark" </dev/null >/dev/null 2>&1; then
            reverted=yes
            break
        fi
        sleep 5
    done
    [ -n "$reverted" ] || {
        echo "walk: $vm is not back at $snapshot within about ten minutes" >&2
        exit 1
    }
fi
check
if [ -n "$snapshot" ]; then
    prepared=$(on_vm "cat ~/.walk-prepared/STATE 2>/dev/null" </dev/null || true)
    wanted=$(state_id) || wanted=''
    [[ $wanted =~ ^[0-9a-f]{12}$ ]] || wanted=''
    [ -n "$wanted" ] && [ "$prepared" = "$wanted" ] || {
        echo "walk: $vm at $snapshot is prepared for the package state '${prepared}', this run's is '${wanted}': give the run its prepare's --porelo and --planner, or prepare anew" >&2
        exit 1
    }
fi
[ -z "$(git -C "$here" status --porcelain --untracked-files=no)" ] || echo "walk: runs HEAD; changes not committed are not in it" >&2
commit=$(git -C "$here" rev-parse --short HEAD)
name="walk-$(date -u +%Y%m%d-%H%M%S)-$commit"
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
project=${project:-$porelo_project}
# Names a folder of the planner's state the ending removes: a name only, never a path or a dot.
[[ $project =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && $project != *..* ]] || {
    echo "walk: --project must be a project's name, got '$project'" >&2
    exit 2
}
run="walk/$name"
mkdir -p "$report"
# A report left from an earlier run would be read as this one's.
rm -f "$report/results.json" "$report/run.log" "$report/report.html" "$report/results.xml" "$report/scenarios.txt" \
    "$report/steps.txt" "$report/probe.log"
rm -rf "$report/pictures"

# Read once and kept in this shell alone, for the vault and for the forge's API in the set-up and the clean-up.
token=$("$WALK_FORGE_TOKEN") || {
    echo "walk: the forge token program failed" >&2
    exit 1
}
[[ $token =~ ^[[:graph:]]+$ && $token != *'"'* && $token != *\\* ]] || {
    echo "walk: the forge token program gave nothing a header can carry" >&2
    exit 1
}
# The answers of the forge's API, never the token; gone with the clean-up.
work=$(mktemp -d)

# The seed is copied, its templates' names made the story's below; the given folder is never changed. A story's own
# seed in this checkout, tool/walk-seeds/<test>, is written over the seed given: what its test needs of the
# repositories beyond the shared seed, such as a fault its reader is bound to find. Its folders carry the templates'
# names: a foo-project folder there holds the work rules only for the default --porelo-project foo-project, and a walk
# under another project name finds them not.
if [ "$mode" = run ] && [ -n "$seed" ]; then
    mkdir "$work/seed"
    cp -R "$seed/." "$work/seed/"
    seed=$work/seed
    if [ -d "$here/tool/walk-seeds/$test" ]; then
        cp -R "$here/tool/walk-seeds/$test/." "$seed/"
        for each in "$seed"/*/; do
            each=$(basename "$each")
            case " ${seeded[*]} " in *" $each "*) ;; *) seeded+=("$each") ;; esac
        done
        echo "walk: the seed of $test from tool/walk-seeds is written over the one given"
    fi
fi
# Every template's name, where it stands alone, made the story's: in a file of the folders or files named, never in
# .git, a file that is not text left as it is. Run here on the seed and on the VM on the porelo project's copy.
cat >"$work/rename.py" <<'EOF'
import os, re, sys
prefix, names, paths = sys.argv[1], sys.argv[2].split(), sys.argv[3:]
alone = re.compile(r"(?<![A-Za-z0-9_-])(" + "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True)) +
                   r")(?![A-Za-z0-9_-])")
def files(path):
    if not os.path.isdir(path):
        yield path
        return
    for root, folders, names_there in os.walk(path):
        folders[:] = [f for f in folders if f != ".git"]
        for each in names_there:
            yield os.path.join(root, each)
for path in paths:
    for file in files(path):
        if os.path.islink(file) or not os.path.isfile(file):
            continue
        data = open(file, "rb").read()
        if b"\0" in data:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        renamed = alone.sub(lambda m: prefix + m[1], text)
        if renamed != text:
            open(file, "w", encoding="utf-8").write(renamed)
EOF

# One call of GitHub's API: the token reaches curl on its standard input as a config line. Prints the status; the
# answer's body is in $work/answer.
# shellcheck disable=SC2329 # run by cleanup, on the EXIT trap
github() {
    local method=$1 path=$2 data=${3:-} code
    code=$(printf 'header = "Authorization: Bearer %s"\n' "$token" |
        curl -sS -K - -X "$method" -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' \
            ${data:+--data "$data"} -o "$work/answer" -w '%{http_code}' --max-time 60 "https://api.github.com$path") || true
    printf '%s\n' "${code:-000}"
}

# The token's person, whose name the planner's commits carry: the run's git configuration hides the account's own.
[ "$(github GET /user)" = 200 ] && login=$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["login"])' \
    "$work/answer") && [[ $login =~ ^[A-Za-z0-9-]+$ ]] || {
    echo "walk: the forge does not name the token's person" >&2
    rm -rf "$work"
    exit 1
}

# Whether the organization, read anew, lists the porelo project: yes, no, or nothing where it cannot be asked.
in_the_organization() {
    local with=''
    # The run's vault once it has one, also where a project still placed moved it beside the run.
    [ -z "${in_vault:-}" ] ||
        with="v=\$HOME/$run/vault/vault.bin; [ -f \$v ] || v=\$HOME/$run.vault/vault.bin; PORELO_VAULT=\$v "
    as_the_person_on_vm "${with}porelo org --json --refresh" </dev/null 2>/dev/null | python3 -I -c 'import json, sys
print("yes" if any(p.get("project") == sys.argv[1] for p in json.load(sys.stdin)["projects"]) else "no")' "$porelo_project" ||
        true
}

# The templates the story's repositories are copied from, each with its default branch and whether it is private: the
# porelo project's, every repository its project.yml names, the issue repositories and the seeded ones. None of the
# story's own may be there yet: one left by a failed run is named with what deletes it, and nothing is made.
templates=()
declare -A branch_of_template=() private_of_template=()
if [ "$mode" = run ]; then
    refused() {
        echo "walk: $*" >&2
        rm -rf "$work"
        exit 1
    }
    [ "$(github GET "/repos/$org/$porelo_template/contents/project.yml")" = 200 ] ||
        refused "$org/$porelo_template holds no project.yml to name its repositories"
    named=$(python3 -I -c 'import base64, json, re, sys
text = base64.b64decode(json.load(open(sys.argv[1]))["content"]).decode()
block = re.search(r"(?m)^repositories:[ \t]*\n((?:[ \t]+.*\n?|[ \t]*\n)*)", text)
lines = [line for line in (block[1] if block else "").split("\n") if line.strip() and not line.strip().startswith("#")]
indent = len(lines[0]) - len(lines[0].lstrip()) if lines else 0
for line in lines:
    key = re.match(r"([A-Za-z0-9][A-Za-z0-9._-]*)[ \t]*:", line[indent:])
    if len(line) - len(line.lstrip()) == indent and key:
        print(key[1])' "$work/answer") || refused "the project.yml of $org/$porelo_template could not be read"
    for each in "$porelo_template" $named "${issue_templates[@]}" "${seeded[@]}"; do
        case " ${templates[*]} " in *" $each "*) ;; *) templates+=("$each") ;; esac
    done
    there=()
    for each in "${templates[@]}"; do
        shaped "the story's repository" "$(own "$each")" '[A-Za-z0-9][A-Za-z0-9._-]{0,99}'
        [ "$(github GET "/repos/$org/$each")" = 200 ] || refused "$org/$each is no template the token can read"
        read -r "branch_of_template[$each]" "private_of_template[$each]" < <(python3 -I -c 'import json, sys
answer = json.load(open(sys.argv[1]))
print(answer["default_branch"], "true" if answer["private"] else "false")' "$work/answer")
        shaped "the default branch of $each" "${branch_of_template[$each]}" '[A-Za-z0-9][A-Za-z0-9._/-]*'
        case $(github GET "/repos/$org/$(own "$each")") in
        404) ;;
        200) there+=("$(own "$each")") ;;
        *) refused "whether $org/$(own "$each") is there could not be asked" ;;
        esac
    done
    case $(in_the_organization) in
    no) ;;
    yes) refused "the organization lists $porelo_project already, left by a run of $test that failed or is kept; take it out" \
        "with: porelo org project remove $porelo_project (as the test person on $vm), and delete its repository" ;;
    *) refused "whether the organization lists $porelo_project could not be asked on $vm" ;;
    esac
    if [ ${#there[@]} -gt 0 ]; then
        echo "walk: the story's repositories are in $org already, left by a run of $test that failed or is kept; nothing is made" >&2
        echo "walk: where its report DIR is kept, tool/walk_idea.sh clean ${reached[*]} --report DIR takes them away; else:" >&2
        for each in "${there[@]}"; do echo "  gh repo delete $org/$each --yes" >&2; done
        rm -rf "$work"
        exit 1
    fi
    # The seed under the story's names: its folders, its diffs' paths and hunks and the porelo project's files.
    if [ -n "$seed" ]; then
        python3 -I "$work/rename.py" "$story-" "${templates[*]}" "$seed"/*.diff "$seed/$porelo_template" ||
            refused "the seed could not be named for the story"
        renamed=()
        for each in "${seeded[@]}"; do
            mv "$seed/$each" "$seed/$(own "$each")"
            renamed+=("$(own "$each")")
        done
        seeded=("${renamed[@]}")
    fi
fi

# Taken away on every ending, in this order: what still runs of the window's part and the planner it started, the
# planner's own state of the project as it stood before the run, the run's tasks, the story's repositories the run
# made, the forge's token and its declaration, porelod's agent put back, the run's copy.
porelo_commit='' swapped='' pointed='' agent_before='' holder='' central_match='' vault='' declared='' taken='' planned=''
# Whether the planner's project is the story's porelo project the run made: its planner state and cache are then the
# story's alone, taken away before the planner starts and on every ending, never kept or put back.
own_planner=''
# The tasks of the porelo project porelod listed before the run began: never the run's. Only once that list was taken
# (before_known) is any task porelod lists counted as the run's.
before_tasks='' before_known=''
# Each noted repository's default branch and its tip at T0, by name.
declare -A branch_of=() t0_of=()
# The story's repositories this run made, deleted on its ending: never one it did not make.
created=()
# Whether the run asked the organization for the story's project, and the person who is its first admin.
org_added='' person=''
left=()
# A kept run is taken up again as it was left; a red step keeps it so.
kept=''
if [ "$mode" != run ]; then
    # shellcheck source=/dev/null
    . "$report/state.sh"
fi
# shellcheck disable=SC2329
cleanup() {
    if [ -n "$kept" ]; then
        # Only the window's part goes; the state stays for a repair by hand and the next step.
        on_vm "if [ -f ~/$run/pid ]; then kill -TERM -- -\$(cat ~/$run/pid) 2>/dev/null || true; fi" </dev/null || true
        [ -z "$holder" ] || kill "$holder" 2>/dev/null || true
        token=''
        rm -rf "$work"
        echo "walk: the run is kept on $vm as ~/$run; go on with: tool/walk_idea.sh resume ${reached[*]} --report $report --from <step>" >&2
        echo "walk: or take it away with: tool/walk_idea.sh clean ${reached[*]} --report $report" >&2
        return
    fi
    on_vm "if [ -f ~/$run/pid ]; then kill -TERM -- -\$(cat ~/$run/pid) 2>/dev/null || true; fi
        for p in /proc/[0-9]*; do
            [ \"\$(readlink \$p/exe 2>/dev/null)\" != \$HOME/$run/bin/porelo-planner ] || kill -TERM \${p#/proc/} 2>/dev/null || true
        done" </dev/null || true
    if [ -n "$planned" ]; then
        # The planner keeps a project's runs in its own state, by story: a later run's story of the same name would
        # take over this run's ended work. Put back once the run's planner is gone, which ends within its stop.
        on_vm "set -e; for _ in \$(seq 50); do
                gone=yes; for p in /proc/[0-9]*; do [ \"\$(readlink \$p/exe 2>/dev/null)\" != \$HOME/$run/bin/porelo-planner ] || gone=''; done
                [ -z \"\$gone\" ] || break; sleep 0.2; done
            [ -n \"\$gone\" ]
            [ -z '$own_planner' ] || exit 0
            mkdir -p ~/.local/state/porelo-planner; cd ~/.local/state/porelo-planner; rm -rf -- '$project'
            if [ -f ~/$run.planner-state.tar ]; then tar -xf ~/$run.planner-state.tar; fi
            rm -f ~/$run.planner-state.tar" </dev/null ||
            left+=("the planner's state of $project on $vm (~/.local/state/porelo-planner/$project; before the run: ~/$run.planner-state.tar)")
    fi
    local tasks='' listed='' each
    # The tasks the window noted, and every task of the project porelod lists now that was not there before the
    # window's part: one the window started after it last looked, such as a reader of a rework, or in a resume.
    if [ -n "$before_known" ]; then
        for each in $(project_tasks); do
            case " $before_tasks " in *" $each "*) ;; *) listed+="$each " ;; esac
        done
    fi
    tasks=$({ on_vm "cat ~/$run/tasks.txt 2>/dev/null" </dev/null || true; printf '%s\n' "$listed"; } | tr ' ' '\n' |
        grep -Ex '[A-Za-z0-9][A-Za-z0-9._-]{2,}' | sort -u || true)
    if [ -n "$taken" ]; then
        # Judged by what porelod lists afterwards: the clear's exit also counts what it could not reach of the run's vault.
        # The project is the run's alone, so a task of it still up (a discussion nobody ended) goes with it.
        as_the_person_on_vm "${in_vault:-}porelo project clear --yes --force '$porelo_project'" </dev/null >/dev/null 2>&1 || true
        if [ "$(placed)" = True ]; then
            # The project's deploy keys are in the run's vault: kept beside the run, a later clear can still forget them.
            on_vm "mv ~/$run/vault ~/$run.vault" </dev/null >/dev/null 2>&1 || true
            left+=("$porelo_project placed on $vm (PORELO_VAULT=~/$run.vault/vault.bin porelo project clear --yes --force $porelo_project there)")
        fi
    fi
    # A task the window noted that the project's clear did not take (a project placed before the run is not cleared):
    # stopped and removed by its name.
    for each in $tasks; do
        as_the_person_on_vm "if porelo task list | awk 'NR > 1 {print \$1}' | grep -qx -- '$each'; then
                porelo task stop -- '$each' >/dev/null 2>&1; porelo task remove --force -- '$each' >/dev/null; fi" </dev/null ||
            left+=("the task $each on $vm (porelo task remove --force $each there)")
    done
    # The story's project out of the organization, where it is listed there: the run added it, as its start found it not.
    if [ -n "$org_added" ]; then
        case $(in_the_organization) in
        yes)
            # With the run's forge token, which the organization is read with: from the run's vault, also where a
            # project still placed moved it beside the run, and while the declaration naming it stands. Asked again
            # under the same id, which answers a change made already, before it is given up.
            local said='' try removed=''
            for try in 1 2 3; do
                if said=$(as_the_person_on_vm "v=\$HOME/$run/vault/vault.bin; [ -f \$v ] || v=\$HOME/$run.vault/vault.bin
                    PORELO_VAULT=\$v porelo org project remove --id '$name-org-remove' '$porelo_project' 2>&1" </dev/null); then
                    removed=yes
                    break
                fi
                [ "$try" = 3 ] || sleep 10
            done
            if [ -n "$removed" ]; then
                echo "walk: $porelo_project is taken out of the organization" >&2
            else
                left+=("$porelo_project in the organization, which said: $(printf '%s' "$said" | tr -s '\n' ' ' | cut -c1-300)" \
                    "(porelo org project remove $porelo_project, as the test person on $vm with the forge token declared)")
            fi
            ;;
        no) ;;
        *) left+=("whether $porelo_project is in the organization could not be asked (porelo org project remove $porelo_project)") ;;
        esac
    fi
    # Deleted whole, with every branch, pull request and commit of the run in them.
    for each in "${created[@]}"; do
        case $(github DELETE "/repos/$org/$each") in
        204 | 404) ;; *) left+=("the repository $org/$each (gh repo delete $org/$each --yes)") ;;
        esac
    done
    # The planner's state and cache of the story's project, once its repositories are gone: a later run of the story
    # makes them anew under the same names, and would read this run's as its own.
    if [ -n "$own_planner" ]; then
        on_vm "rm -rf -- ~/.local/state/porelo-planner/'$project' ~/.cache/porelo-planner/'$project'" </dev/null ||
            left+=("the planner's state and cache of $project on $vm" \
                "(~/.local/state/porelo-planner/$project, ~/.cache/porelo-planner/$project)")
    fi
    if [ -n "$declared" ]; then
        as_the_person_on_vm "porelo credentials forget '$central_match'" </dev/null >/dev/null 2>&1 ||
            left+=("the declaration of $central_match on $vm (porelo credentials forget there)")
    fi
    if [ -n "$vault" ]; then
        on_vm "PORELO_VAULT=$vault porelo vault lock" </dev/null >/dev/null 2>&1 || true
    fi
    if [ -n "$swapped" ]; then
        # The kept ones go back over the run's; porelod is restarted on them below, or here where nothing else does.
        on_vm "set -e; cd ~/.local/bin; for f in porelo porelod; do [ ! -f \$f.walk-kept ] || mv -f \$f.walk-kept \$f; done
            [ -n '$pointed' ] || systemctl --user restart porelod" </dev/null ||
            left+=("porelo and porelod of $porelo_commit in ~/.local/bin on $vm (the *.walk-kept ones there go back)")
    fi
    if [ -n "$pointed" ]; then
        on_vm "systemctl --user unset-environment PORELO_VAULT; if [ -n '$agent_before' ]; then systemctl --user set-environment SSH_AUTH_SOCK='$agent_before'
            else systemctl --user unset-environment SSH_AUTH_SOCK; fi; systemctl --user restart porelod" </dev/null ||
            left+=("porelod on $vm still pointed at the person's agent (restart it there)")
    fi
    [ -z "$holder" ] || kill "$holder" 2>/dev/null || true
    on_vm "if [ -f ~/$run/agent.pid ]; then kill -TERM \$(cat ~/$run/agent.pid) 2>/dev/null || true; fi; rm -rf ~/$run" \
        </dev/null || left+=("the run's copy ~/$run on $vm")
    token=''
    rm -rf "$work"
    if [ ${#left[@]} -gt 0 ]; then
        echo "walk: the clean-up left:" >&2
        printf '  %s\n' "${left[@]}" >&2
        exit 1
    fi
}

# Signs the porelo project's project.yml anew on [base] as the person, its admin, whose card key is the forwarded one.
sign_the_project() {
    # Refused here rather than by shaped, whose exit would cut the clean-up short.
    printf '%s\n' "$1" | grep -Eqx '[0-9a-f]{40,64}' || return 1
    as_the_person_on_vm "${in_vault:-}porelo project sign '$porelo_project' --yes --base '$1'" </dev/null >&2
}

# Notes the repository's default branch and tip as its T0, read through the forwarded agent before the run touches it.
note_t0() {
    local repository=$1 heads branch t0
    heads=$(as_the_person_on_vm "git ls-remote --symref 'git@github.com:$org/$repository.git' HEAD" </dev/null) || {
        echo "walk: $org/$repository cannot be read from $vm with the test person's key" >&2
        exit 1
    }
    branch=$(printf '%s\n' "$heads" | sed -n 's|^ref: refs/heads/\([^[:space:]]*\)[[:space:]]*HEAD$|\1|p')
    t0=$(printf '%s\n' "$heads" | awk '$2 == "HEAD" && $1 ~ /^[0-9a-f]{40,64}$/ {print $1}')
    shaped "the default branch of $repository" "$branch" '[A-Za-z0-9][A-Za-z0-9._/-]*'
    [ -n "$branch" ] && [ -n "$t0" ] || {
        echo "walk: $org/$repository answers no default branch and tip" >&2
        exit 1
    }
    branch_of[$repository]=$branch
    # From here on every ending takes the repository back to this tree.
    t0_of[$repository]=$t0
    echo "walk: $org/$repository stands at $t0 on $branch (T0, $since)"
}

# The seed's files written over the repository's clone on the VM and committed there, nothing pushed yet; a file a
# diff of the seed names is not copied but that diff applied to the file as it is at T0.
prepare_seed() {
    local repository=$1 branch=${branch_of[$1]} diff path file
    as_the_person_on_vm "set -e; mkdir -p ~/$run/seed; cd ~/$run/seed
        git clone -q --depth 1 --branch '$branch' 'git@github.com:$org/$repository.git' '$repository'" </dev/null >&2 || {
        echo "walk: $org/$repository could not be cloned on $vm" >&2
        exit 1
    }
    tar -C "$seed/$repository" -c . | on_vm "mkdir -p ~/$run/seed/$repository.files && tar -x -C ~/$run/seed/$repository.files"
    for diff in "${diffs[@]}"; do
        path=$(diff_target "$diff")
        [ "${path%%/*}" = "$repository" ] || continue
        file=${path#*/}
        on_vm "cat ~/$run/seed/'$repository/$file'" </dev/null >"$work/t0" || {
            echo "walk: $org/$repository holds no $file at T0 for $(basename "$diff") to apply to" >&2
            exit 1
        }
        python3 -I - "$diff" "$work/t0" >"$work/applied" <<'EOF' || exit 1
import re, sys
# A hunk is headed by the YAML path it is under (`@@ repositories.foo-1:`): its context and removed lines must stand
# under that path, first after it; its context and added lines replace them there.
hunks, hunk = [], None
for line in open(sys.argv[1]).read().splitlines():
    if line.startswith(("--- ", "+++ ")):
        continue
    if line.startswith("@@"):
        hunk = {"name": line, "path": line[2:].strip().rstrip(":").split("."), "old": [], "new": []}
        hunks.append(hunk)
        continue
    if hunk is None or line[:1] not in (" ", "-", "+"):
        sys.exit(f"walk: {sys.argv[1]}: {line!r} is no line of a hunk")
    if line[:1] in " -":
        hunk["old"].append(line[1:])
    if line[:1] in " +":
        hunk["new"].append(line[1:])
lines = open(sys.argv[2]).read().split("\n")
for hunk in hunks:
    start = 0
    for key in hunk["path"]:
        found = [i for i in range(start, len(lines)) if re.match(r"\s*" + re.escape(key) + r"\s*:", lines[i])]
        if not found:
            sys.exit(f"walk: {sys.argv[1]} does not apply to the file at T0: no {key} under {hunk['name']}")
        start = found[0]
    n = len(hunk["old"])
    at = [i for i in range(start, len(lines) - n + 1) if n and lines[i:i + n] == hunk["old"]]
    if not at:
        sys.exit(f"walk: {sys.argv[1]} does not apply to the file at T0: {hunk['name']} has not its context there")
    lines[at[0]:at[0] + n] = hunk["new"]
sys.stdout.write("\n".join(lines))
EOF
        if [ "$mail" = drop ] && [ "$path" = "$porelo_project/project.yml" ]; then
            # A laptop names no homeserver of its own for an organization's project: the run's project goes without mail.
            python3 -I -c 'import re, sys
text = open(sys.argv[1]).read()
sys.stdout.write(re.sub(r"(?m)^mail:\n(?:[ \t].*\n?|\n)*", "", text))' "$work/applied" >"$work/no-mail"
            mv "$work/no-mail" "$work/applied"
        fi
        on_vm "cat >~/$run/seed/'$repository.files/$file'" <"$work/applied"
    done
    as_the_person_on_vm "set -e; cd ~/$run/seed; cp -R '$repository.files/.' '$repository/'; cd '$repository'; git add -A
        git -c user.name='Porelo walk' -c user.email=walk@example.org commit -q --allow-empty -m 'Seed the walk $name'" \
        </dev/null >&2 || {
        echo "walk: the seed could not be committed to $org/$repository on $vm" >&2
        exit 1
    }
}

# The commands that take a template's clone on the VM back to before a walk that seeds the template itself and is not
# over yet (one of the scripts before the story's own repositories): from the tip back, a `Seed the walk` commit met
# before a `Restore the tree before the walk` one is such a walk's, and its parent the template as it was before it.
# shellcheck disable=SC2016 # expanded on the VM, not here
before_a_walk() {
    printf '%s' "b=\$(git -C $1 log --first-parent --format='%H %s' | awk '!d && /^[0-9a-f]+ Restore the tree before the walk / {d=1} !d && /^[0-9a-f]+ Seed the walk / {print \$1; d=1}')
            if [ -n \"\$b\" ] && git -C $1 rev-parse -q --verify \"\$b^\" >/dev/null; then git -C $1 checkout -q --detach \"\$b^\"
                echo \"walk: $2 is seeded by a walk not over yet; taken as before it, at \$(git -C $1 rev-parse HEAD)\" >&2; fi"
}

# The story's repository of the template named, made new in the organization and filled with the template's default
# branch as it is; in the porelo project's copy every template's name is made the story's in one commit. Noted as made
# at once, so every ending deletes it.
make_repository() {
    local template=$1 repository branch=${branch_of_template[$1]} status
    repository=$(own "$template")
    status=$(github POST "/orgs/$org/repos" "{\"name\": \"$repository\", \"private\": ${private_of_template[$template]}, \"auto_init\": false, \"description\": \"The walk $name of $test, a copy of $template; deleted at its end\"}")
    if [ "$status" != 201 ]; then
        # No answer, or the forge's own fault, may still have made it: taken as the run's only where it carries this
        # run's description, never one of that name made by anyone else.
        if [[ $status == 000 || $status == 5?? ]] && [ "$(github GET "/repos/$org/$repository")" = 200 ] &&
            [ "$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1])).get("description") or "")' "$work/answer" |
                cut -c1-$((${#name} + 12)))" = "The walk $name of" ]; then
            created+=("$repository")
        fi
        echo "walk: $org/$repository could not be made ($status)" >&2
        exit 1
    fi
    created+=("$repository")
    if [ "$template" = "$porelo_template" ]; then
        # porelo knows a project by the organization's entry alone, and files its address only for a repository it
        # filled first: the entry is added with the person as its first admin, porelo's first signed commit made in
        # the still empty repository on main, and the template's tree put over it in one commit. Noted once it was
        # added, so every ending takes the entry out again; an add that failed is retried once under its id, and an
        # entry listed after all is named, never taken out: it may be another's.
        as_the_person_on_vm "${in_vault}porelo org project add --id '$name-org-add' --admin='$person' '$repository' >/dev/null ||
            ${in_vault}porelo org project add --id '$name-org-add' --admin='$person' '$repository' >/dev/null" </dev/null >&2 || {
            [ "$(in_the_organization)" != yes ] ||
                left+=("$repository in the organization (porelo org project remove $repository, as the test person on $vm)")
            echo "walk: $repository could not be added to the organization on $vm" >&2
            exit 1
        }
        org_added=yes
        as_the_person_on_vm "set -e; ${in_vault}porelo project create-repository --id '$name-repository' --review optional '$repository' >/dev/null
            ${in_vault}porelo org --refresh >/dev/null" </dev/null >&2 || {
            echo "walk: $repository could not be given its repository by porelo on $vm" >&2
            exit 1
        }
        as_the_person_on_vm "set -eo pipefail; d=~/$run/fill/$repository; t=~/$run/fill/$repository.template; rm -rf \$d \$t
            git clone -q --branch main 'git@github.com:$org/$repository.git' \$d
            git clone -q --single-branch --branch '$branch' 'git@github.com:$org/$template.git' \$t
            $(before_a_walk "\$t" "$template")
            git -C \$d rm -rq --ignore-unmatch -- .
            git -C \$t archive --format=tar HEAD | tar -x -C \$d" </dev/null >&2 || {
            echo "walk: $org/$template could not be put over $org/$repository on $vm" >&2
            exit 1
        }
    else
        as_the_person_on_vm "set -e; d=~/$run/fill/$repository; rm -rf \$d
            git clone -q --single-branch --branch '$branch' 'git@github.com:$org/$template.git' \$d
            $(before_a_walk "\$d" "$template")" </dev/null >&2 || {
            echo "walk: $org/$template could not be cloned on $vm" >&2
            exit 1
        }
    fi
    if [ "$template" = "$porelo_template" ]; then
        # shellcheck disable=SC2015 # either failing stops the run
        on_vm "cd ~/$run/fill/'$repository' && python3 -I - '$story-' '${templates[*]}' ." <"$work/rename.py" >&2 &&
            on_vm "set -e; cd ~/$run/fill/'$repository'; git add -A; git diff --cached --quiet ||
                git -c user.name='Porelo walk' -c user.email=walk@example.org commit -q -m 'Take the template $template for the walk $name'" \
                </dev/null >&2 || {
            echo "walk: the copy of $template could not be named for the story on $vm" >&2
            exit 1
        }
    fi
    # The porelo project's onto main, where porelo's first commit is, any other onto its template's branch.
    as_the_person_on_vm "cd ~/$run/fill/'$repository' && if [ '$template' = '$porelo_template' ]; then git push -q origin HEAD:refs/heads/main
        else git push -q 'git@github.com:$org/$repository.git' HEAD:'refs/heads/$branch'; fi" \
        </dev/null >&2 || {
        echo "walk: $org/$repository could not be filled from $org/$template" >&2
        exit 1
    }
    echo "walk: $org/$repository made, a copy of $org/$template on $branch"
}

# The seed's commit pushed onto the repository's default branch, never forced.
push_seed() {
    as_the_person_on_vm "cd ~/$run/seed/'$1' && git push -q origin HEAD:'refs/heads/${branch_of[$1]}'" </dev/null >&2 || {
        echo "walk: the seed could not be pushed to $org/$1" >&2
        exit 1
    }
}

# The repository and file a diff of the seed names on its first line, `--- <repository>/<file> ...`.
diff_target() {
    local path
    path=$(sed -n '1s/^--- \([^[:space:]]*\).*/\1/p' "$1")
    shaped "the file $(basename "$1") names" "$path" '[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._/-]*'
    [ -n "$path" ] || {
        echo "walk: $(basename "$1") names no file on its first line" >&2
        exit 1
    }
    printf '%s\n' "$path"
}

# The repository's tip as the forge has it now.
tip_of() {
    local tip
    tip=$(as_the_person_on_vm "git ls-remote 'git@github.com:$org/$1.git' 'refs/heads/${branch_of[$1]}'" </dev/null | cut -f1)
    shaped "the tip of $1" "$tip" '[0-9a-f]{40,64}'
    printf '%s\n' "$tip"
}
porelod_call() {
    on_vm "python3 -I -c 'import json, os, socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(\"/run/user/%d/porelo/porelod.sock\" % os.getuid())
s.sendall(json.dumps({\"method\": \"org.fuin.porelo.Tasks1.\" + sys.argv[1], \"parameters\": json.loads(sys.argv[2])}).encode() + bytes(1))
b = b\"\"
while not b.endswith(bytes(1)):
    got = s.recv(65536)
    if not got:
        break
    b += got
print(b.rstrip(bytes(1)).decode())' $1 '$2'" </dev/null
}
# The containers and task names of the porelo project's tasks porelod lists, one a line; none where it cannot be asked.
project_tasks() {
    porelod_call List '{}' 2>/dev/null | python3 -I -c 'import json, sys
for task in json.load(sys.stdin)["parameters"]["tasks"]:
    if task.get("project") == sys.argv[1]:
        print(task.get("container") or task.get("name") or "", task.get("task") or "")' "$porelo_project" 2>/dev/null |
        tr ' ' '\n' | grep -Ex '[A-Za-z0-9][A-Za-z0-9._-]{2,}' || true
}
placed() { porelod_call Projects '{}' | python3 -I -c 'import json, sys
print(any(p.get("name") == sys.argv[1] for p in json.load(sys.stdin)["parameters"]["projects"]))' "$porelo_project"; }
# A run whose copy on the VM is gone was taken away already, by its own ending or an earlier clean: nothing of the
# forge or the VM is touched again, as what a second clean would judge is no longer the run's.
if [ "$mode" = clean ] && [ "$(on_vm "if [ -d ~/$run ]; then echo kept; else echo gone; fi" </dev/null || true)" = gone ]; then
    echo "walk: ~/$run is gone on $vm: the run was cleaned up already; nothing is touched" >&2
    rm -rf "$work"
    exit 0
fi
if [ "$mode" = run ]; then
    before_tasks=$(project_tasks | tr '\n' ' ')
    before_known=yes
fi
trap cleanup EXIT
[ "$mode" != clean ] || exit 0

echo "walk: $commit to $vm:~/$run as $name"
git -C "$here" archive --format=tar HEAD | on_vm "mkdir -p ~/$run/bin && tar -x -C ~/$run"
if [ "$mode" = run ] && [ -n "$planner" ]; then
    tar -C "$planner" -c porelo-planner planner-probe.sh SHA256SUMS | on_vm "tar -x -C ~/$run/bin"
    # Checked again where it runs: what arrived is what was checked here.
    on_vm "cd ~/$run/bin && sha256sum --strict --quiet -c SHA256SUMS && chmod 755 porelo-planner planner-probe.sh" </dev/null || {
        echo "walk: the planner copied to $vm is not what SHA256SUMS names" >&2
        exit 1
    }
fi
if [ "$mode" = run ]; then
    if [ -n "$porelo_dir" ] && [ -n "$snapshot" ]; then
        # In place since the VM was prepared, as its package state says.
        porelo_commit=$(cat "$porelo_dir/COMMIT")
        {
            echo "porelo $porelo_commit, prepared in $snapshot"
            on_vm "porelo --version" </dev/null
        } | tee "$report/porelo.txt"
    elif [ -n "$porelo_dir" ]; then
        porelo_commit=$(cat "$porelo_dir/COMMIT")
        tar -C "$porelo_dir" -c porelo porelod SHA256SUMS | on_vm "mkdir -p ~/$run/porelo && tar -x -C ~/$run/porelo"
        swapped=yes
        # Checked again where it runs; the person's own ones are kept beside, never overwritten by a second run's.
        on_vm "set -e; cd ~/$run/porelo; sha256sum --strict --quiet -c SHA256SUMS; chmod 755 porelo porelod
        cd ~/.local/bin; for f in porelo porelod; do [ -f \$f.walk-kept ] || mv \$f \$f.walk-kept; cp ~/$run/porelo/\$f \$f; done
        systemctl --user restart porelod
        for _ in \$(seq 50); do [ -S /run/user/\$(id -u)/porelo/porelod.sock ] && break; sleep 0.2; done
        systemctl --user is-active --quiet porelod" </dev/null || {
            echo "walk: porelo of $porelo_commit could not be put in place on $vm" >&2
            exit 1
        }
        {
            echo "porelo $porelo_commit"
            on_vm "porelo --version" </dev/null
        } | tee "$report/porelo.txt"
    fi

    fetch_flutter

    # The account's card is the person's only while the forwarded agent holds its key.
    read -r holds person < <(as_the_person_on_vm "porelo identity show --json" </dev/null |
        python3 -I -c 'import json,sys; a = json.load(sys.stdin); print(a.get("agent_holds_key"), a.get("login") or "-")' || true) || true
    [ "$holds" = True ] || {
        echo "walk: the agent forwarded to $vm does not hold the key of the card there" >&2
        exit 1
    }
    [ -n "${person:-}" ] && [ "$person" != - ] || {
        echo "walk: the card on $vm names no login" >&2
        exit 1
    }
    shaped "the person's login" "$person" '[A-Za-z0-9][A-Za-z0-9-]{0,38}'

fi
# porelod on the VM is given the person's forwarded agent for the run, as tool/rehearse_window.sh does it, and put
# back as it was on every ending. A resumed run holds it again under the same name, which porelod still points at.
as_the_person_on_vm "echo \$\$ >~/$run/agent.pid && ln -sfn \"\$SSH_AUTH_SOCK\" ~/$run/agent.sock && exec sleep infinity" </dev/null >/dev/null 2>&1 &
holder=$!
on_vm "for _ in \$(seq 50); do [ -S ~/$run/agent.sock ] && exit 0; sleep 0.2; done; exit 1" </dev/null || {
    echo "walk: the person's agent could not be held open on $vm for porelod" >&2
    exit 1
}
if [ "$mode" = run ]; then
    agent_before=$(on_vm "systemctl --user show-environment | sed -n 's/^SSH_AUTH_SOCK=//p'" </dev/null)
    shaped 'porelod agent' "$agent_before" '/[A-Za-z0-9/._-]*'
    pointed=yes
    on_vm "set -e; systemctl --user set-environment SSH_AUTH_SOCK=\$HOME/$run/agent.sock; systemctl --user restart porelod
    for _ in \$(seq 50); do [ -S /run/user/\$(id -u)/porelo/porelod.sock ] && break; sleep 0.2; done
    systemctl --user is-active --quiet porelod
    systemctl --user show-environment | grep -qx \"SSH_AUTH_SOCK=\$HOME/$run/agent.sock\"" </dev/null || {
        echo "walk: porelod on $vm could not be started on the person's agent" >&2
        exit 1
    }

    # The forge's token in a vault of the run's own, declared for the organization's forge, as tool/rehearse_window.sh
    # does it with REHEARSAL_CENTRAL_TOKEN: the account's vault is never opened, read or changed.
    central_match=$(as_the_person_on_vm "porelo org --json --refresh" </dev/null 2>/dev/null | python3 -I -c 'import json, re, sys
a = json.load(sys.stdin)
m = re.search(re.escape(a["forge"]) + r"[:/]+([A-Za-z0-9_.-]+)/", a["address"])
print("https://" + a["forge"] + "/" + m[1] + "/" if m else "")') || true
    shaped 'the organization forge' "$central_match" 'https://[A-Za-z0-9.-]+/[A-Za-z0-9_.-]+/'
    [ -n "$central_match" ] || {
        echo "walk: porelo on $vm names no forge and owner of the organization" >&2
        exit 1
    }
    # porelo looks for the project's repository beside the organization's: the story's are made under that owner.
    [ "$central_match" = "https://github.com/$org/" ] || {
        echo "walk: the organization porelo follows on $vm is kept at $central_match, not under --org $org" >&2
        exit 1
    }
    vault="\$HOME/$run/vault/vault.bin"
    in_vault="PORELO_VAULT=$vault "
    on_vm "set -e; umask 077; mkdir ~/$run/vault
    head -c 32 /dev/urandom | base64 -w0 | { cat; echo; } | ${in_vault}porelo vault init --passphrase-stdin >/dev/null" \
        </dev/null || {
        echo "walk: a vault of the run's own could not be made on $vm" >&2
        exit 1
    }
    printf '%s\n' "$token" | on_vm "${in_vault}porelo vault put --json central-forge" >/dev/null || {
        echo "walk: the forge token could not be put into the run's vault on $vm" >&2
        exit 1
    }
    # The tasks' agent pi signs in at OpenRouter with the key stored under the provider's name in porelod's vault.
    on_vm "${in_vault}porelo vault put --json openrouter" <"$WALK_PROVIDER_KEY_FILE" >/dev/null || {
        echo "walk: the OpenRouter key could not be put into the run's vault on $vm" >&2
        exit 1
    }
    if as_the_person_on_vm "porelo credentials list" </dev/null | awk '{print $1}' | grep -qxF "$central_match"; then
        echo "walk: the person on $vm declares $central_match already; that declaration is used"
    else
        declared=yes
        as_the_person_on_vm "porelo credentials declare '$central_match' --kind token --vault central-forge" \
            </dev/null >/dev/null || {
            echo "walk: $central_match could not be declared on $vm" >&2
            exit 1
        }
    fi
    # porelod reads the organization's https addresses with the vault it was started with: for the run, the run's own.
    on_vm "set -e; systemctl --user set-environment PORELO_VAULT=$vault; systemctl --user restart porelod
    for _ in \$(seq 50); do [ -S /run/user/\$(id -u)/porelo/porelod.sock ] && break; sleep 0.2; done
    systemctl --user is-active --quiet porelod" </dev/null || {
        echo "walk: porelod on $vm could not be started on the run's vault" >&2
        exit 1
    }

    # The seed's diffs, read before anything is touched, each to apply to a file of a seeded repository as it is at T0; other top-level files are not
    # seeded.
    diffs=()
    for each in ${seed:+"$seed"/*.diff}; do
        [ -f "$each" ] || continue
        target=$(diff_target "$each")
        case " ${seeded[*]} " in *" ${target%%/*} "*) ;; *)
            echo "walk: $(basename "$each") names ${target%%/*}, which the seed does not hold" >&2
            exit 1
            ;;
        esac
        diffs+=("$each")
    done
    # The story's repositories, each a copy of its template; T0 of each, then the seed written over the seeded ones.
    for each in "${templates[@]}"; do make_repository "$each"; done
    for each in "${templates[@]}"; do note_t0 "$(own "$each")"; done
    # Every seeded repository is prepared before any is pushed: a diff that does not apply stops the run with nothing pushed.
    for each in "${seeded[@]}"; do prepare_seed "$each"; done
    for each in "${seeded[@]}"; do push_seed "$each"; done
    # A changed project.yml counts only once its newest change is signed by a Project Admin; the story's names changed
    # it, so it is signed whether seeded or not.
    sign_the_project "$(tip_of "$porelo_project")" || {
        echo "walk: $porelo_project could not be signed anew on $vm" >&2
        exit 1
    }
    echo "walk: $org/$porelo_project stands signed at $(tip_of "$porelo_project")"
    # Each issue repository's tip once seeded, as the window's walk reads its builder's work against it.
    issue_heads=''
    for each in "${issue_repos[@]}"; do issue_heads+="${issue_heads:+ }$each=$(tip_of "$each")"; done

    # The person's own machine takes the organization's project as a person's laptop does, on the person's agent, so porelod lists it and the
    # window tells the planner of it; one already placed there is not the run's to take or to clear.
    if [ "$(placed)" != True ]; then
        taken=yes
        # Off a host only a start or its question takes a project; the question starts nothing.
        answer=$(porelod_call CanStart "{\"project\": \"$porelo_project\", \"repository\": \"${issue_repos[0]}\"}") || answer=''
        echo "walk: porelod asked whether $porelo_project can start: $answer"
        if [ "$(placed)" != True ]; then
            echo "walk: porelod on $vm does not list $porelo_project after taking it" >&2
            exit 1
        fi
    fi

    # The planner's state and cache of the story's own project are taken away first: what an earlier run of the story
    # left there names repositories made anew since. Of any other project, its state as before the run is put back on
    # every ending; none stands for a project new to the planner. Kept beside the run's copy, which goes first.
    if [ -n "$planner" ] && [ "$project" = "$porelo_project" ]; then
        own_planner=yes
        planned=yes
        on_vm "rm -rf -- ~/.local/state/porelo-planner/'$project' ~/.cache/porelo-planner/'$project'" </dev/null || {
            echo "walk: the planner's state and cache of $project on $vm could not be taken away" >&2
            exit 1
        }
    elif [ -n "$planner" ]; then
        on_vm "set -e; rm -f ~/$run.planner-state.tar; d=~/.local/state/porelo-planner
            if [ -d \$d/'$project' ]; then tar -C \$d -cf ~/$run.planner-state.tar -- '$project'; fi" </dev/null || {
            echo "walk: the planner's state of $project on $vm could not be kept" >&2
            exit 1
        }
        planned=yes
    fi

    # The branch the forwarding test chooses, made at the default branch's tip; named for the run, so the ending
    # deletes it with the one the person types.
    if [ "$test" = forwarding_to_a_branch ]; then
        case $(github POST "/repos/$org/${issue_repos[0]}/git/refs" \
            "{\"ref\": \"refs/heads/walk-$name-existing\", \"sha\": \"${t0_of[${issue_repos[0]}]}\"}") in
        201) echo "walk: $org/${issue_repos[0]} has walk-$name-existing at ${t0_of[${issue_repos[0]}]}" ;;
        # Made already by this run, for instance before a resume: taken as it stands where it stands at T0.
        422) [ "$(github GET "/repos/$org/${issue_repos[0]}/git/ref/heads/walk-$name-existing")" = 200 ] &&
            [ "$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["object"]["sha"])' \
                "$work/answer")" = "${t0_of[${issue_repos[0]}]}" ] || {
            echo "walk: walk-$name-existing in $org/${issue_repos[0]} stands elsewhere than T0" >&2
            exit 1
        } ;;
        *)
            echo "walk: walk-$name-existing could not be made in $org/${issue_repos[0]}" >&2
            exit 1
            ;;
        esac
    fi

    # What a resume or a clean takes the run up with.
    declare -p created org_added person before_tasks before_known test vm org planner project porelo_project mail issue_repos name run since issue_heads vault in_vault central_match \
        declared pointed agent_before swapped porelo_commit taken planned own_planner branch_of t0_of | sed 's/^declare -A/declare -gA/' >"$report/state.sh"
fi

echo "walk: the window walks $project from step $from, at most $budget minutes"
status=0
# The planner fetches the project's https repositories with git, as a person's own login would: a git configuration of
# the run's own names porelo's credential helper for the organization, which answers from the run's vault, so the token
# is in no file and on no command line. The planner passes git no other GIT_ variable than this one.
on_vm "set -e; umask 077; printf '[credential \"https://github.com/%s\"]\\n\\thelper = \"!porelo vault credential --entry central-forge\"\\n[user]\\n\\tname = %s\\n\\temail = %s@users.noreply.github.com\\n' '$org' '$login' '$login' >~/$run/gitconfig
    ${in_vault}GIT_CONFIG_GLOBAL=\$HOME/$run/gitconfig GIT_TERMINAL_PROMPT=0 git -c credential.interactive=never \
        ls-remote https://github.com/$org/$porelo_project HEAD >/dev/null" </dev/null || {
    echo "walk: git on $vm cannot read https://github.com/$org/$porelo_project through the run's vault" >&2
    exit 1
}
# The steps an earlier attempt of this run noted; this attempt is judged on the ones after them.
steps_before=$(on_vm "cat ~/$run/steps.txt 2>/dev/null | wc -l" </dev/null) && [[ $steps_before =~ ^[0-9]+$ ]] || steps_before=0
# In a session of its own whose number is kept, so an ending here takes the whole of it down there too. In a scope of
# the account's user manager, as a window on a desktop is: a terminal's podman exec under the ssh login's own scope may
# not move into the task's cgroup ("OCI permission denied"). The window
# reaches this VM's own porelod and keeps the account's settings; tool/e2e.sh insists on a machine, which is this one.
# The forwarding test's window reaches GitHub as a person's own does, with the token from the run's vault in its
# environment alone: never on a command line, never in a file.
forwarding=''
[ "$test" != forwarding_to_a_branch ] || forwarding="export PORELO_FORGE_TOKEN PORELO_FORGE_TOKEN_FORGE=github.com
    PORELO_FORGE_TOKEN=\$(printf 'protocol=https\\nhost=github.com\\n\\n' | ${in_vault}porelo vault credential --entry central-forge get | sed -n 's/^password=//p')
    [ -n \"\$PORELO_FORGE_TOKEN\" ] || { echo 'walk: the run vault gave no forge token' >&2; exit 1; }
    export PORELO_FORWARD_URL='https://github.com/$org/${issue_repos[0]}' PORELO_FORWARD_REPOSITORY='${issue_repos[0]}'
    export PORELO_FORWARD_EXISTING='walk-$name-existing' PORELO_FORWARD_TYPED='walk-$name-typed'
    export PORELO_REHEARSAL_HOST_NAME='this machine' PORELO_REHEARSAL_PROJECT='$porelo_project'
    export PORELO_REHEARSAL_AGENT='$agent' PORELO_REHEARSAL_MODEL='$task_model'
    "
as_the_person_on_vm \
    "$forwarding cd ~/$run && exec systemd-run --user --scope --quiet setsid sh -c 'echo \$\$ >pid; exec \"\$@\"' walk env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
        PATH=\$HOME/$run/bin:\$HOME/$flutter_dir/bin:\$PATH \
        PORELO_E2E_HOST=localhost PORELO_E2E_REMOTE_SOCKET=/run/user/\$(id -u)/porelo/porelod.sock \
        PORELO_E2E_ACCOUNT_RUNTIME=1 XDG_RUNTIME_DIR=/run/user/\$(id -u) \
        PORELO_E2E_OWN_SETTINGS=1 $in_vault \
        GIT_CONFIG_GLOBAL=\$HOME/$run/gitconfig \
        PORELO_WALK_PROJECT='$project' PORELO_WALK_PORELO_PROJECT='$porelo_project' PORELO_WALK_AGENT='$agent' PORELO_WALK_MODEL='$task_model' \
        PORELO_WALK_PROBE=\$HOME/$run/bin/planner-probe.sh PORELO_WALK_PLANNER=\$HOME/$run/bin/porelo-planner \
        PORELO_WALK_OWN_URL='https://github.com/$org/$project' PORELO_WALK_ISSUE_REPOS='${issue_repos[*]}' \
        PORELO_WALK_ISSUE_HEADS='$issue_heads' PORELO_WALK_SINCE='$since' PORELO_WALK_TASK_MINUTES='$task_minutes' \
        PORELO_WALK_AGENT_QUIT='$agent_quit' \
        PORELO_WALK_FROM='$from' PORELO_WALK_STATE=\$HOME/$run/walk-state.json \
        PORELO_WALK_STEPS=\$HOME/$run/steps.txt PORELO_WALK_TASKS=\$HOME/$run/tasks.txt \
        PORELO_WALK_PROBE_LOG=\$HOME/$run/probe.log \
        PORELO_REHEARSAL_SHOTS=\$HOME/$run/pictures \
        timeout --signal=TERM ${budget}m dbus-run-session -- \
        tool/e2e.sh --machine integration_test/${test}_test.dart" \
    </dev/null >"$report/results.json" 2>"$report/run.log" || status=$?
# The steps and pictures, before the run's copy is taken away; a run taken up again adds its steps to the earlier ones.
on_vm "cat ~/$run/steps.txt 2>/dev/null" </dev/null >"$report/steps.txt" || true
on_vm "cat ~/$run/probe.log 2>/dev/null" </dev/null >"$report/probe.log" || true
# What came back is blanked of the run's forge token and the provider's key wherever it may show: the token goes in on
# standard input, the key is read from its file, neither reaches a command line.
printf '%s' "${token:-}" | python3 -I -c '
import sys
secrets = [sys.stdin.read().strip()]
try:
    secrets.append(open(sys.argv[1]).read().strip())
except OSError:
    pass
secrets = [each for each in secrets if len(each) >= 8]
for path in sys.argv[2:]:
    try:
        text = open(path, encoding="utf-8", errors="surrogateescape").read()
    except OSError:
        continue
    blanked = text
    for each in secrets:
        blanked = blanked.replace(each, "<token>")
    if blanked != text:
        open(path, "w", encoding="utf-8", errors="surrogateescape").write(blanked)
' "${WALK_PROVIDER_KEY_FILE:-/nonexistent}" "$report/steps.txt" "$report/probe.log" "$report/run.log" "$report/results.json" ||
    echo "walk: the report could not be blanked of the run's secrets" >&2
tail -n +"$((steps_before + 1))" "$report/steps.txt" >"$work/these-steps"
if on_vm "[ -d ~/$run/pictures ]" </dev/null; then on_vm "tar -C ~/$run -c pictures" </dev/null | tar -x -C "$report" || true; fi
[ "$status" -ne 124 ] || echo "walk: the window's part ran out its $budget minutes and was stopped" | tee -a "$report/run.log" >&2

(cd "$here" && dart tool/test_report.dart "$report/results.json" "$report/report.html" "$report/results.xml" \
    --heading="$(case "$test" in walking_an_idea) echo 'A real idea walked in the window' ;; a_tasks_results_land) echo "A task's results landing, walked in the window" ;; the_planner_moves_work_on) echo 'Work moving on by itself, walked in the window' ;; *) echo 'Work forwarded to a branch at GitHub' ;; esac)" --against="$vm, project $project" --lines="$report/scenarios.txt") || true
# Passed only where the scenarios passed and none failed, and, for the walk that notes its steps, a step of this attempt
# was read and none failed.
if ! grep -q '^OK ' "$report/scenarios.txt" 2>/dev/null || grep -q '^FAIL ' "$report/scenarios.txt" ||
    grep -q '^FAIL ' "$work/these-steps" ||
    { [ "$test" != forwarding_to_a_branch ] && ! grep -q '^OK ' "$work/these-steps"; }; then
    [ "$status" -ne 0 ] || status=1
fi
cat "$report/steps.txt"
# A red step keeps the run for a repair by hand and the next step.
if grep -q '^FAIL ' "$work/these-steps"; then kept=yes; fi
exit "$status"
