#!/usr/bin/env bash
# Walks a real idea through the real window to its story Finished, the window running in a local VM under a virtual
# display against that VM's own porelo and the planner given, never on this computer's.
#
#   tool/walk_idea.sh check --vm USER@VM --vm-key FILE [--planner DIR]
#   tool/walk_idea.sh run   --vm USER@VM --vm-key FILE --planner DIR --seed DIR --org ORG --report DIR \
#                           [--porelo-project foo-project] [--project NAME] [--issue-repo foo-1] [--budget-minutes 180]
#
# `check` says what the VM lacks and changes nothing. `run` checks first, then seeds the existing repositories of ORG:
# the seed holds one directory per repository, named as it is, whose files are written over that repository's at the
# same paths and pushed as one commit, after each repository's tip was noted as T0; the issue repository's T0 is noted
# whether it is seeded or not. A top-level <name>.diff whose first line is `--- <repository>/<file>` is applied to that
# file as it is at T0 instead of copying it, and the run stops before any push where it does not apply. The porelo
# project's repository, where seeded, is signed anew as the person (`porelo project sign`) on the pushed tip. The
# planner's project is the porelo project (--project defaults to --porelo-project), whose own repository is the one of
# that name. It copies this checkout's HEAD to the VM, puts the planner of DIR first on the window's path and runs
# integration_test/walking_an_idea_test.dart there through tool/e2e.sh, and writes the report into DIR: one line per
# step (`OK` or `FAIL` with what was asked and got), a picture of the window where it failed, the HTML and JUnit
# report, and the test's own output.
#
# DIR of --planner holds porelo-planner, planner-probe.sh and SHA256SUMS naming both; nothing unchecked is copied.
# The test person's key never enters the VM: SSH_AUTH_SOCK must name an agent holding it (a throwaway one, never the
# operator's), forwarded for the run alone. WALK_FORGE_TOKEN names a program that prints the test identity's token
# for the forge: it goes on standard input alone into a vault of the run's own on the VM, and to GitHub's API as a
# curl config on standard input, never on a command line. Every ending takes away what the run made: the task branches
# and pull requests in the issue repository, each noted repository's tree back to its T0 in one new commit where it
# differs (never a force push), the porelo project's repository signed anew on that commit, the run's vault and copy
# on the VM; it exits non-zero naming what it left.
set -euo pipefail

usage() {
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 64
}

[ $# -ge 1 ] || usage
mode=$1
shift
vm='' vm_key='' planner='' seed='' org='' project='' issue_repo=foo-1 porelo_project=foo-project report='' budget=180
while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || usage
    case "$1" in
    --vm) vm=$2 ;;
    --vm-key) vm_key=$2 ;;
    --planner) planner=$2 ;;
    --seed) seed=$2 ;;
    --org) org=$2 ;;
    --project) project=$2 ;;
    --porelo-project) porelo_project=$2 ;;
    --issue-repo) issue_repo=$2 ;;
    --report) report=$2 ;;
    --budget-minutes) budget=$2 ;;
    *) usage ;;
    esac
    shift 2
done
case "$mode" in check | run) ;; *) usage ;; esac
[ -n "$vm" ] && [ -n "$vm_key" ] || usage
case "$budget" in '' | *[!0-9]*) echo "walk: --budget-minutes is a whole number of minutes" >&2 && exit 64 ;; esac
# Every task of the walk runs this agent and model: the discussion, the builder and the reader.
agent=${WALK_AGENT:-pi}
task_model=${WALK_TASK_MODEL:-z-ai/glm-5.3-flash}
task_minutes=${PORELO_WALK_TASK_MINUTES:-30}
# What ends the discussion's agent session, typed as the person would; the test's own default where unset.
agent_quit=${WALK_AGENT_QUIT:-}
case "$task_minutes" in '' | *[!0-9]*) echo "walk: PORELO_WALK_TASK_MINUTES is a whole number" >&2 && exit 64 ;; esac
# Every value goes into a command line on the VM or a URL, so each is held to what it can be.
shaped() {
    [ -z "$2" ] || printf '%s\n' "$2" | grep -Eqx "$3" || {
        echo "walk: $1 is not of the form it takes" >&2
        exit 64
    }
}
shaped --vm "$vm" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
shaped --org "$org" '[A-Za-z0-9][A-Za-z0-9-]{0,38}'
# The planner and its probe take a project name in lower case alone.
shaped --project "$project" '[a-z0-9][a-z0-9._-]{0,99}'
shaped --porelo-project "$porelo_project" '[A-Za-z0-9][A-Za-z0-9._-]*'
shaped --issue-repo "$issue_repo" '[A-Za-z0-9][A-Za-z0-9._-]{0,99}'
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
    env -u SSH_AUTH_SOCK SSH_ASKPASS_REQUIRE=never ssh -x -o BatchMode=yes -o IdentitiesOnly=yes -i "$vm_key" "$vm" \
        "$(in_the_login_shell "$@")"
}

# The VM with the test person's agent forwarded, for the calls that reach the forge or the organization as that person.
as_the_person_on_vm() {
    SSH_ASKPASS_REQUIRE=never ssh -x -A -o BatchMode=yes -o IdentitiesOnly=yes -i "$vm_key" "$vm" \
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

# What the run needs on the VM, each named; a missing one is said with the line that installs it.
check() {
    local missing
    planner_checked
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

if [ "$mode" = check ]; then
    check
    exit
fi

[ -n "$planner" ] && [ -n "$seed" ] && [ -n "$org" ] && [ -n "$report" ] || usage
# The repositories to seed, each a directory of the seed named as the repository is.
seeded=()
for each in "$seed"/*/; do
    [ -d "$each" ] || continue
    each=$(basename "$each")
    shaped "the seed's directory" "$each" '[A-Za-z0-9][A-Za-z0-9._-]{0,99}'
    seeded+=("$each")
done
[ ${#seeded[@]} -gt 0 ] || {
    echo "walk: $seed holds no directory named for a repository to seed" >&2
    exit 1
}
[ -n "${WALK_FORGE_TOKEN:-}" ] && [ -x "$WALK_FORGE_TOKEN" ] || {
    echo "walk: WALK_FORGE_TOKEN names no program printing the forge's token" >&2
    exit 1
}
if [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l >/dev/null 2>&1; then
    echo "walk: SSH_AUTH_SOCK names no agent holding the test person's key" >&2
    exit 1
fi
check
[ -z "$(git -C "$here" status --porcelain --untracked-files=no)" ] || echo "walk: runs HEAD; changes not committed are not in it" >&2
commit=$(git -C "$here" rev-parse --short HEAD)
name="walk-$(date -u +%Y%m%d-%H%M%S)-$commit"
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
project=${project:-$porelo_project}
run="walk/$name"
mkdir -p "$report"
# A report left from an earlier run would be read as this one's.
rm -f "$report/results.json" "$report/run.log" "$report/report.html" "$report/results.xml" "$report/scenarios.txt" \
    "$report/steps.txt"
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

# Taken away on every ending, in this order: what still runs of the window's part and the planner it started, the
# task branches and pull requests in the issue repository, each noted repository's tree as at its T0, the forge's
# token and its declaration, porelod's agent put back, the run's copy.
pointed='' agent_before='' holder='' central_match='' vault='' declared='' taken=''
# Each noted repository's default branch and its tip at T0, by name; only a noted one is restored.
declare -A branch_of=() t0_of=()
left=()
# shellcheck disable=SC2329
cleanup() {
    on_vm "if [ -f ~/$run/pid ]; then kill -TERM -- -\$(cat ~/$run/pid) 2>/dev/null || true; fi
        for p in /proc/[0-9]*; do
            [ \"\$(readlink \$p/exe 2>/dev/null)\" != \$HOME/$run/bin/porelo-planner ] || kill -TERM \${p#/proc/} 2>/dev/null || true
        done" </dev/null || true
    local tasks=''
    tasks=$(on_vm "tr ' ' '\\n' <~/$run/tasks.txt 2>/dev/null" </dev/null | grep -Ex '[A-Za-z0-9][A-Za-z0-9._-]{2,}' || true)
    if [ -n "$taken" ]; then
        # Judged by what porelod lists afterwards: the clear's exit also counts what it could not reach of the run's vault.
        as_the_person_on_vm "${in_vault:-}porelo project clear --yes '$porelo_project'" </dev/null >/dev/null 2>&1 || true
        [ "$(placed)" != True ] || left+=("$porelo_project placed on $vm (porelo project clear --yes $porelo_project there)")
    fi
    [ -z "${t0_of[$issue_repo]:-}" ] || take_back_the_tasks_work "$tasks"
    local each
    for each in "${!t0_of[@]}"; do restore "$each"; done
    if [ -n "$declared" ]; then
        as_the_person_on_vm "porelo credentials forget '$central_match'" </dev/null >/dev/null 2>&1 ||
            left+=("the declaration of $central_match on $vm (porelo credentials forget there)")
    fi
    if [ -n "$vault" ]; then
        on_vm "PORELO_VAULT=$vault porelo vault lock" </dev/null >/dev/null 2>&1 || true
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

# The issue repository's branches named for the run's project or one of its tasks go, each open pull request from one
# of them closed first: the API deletes no pull request, so a closed one with its branch gone is all that can go.
# shellcheck disable=SC2329 # run by cleanup, on the EXIT trap
take_back_the_tasks_work() {
    local names=$1 status branch number
    status=$(github GET "/repos/$org/$issue_repo/pulls?state=open&per_page=100")
    if [ "$status" = 200 ]; then
        while read -r number branch; do
            if carries_the_run "$branch" "$names"; then
                case $(github PATCH "/repos/$org/$issue_repo/pulls/$number" '{"state":"closed"}') in
                200) ;; *) left+=("pull request #$number of $org/$issue_repo") ;;
                esac
            fi
        done < <(jq -r '.[] | "\(.number) \(.head.ref)"' "$work/answer")
    else
        left+=("the pull requests of $org/$issue_repo could not be listed ($status)")
    fi
    status=$(github GET "/repos/$org/$issue_repo/branches?per_page=100")
    if [ "$status" = 200 ]; then
        while read -r branch; do
            if carries_the_run "$branch" "$names"; then
                case $(github DELETE "/repos/$org/$issue_repo/git/refs/heads/$branch") in
                204 | 422) ;; *) left+=("the branch $branch of $org/$issue_repo") ;;
                esac
            fi
        done < <(jq -r '.[].name' "$work/answer" | grep -Ex '[A-Za-z0-9][A-Za-z0-9._/-]*' || true)
    else
        left+=("the branches of $org/$issue_repo could not be listed ($status)")
    fi
}

# shellcheck disable=SC2329 # run by cleanup, on the EXIT trap
carries_the_run() {
    local branch=$1 each
    case "$branch" in *"$project"* | *"$name"*) return 0 ;; esac
    for each in $2; do
        case "$branch" in *"$each"*) return 0 ;; esac
    done
    return 1
}

# One new commit on the repository's tip holding its T0 tree, where the tree differs: never a force push. The porelo
# project's repository is signed anew on it, since porelo judges its project.yml by its newest change.
# shellcheck disable=SC2329 # run by cleanup, on the EXIT trap
restore() {
    local repository=$1 branch=${branch_of[$1]} t0=${t0_of[$1]} pushed
    pushed=$(as_the_person_on_vm "set -e; d=~/$run/restore/$repository; rm -rf \$d
        git clone -q --bare --filter=blob:none --single-branch --branch '$branch' 'git@github.com:$org/$repository.git' \$d
        tip=\$(git -C \$d rev-parse 'refs/heads/$branch')
        tree=\$(git -C \$d rev-parse '$t0^{tree}')
        [ \"\$(git -C \$d rev-parse \$tip^{tree})\" != \"\$tree\" ] || exit 0
        c=\$(git -C \$d -c user.name='Porelo walk' -c user.email=walk@example.org commit-tree \$tree -p \$tip \
            -m 'Restore the tree before the walk $name')
        git -C \$d push -q origin \$c:'refs/heads/$branch' >&2; echo \$c" </dev/null) || {
        left+=("$org/$repository is not back at the tree of $t0")
        return
    }
    if [ "$repository" = "$porelo_project" ] && [ -n "$pushed" ]; then
        sign_the_project "$pushed" || left+=("the signature of $porelo_project on the restore commit $pushed")
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
        on_vm "cat >~/$run/seed/'$repository.files/$file'" <"$work/applied"
    done
    as_the_person_on_vm "set -e; cd ~/$run/seed; cp -R '$repository.files/.' '$repository/'; cd '$repository'; git add -A
        git -c user.name='Porelo walk' -c user.email=walk@example.org commit -q --allow-empty -m 'Seed the walk $name'" \
        </dev/null >&2 || {
        echo "walk: the seed could not be committed to $org/$repository on $vm" >&2
        exit 1
    }
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
trap cleanup EXIT

echo "walk: $commit to $vm:~/$run as $name"
git -C "$here" archive --format=tar HEAD | on_vm "mkdir -p ~/$run/bin && tar -x -C ~/$run"
tar -C "$planner" -c porelo-planner planner-probe.sh SHA256SUMS | on_vm "tar -x -C ~/$run/bin"
# Checked again where it runs: what arrived is what was checked here.
on_vm "cd ~/$run/bin && sha256sum --strict --quiet -c SHA256SUMS && chmod 755 porelo-planner planner-probe.sh" </dev/null || {
    echo "walk: the planner copied to $vm is not what SHA256SUMS names" >&2
    exit 1
}

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

# The account's card is the person's only while the forwarded agent holds its key.
holds=$(as_the_person_on_vm "porelo identity show --json" </dev/null | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("agent_holds_key"))' || true)
[ "$holds" = True ] || {
    echo "walk: the agent forwarded to $vm does not hold the key of the card there" >&2
    exit 1
}

# porelod on the VM is given the person's forwarded agent for the run, as tool/rehearse_window.sh does it, and put
# back as it was on every ending.
as_the_person_on_vm "echo \$\$ >~/$run/agent.pid && ln -sfn \"\$SSH_AUTH_SOCK\" ~/$run/agent.sock && exec sleep infinity" </dev/null >/dev/null 2>&1 &
holder=$!
on_vm "for _ in \$(seq 50); do [ -S ~/$run/agent.sock ] && exit 0; sleep 0.2; done; exit 1" </dev/null || {
    echo "walk: the person's agent could not be held open on $vm for porelod" >&2
    exit 1
}
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
for each in "$seed"/*.diff; do
    [ -f "$each" ] || continue
    target=$(diff_target "$each")
    case " ${seeded[*]} " in *" ${target%%/*} "*) ;; *)
        echo "walk: $(basename "$each") names ${target%%/*}, which the seed does not hold" >&2
        exit 1
        ;;
    esac
    diffs+=("$each")
done
# T0 of every repository the run may change, then the seed written over the seeded ones.
for each in "${seeded[@]}"; do note_t0 "$each"; done
[ -n "${t0_of[$issue_repo]:-}" ] || note_t0 "$issue_repo"
# Every seeded repository is prepared before any is pushed: a diff that does not apply stops the run with nothing pushed.
for each in "${seeded[@]}"; do prepare_seed "$each"; done
for each in "${seeded[@]}"; do push_seed "$each"; done
# A changed project.yml counts only once its newest change is signed by a Project Admin.
case " ${seeded[*]} " in *" $porelo_project "*)
    sign_the_project "$(tip_of "$porelo_project")" || {
        echo "walk: $porelo_project could not be signed anew on $vm" >&2
        exit 1
    }
    echo "walk: $org/$porelo_project stands signed at $(tip_of "$porelo_project")"
    ;;
esac
issue_head=$(tip_of "$issue_repo")

# The person's own machine takes the organization's project as a person's laptop does, on the person's agent, so porelod lists it and the
# window tells the planner of it; one already placed there is not the run's to take or to clear.
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
placed() { porelod_call Projects '{}' | python3 -I -c 'import json, sys
print(any(p.get("name") == sys.argv[1] for p in json.load(sys.stdin)["parameters"]["projects"]))' "$porelo_project"; }
if [ "$(placed)" != True ]; then
    taken=yes
    # Off a host only a start or its question takes a project; the question starts nothing.
    answer=$(porelod_call CanStart "{\"project\": \"$porelo_project\", \"repository\": \"$issue_repo\"}") || answer=''
    echo "walk: porelod asked whether $porelo_project can start: $answer"
    if [ "$(placed)" != True ]; then
        echo "walk: porelod on $vm does not list $porelo_project after taking it" >&2
        exit 1
    fi
fi

echo "walk: the window walks $project, at most $budget minutes"
status=0
# The planner fetches the project's https repositories with git, as a person's own login would: a git configuration of
# the run's own names porelo's credential helper for the organization, which answers from the run's vault, so the token
# is in no file and on no command line. The planner passes git no other GIT_ variable than this one.
on_vm "set -e; umask 077; printf '[credential \"https://github.com/%s\"]\\n\\thelper = \"!porelo vault credential\"\\n' '$org' >~/$run/gitconfig
    ${in_vault}GIT_CONFIG_GLOBAL=\$HOME/$run/gitconfig GIT_TERMINAL_PROMPT=0 git -c credential.interactive=never \
        ls-remote https://github.com/$org/$porelo_project HEAD >/dev/null" </dev/null || {
    echo "walk: git on $vm cannot read https://github.com/$org/$porelo_project through the run's vault" >&2
    exit 1
}
# In a session of its own whose number is kept, so an ending here takes the whole of it down there too. The window
# reaches this VM's own porelod and keeps the account's settings; tool/e2e.sh insists on a machine, which is this one.
as_the_person_on_vm \
    "cd ~/$run && exec setsid sh -c 'echo \$\$ >pid; exec \"\$@\"' walk env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
        PATH=\$HOME/$run/bin:\$HOME/$flutter_dir/bin:\$PATH \
        PORELO_E2E_HOST=localhost PORELO_E2E_REMOTE_SOCKET=/run/user/\$(id -u)/porelo/porelod.sock \
        PORELO_E2E_LINK_SOCKET=/run/user/\$(id -u)/porelo/porelod.sock \
        PORELO_E2E_OWN_SETTINGS=1 $in_vault \
        GIT_CONFIG_GLOBAL=\$HOME/$run/gitconfig \
        PORELO_WALK_PROJECT='$project' PORELO_WALK_PORELO_PROJECT='$porelo_project' PORELO_WALK_AGENT='$agent' PORELO_WALK_MODEL='$task_model' \
        PORELO_WALK_PROBE=\$HOME/$run/bin/planner-probe.sh PORELO_WALK_PLANNER=\$HOME/$run/bin/porelo-planner \
        PORELO_WALK_OWN_URL='https://github.com/$org/$project' PORELO_WALK_ISSUE_REPO='$issue_repo' \
        PORELO_WALK_ISSUE_HEAD='$issue_head' PORELO_WALK_SINCE='$since' PORELO_WALK_TASK_MINUTES='$task_minutes' \
        PORELO_WALK_AGENT_QUIT='$agent_quit' \
        PORELO_WALK_STEPS=\$HOME/$run/steps.txt PORELO_WALK_TASKS=\$HOME/$run/tasks.txt \
        PORELO_REHEARSAL_SHOTS=\$HOME/$run/pictures \
        timeout --signal=TERM ${budget}m dbus-run-session -- \
        tool/e2e.sh --machine integration_test/walking_an_idea_test.dart" \
    </dev/null >"$report/results.json" 2>"$report/run.log" || status=$?
# The steps and pictures, before the run's copy is taken away.
on_vm "cat ~/$run/steps.txt 2>/dev/null" </dev/null >"$report/steps.txt" || true
if on_vm "[ -d ~/$run/pictures ]" </dev/null; then on_vm "tar -C ~/$run -c pictures" </dev/null | tar -x -C "$report" || true; fi
[ "$status" -ne 124 ] || echo "walk: the window's part ran out its $budget minutes and was stopped" | tee -a "$report/run.log" >&2

(cd "$here" && dart tool/test_report.dart "$report/results.json" "$report/report.html" "$report/results.xml" \
    --heading='A real idea walked in the window' --against="$vm, project $project" --lines="$report/scenarios.txt") || true
# Passed only where a step was read and none failed, and the scenario passed.
if ! grep -q '^OK ' "$report/steps.txt" || grep -q '^FAIL ' "$report/steps.txt" ||
    ! grep -q '^OK ' "$report/scenarios.txt" 2>/dev/null; then
    [ "$status" -ne 0 ] || status=1
fi
cat "$report/steps.txt"
exit "$status"
