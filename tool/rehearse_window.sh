#!/usr/bin/env bash
# Drives a move's scenarios through the real window against a rented host, the window running in a local VM
# under a virtual display, never on this computer's.
#
#   tool/rehearse_window.sh check --vm USER@VM --vm-key FILE
#   tool/rehearse_window.sh run   --vm USER@VM --vm-key FILE --host PERSON@ADDRESS --host-key 'TYPE BASE64' \
#                                 --host-name NAME --project PROJECT --report DIR [--budget-minutes 60]
#
# `check` says what the VM lacks and changes nothing. `run` checks first, copies this checkout's HEAD to the VM,
# runs integration_test/rehearsing_a_move_test.dart there through tool/e2e.sh, and writes the report into DIR:
# one line per scenario (`OK`, `FAIL`, or `SKIPPED` with why it did not run), a picture of the window for each one
# that failed, the HTML and JUnit report, and the test's own output.
#
# The test person's key never enters the VM: SSH_AUTH_SOCK must name an agent holding it (a throwaway one, never
# the operator's), and only the VM's connection forwards it, for the run alone. The VM is reached with --vm-key.
# The host's key is the one the rehearsal read when the server was rented; nothing that answers is trusted on its
# own word. REHEARSAL_CENTRAL_TOKEN, where set, names a program that prints the test identity's token for the central
# forge: it goes on standard input alone into a vault of the run's own on the VM, never the account's, and goes with
# the run's copy on every ending, so that porelo on the VM can ask the forge who holds which key.
set -euo pipefail

usage() {
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 64
}

[ $# -ge 1 ] || usage
mode=$1
shift
vm='' vm_key='' host='' host_key='' host_name='' project='' report='' budget=60
while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || usage
    case "$1" in
    --vm) vm=$2 ;;
    --vm-key) vm_key=$2 ;;
    --host) host=$2 ;;
    --host-key) host_key=$2 ;;
    --host-name) host_name=$2 ;;
    --project) project=$2 ;;
    --report) report=$2 ;;
    --budget-minutes) budget=$2 ;;
    *) usage ;;
    esac
    shift 2
done
case "$mode" in check | run) ;; *) usage ;; esac
[ -n "$vm" ] && [ -n "$vm_key" ] || usage
case "$budget" in '' | *[!0-9]*) echo "rehearse: --budget-minutes is a whole number of minutes" >&2 && exit 64 ;; esac
# Every value goes into a command line on the VM, so each is held to what it can be: no quote, no space, no option.
shaped() {
    [ -z "$2" ] || printf '%s\n' "$2" | grep -Eqx "$3" || {
        echo "rehearse: $1 is not of the form it takes" >&2
        exit 64
    }
}
shaped --vm "$vm" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
shaped --host "$host" '[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9.:-]*'
shaped --host-key "$host_key" '(ssh|ecdsa-sha2|sk-ssh)-[a-z0-9@.-]+ [A-Za-z0-9+/]+={0,2}'
shaped --host-name "$host_name" '[A-Za-z0-9][A-Za-z0-9._-]*'
shaped --project "$project" '[A-Za-z0-9][A-Za-z0-9._-]*'

here=$(cd "$(dirname "$0")/.." && pwd)
flutter_version=$(sed -n 's/^ *flutter: *\([0-9][0-9.]*\) *$/\1/p' "$here/pubspec.yaml" | head -1)
[ -n "$flutter_version" ] || {
    echo "rehearse: pubspec.yaml names no flutter version" >&2
    exit 1
}
flutter_dir=".cache/porelo-frontend/flutter-$flutter_version"

# The VM is reached with its own key alone: never the operator's agent, never a password asked.
# No forwarding of a display either way: the window has a virtual display of its own on the VM.
on_vm() {
    env -u SSH_AUTH_SOCK SSH_ASKPASS_REQUIRE=never ssh -x -o BatchMode=yes -o IdentitiesOnly=yes -i "$vm_key" "$vm" \
        "$(in_the_login_shell "$@")"
}

# The VM with the test person's agent forwarded, for the calls that reach the host as that person.
as_the_person_on_vm() {
    SSH_ASKPASS_REQUIRE=never ssh -x -A -o BatchMode=yes -o IdentitiesOnly=yes -i "$vm_key" "$vm" \
        "$(in_the_login_shell "$@")"
}

# A command over ssh runs in the account's login shell: without it, it meets the machine-wide porelo instead of the
# account's own, and the window with it.
in_the_login_shell() {
    printf 'exec bash -lc %q' "$*"
}

# What the run needs on the VM, each named; a missing one is said with the line that installs it.
check() {
    local missing
    # shellcheck disable=SC2016 # expanded on the VM, not here
    missing=$(on_vm 'for t in xvfb-run dbus-run-session clang cmake ninja pkg-config git curl xz python3 porelo; do
            command -v "$t" >/dev/null || echo "tool $t"
        done
        for p in libgtk-3-dev libsecret-1-dev; do dpkg -s "$p" >/dev/null 2>&1 || echo "package $p"; done
        c=${XDG_CONFIG_HOME:-$HOME/.config}/porelo
        [ -s "$c/identity/card" ] || echo "no porelo identity here: copy in the test person'"'"'s card"
        [ -s "$c/organization.yml" ] || echo "porelo follows no organization here: copy in its organization.yml"') || {
        echo "rehearse: $vm cannot be reached with $vm_key" >&2
        return 1
    }
    if [ -n "$missing" ]; then
        echo "rehearse: $vm lacks:" >&2
        printf '%s\n' "$missing" | sed 's/^/  /' >&2
        local packages
        packages=$(printf '%s\n' "$missing" | sed -n 's/^package //p; s/^tool xvfb-run$/xvfb/p; s/^tool \(clang\|cmake\|git\|curl\)$/\1/p;
            s/^tool ninja$/ninja-build/p; s/^tool pkg-config$/pkg-config/p; s/^tool xz$/xz-utils/p; s/^tool dbus-run-session$/dbus/p' | tr '\n' ' ')
        [ -z "$packages" ] || echo "  the operator installs them there with: sudo apt install $packages" >&2
        return 1
    fi
    # The organization is read only with the test person's agent, named in REHEARSAL_PERSON_AGENT as the rehearsal
    # names it; never with the agent of whoever calls the check. Read fresh, in this call: a read of what porelo kept
    # starts a check of its own after it, which outlives this connection and its forwarded agent.
    if [ -n "${REHEARSAL_PERSON_AGENT:-}" ] &&
        ! SSH_AUTH_SOCK=$REHEARSAL_PERSON_AGENT as_the_person_on_vm 'porelo org --json --refresh >/dev/null 2>&1'; then
        echo "rehearse: porelo on $vm cannot read the organization with the agent given" >&2
        return 1
    fi
    echo "rehearse: $vm has what the run needs; Flutter $flutter_version is fetched into ~/$flutter_dir if missing"
}

if [ "$mode" = check ]; then
    check
    exit
fi

[ -n "$host" ] && [ -n "$host_key" ] && [ -n "$host_name" ] && [ -n "$project" ] && [ -n "$report" ] || usage
case "$host" in *@*) ;; *) echo "rehearse: --host is PERSON@ADDRESS" >&2 && exit 64 ;; esac
if [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l >/dev/null 2>&1; then
    echo "rehearse: SSH_AUTH_SOCK names no agent holding the test person's key" >&2
    exit 1
fi
check
[ -z "$(git -C "$here" status --porcelain --untracked-files=no)" ] || echo "rehearse: runs HEAD; changes not committed are not in it" >&2
commit=$(git -C "$here" rev-parse --short HEAD)
address=${host#*@}
run="rehearsal/$(date -u +%Y%m%dT%H%M%SZ)-$commit"
mkdir -p "$report"
# A report left from an earlier run would be read as this one's.
rm -f "$report/results.json" "$report/run.log" "$report/report.html" "$report/results.xml" "$report/scenarios.txt"
rm -rf "$report/pictures"

# Taken away on every ending: the central forge's token and its declaration where this run put them, what still
# runs of the window's part, porelod's agent put back where this run pointed it at the person's, the run's copy, and
# the host's key where this run added it.
added_key='' pointed='' agent_before='' holder='' central_match='' vault='' declared=''
# shellcheck disable=SC2329
cleanup() {
    if [ -n "$declared" ]; then
        as_the_person_on_vm "porelo credentials forget '$central_match'" </dev/null >/dev/null 2>&1 ||
            echo "rehearse: the declaration of $central_match could not be taken off $vm; forget it there" >&2
    fi
    if [ -n "$vault" ]; then
        on_vm "PORELO_VAULT=$vault porelo vault lock" </dev/null >/dev/null 2>&1 || true
    fi
    if [ -n "$pointed" ]; then
        on_vm "if [ -n '$agent_before' ]; then systemctl --user set-environment SSH_AUTH_SOCK='$agent_before'
            else systemctl --user unset-environment SSH_AUTH_SOCK; fi; systemctl --user restart porelod" ||
            echo "rehearse: porelod on $vm could not be given its own agent back; restart it there" >&2
    fi
    [ -z "$holder" ] || kill "$holder" 2>/dev/null || true
    on_vm "if [ -f ~/$run/pid ]; then kill -TERM -- -\$(cat ~/$run/pid) 2>/dev/null || true; fi
        if [ -f ~/$run/agent.pid ]; then kill -TERM \$(cat ~/$run/agent.pid) 2>/dev/null || true; fi; rm -rf ~/$run
        if [ -n '$added_key' ]; then ssh-keygen -R '$address' >/dev/null 2>&1 || true; fi" || true
}
trap cleanup EXIT

echo "rehearse: $commit to $vm:~/$run"
git -C "$here" archive --format=tar HEAD | on_vm "mkdir -p ~/$run && tar -x -C ~/$run"

on_vm "set -e
    if [ ! -x ~/$flutter_dir/bin/flutter ]; then
        mkdir -p ~/.cache/porelo-frontend && cd ~/.cache/porelo-frontend
        listed=\$(curl -fsS https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)
        line=\$(printf '%s' \"\$listed\" | python3 -I -c 'import json,sys
d=json.load(sys.stdin)
r=[r for r in d[\"releases\"] if r[\"version\"]==\"$flutter_version\" and r[\"channel\"]==\"stable\"]
print(r[0][\"archive\"], r[0][\"sha256\"]) if r else None')
        [ -n \"\$line\" ] || { echo 'rehearse: Flutter $flutter_version is not listed' >&2; exit 1; }
        set -- \$line
        curl -fsS -o flutter.tar.xz \"https://storage.googleapis.com/flutter_infra_release/releases/\$1\"
        echo \"\$2  flutter.tar.xz\" | sha256sum -c --quiet
        rm -rf flutter-$flutter_version.part && mkdir flutter-$flutter_version.part
        tar -xJf flutter.tar.xz -C flutter-$flutter_version.part && rm flutter.tar.xz
        rm -rf ~/$flutter_dir && mv flutter-$flutter_version.part/flutter ~/$flutter_dir && rmdir flutter-$flutter_version.part
    fi"

# The host trusted by the key given and no other: a different key already known for the address stops the run.
known=$(on_vm "ssh-keygen -F '$address' 2>/dev/null | grep -v '^#' | cut -d' ' -f2- || true")
if [ -z "$known" ]; then
    on_vm "mkdir -p ~/.ssh && printf '%s %s\\n' '$address' '$host_key' >>~/.ssh/known_hosts"
    added_key=yes
elif [ "$known" != "$host_key" ]; then
    echo "rehearse: $vm knows another key for $address; remove it there first if the server was rented anew" >&2
    exit 1
fi

# The account's card is the person's only while the forwarded agent holds its key.
holds=$(as_the_person_on_vm "porelo identity show --json" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("agent_holds_key"))' || true)
[ "$holds" = True ] || {
    echo "rehearse: the agent forwarded to $vm does not hold the key of the card there" >&2
    exit 1
}

# The host's daemon socket, asked of the host as the person, through the forwarded agent.
socket=$(as_the_person_on_vm "ssh -x -o BatchMode=yes '$host' 'printf /run/user/%s/porelo/porelod.sock \$(id -u)'") || {
    echo "rehearse: $host cannot be reached from $vm with the test person's key" >&2
    exit 1
}

# porelod on the VM checks the organization with the agent its user service was given, which on the VM is not the
# person's. For the run it is given the forwarded one: a session of the person's held open, its agent named at a
# path of the run's, and porelod restarted on it; put back as it was on every ending. porelod's own environment
# cannot be read (it makes itself undumpable), so the fresh read of the organization below is the proof it holds.
as_the_person_on_vm "echo \$\$ >~/$run/agent.pid && ln -sfn \"\$SSH_AUTH_SOCK\" ~/$run/agent.sock && exec sleep infinity" </dev/null >/dev/null 2>&1 &
holder=$!
on_vm "for _ in \$(seq 50); do [ -S ~/$run/agent.sock ] && exit 0; sleep 0.2; done; exit 1" || {
    echo "rehearse: the person's agent could not be held open on $vm for porelod" >&2
    exit 1
}
agent_before=$(on_vm "systemctl --user show-environment | sed -n 's/^SSH_AUTH_SOCK=//p'")
shaped 'porelod agent' "$agent_before" '/[A-Za-z0-9/._-]*'
pointed=yes
on_vm "set -e; systemctl --user set-environment SSH_AUTH_SOCK=\$HOME/$run/agent.sock; systemctl --user restart porelod
    for _ in \$(seq 50); do [ -S /run/user/\$(id -u)/porelo/porelod.sock ] && break; sleep 0.2; done
    systemctl --user is-active --quiet porelod
    systemctl --user show-environment | grep -qx \"SSH_AUTH_SOCK=\$HOME/$run/agent.sock\"" || {
    echo "rehearse: porelod on $vm could not be started on the person's agent" >&2
    exit 1
}

# The central forge's token, for the organization's forge and owner as porelo on the VM names them, in a vault of the
# run's own: the account's vault is never opened, read or changed. Its passphrase is made on the VM and goes to the
# vault on standard input alone, kept nowhere but the cache the unlock fills; the vault goes with the run's copy. Every
# porelo call of the run names it in PORELO_VAULT. A declaration the VM person already has is used and left there.
in_vault=''
if [ -n "${REHEARSAL_CENTRAL_TOKEN:-}" ]; then
    [ -x "$REHEARSAL_CENTRAL_TOKEN" ] || {
        echo "rehearse: REHEARSAL_CENTRAL_TOKEN names no program" >&2
        exit 1
    }
    central_match=$(as_the_person_on_vm "porelo org --json --refresh" 2>/dev/null | python3 -I -c 'import json, re, sys
a = json.load(sys.stdin)
m = re.search(re.escape(a["forge"]) + r"[:/]+([A-Za-z0-9_.-]+)/", a["address"])
print(a["forge"] + "/" + m[1] + "/" if m else "")') || true
    shaped 'the organization forge' "$central_match" '[A-Za-z0-9.-]+/[A-Za-z0-9_.-]+/'
    [ -n "$central_match" ] || {
        echo "rehearse: porelo on $vm names no forge and owner of the organization" >&2
        exit 1
    }
    vault="\$HOME/$run/vault/vault.bin"
    in_vault="PORELO_VAULT=$vault "
    on_vm "set -e; umask 077; mkdir ~/$run/vault
        head -c 32 /dev/urandom | base64 -w0 | { cat; echo; } | ${in_vault}porelo vault init --passphrase-stdin >/dev/null" \
        </dev/null || {
        echo "rehearse: a vault of the run's own could not be made on $vm" >&2
        exit 1
    }
    token=$("$REHEARSAL_CENTRAL_TOKEN") || {
        echo "rehearse: the central token program failed" >&2
        exit 1
    }
    [ -n "$token" ] || {
        echo "rehearse: the central token program gave nothing" >&2
        exit 1
    }
    printf '%s\n' "$token" | on_vm "${in_vault}porelo vault put --json central-forge" >/dev/null || {
        token=''
        echo "rehearse: the central-forge token could not be put into the run's vault on $vm" >&2
        exit 1
    }
    token=''
    if as_the_person_on_vm "porelo credentials list" </dev/null | awk '{print $1}' | grep -qxF "$central_match"; then
        echo "rehearse: the person on $vm declares $central_match already; that declaration is used"
    else
        declared=yes
        as_the_person_on_vm "porelo credentials declare '$central_match' --kind token --vault central-forge" \
            </dev/null >/dev/null || {
            echo "rehearse: $central_match could not be declared on $vm" >&2
            exit 1
        }
    fi
fi

# Who porelo on the VM takes itself to be, kept beside it: an organization read as someone not in it lists no host.
as_the_person_on_vm "${in_vault}porelo identity show --json" >"$report/identity-on-vm.json" 2>&1 || true
# What the window will read of the organization, as the person on the VM, checked now rather than taken from what
# porelo kept: kept in the report, and the run stops here with its words where the answer is still the kept one or the
# host is not in it, instead of every scenario waiting for a host that cannot appear.
as_the_person_on_vm "${in_vault}porelo org --json --refresh" >"$report/org-on-vm.json" 2>"$report/org-on-vm.err" || {
    echo "rehearse: porelo on $vm cannot read the organization as the person: $(tail -n 1 "$report/org-on-vm.err")" >&2
    exit 1
}
python3 -I - "$report/org-on-vm.json" "$host_name" <<'EOF' >&2 || exit 1
import json, sys
answer = json.load(open(sys.argv[1]))
words = json.dumps(answer)
print(f"rehearse: the organization on the VM is at revision {answer.get('revision')}")
if answer.get('stale'):
    why = answer.get('stale_why') or {}
    sys.exit(f"rehearse: porelo on the VM could not check the organization and answers what it kept from "
             f"{answer.get('checked_at')}: {why.get('cause', 'no reason given')}; see org-on-vm.json")
if f'"{sys.argv[2]}"' not in words:
    sys.exit(f"rehearse: the organization porelo reads on the VM does not list the host {sys.argv[2]}; see org-on-vm.json")
EOF

echo "rehearse: the window against $host, at most $budget minutes"
status=0
# In a session of its own whose number is kept, so an ending here takes the whole of it down there too.
as_the_person_on_vm \
    "cd ~/$run && exec setsid sh -c 'echo \$\$ >pid; exec \"\$@\"' rehearse env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
        PATH=\$HOME/$flutter_dir/bin:\$PATH PORELO_E2E_HOST='$host' PORELO_E2E_REMOTE_SOCKET='$socket' PORELO_E2E_OWN_SETTINGS=1 $in_vault\
        PORELO_REHEARSAL_HOST_NAME='$host_name' PORELO_REHEARSAL_PROJECT='$project' \
        PORELO_REHEARSAL_HOST_KEY='$host_key' PORELO_REHEARSAL_SHOTS=\$HOME/$run/pictures \
        timeout --signal=TERM ${budget}m dbus-run-session -- \
        tool/e2e.sh --machine integration_test/rehearsing_a_move_test.dart" \
    >"$report/results.json" 2>"$report/run.log" || status=$?
# The pictures of failed scenarios, before the run's copy is taken away.
if on_vm "[ -d ~/$run/pictures ]"; then on_vm "tar -C ~/$run -c pictures" | tar -x -C "$report" || true; fi
[ "$status" -ne 124 ] || echo "rehearse: the window's part ran out its $budget minutes and was stopped" | tee -a "$report/run.log" >&2

(cd "$here" && dart tool/test_report.dart "$report/results.json" "$report/report.html" "$report/results.xml" \
    --heading='The move rehearsed in the window' --against="$host, from $vm" --lines="$report/scenarios.txt") || true
# Passed only where no scenario failed and one at least ran: no lines, a FAIL, or nothing but SKIPPED is a failed
# rehearsal, whatever the exit. A SKIPPED line says why it did not run.
if [ ! -s "$report/scenarios.txt" ]; then
    echo "rehearse: no scenario was reported; see $report/run.log" >&2
    [ "$status" -ne 0 ] || status=1
elif ! grep -q '^OK ' "$report/scenarios.txt"; then
    [ "$status" -ne 0 ] || status=1
elif grep -qv '^\(OK\|SKIPPED\) ' "$report/scenarios.txt"; then
    [ "$status" -ne 0 ] || status=1
fi
cat "$report/scenarios.txt" 2>/dev/null || true
exit "$status"
