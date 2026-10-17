#!/usr/bin/env bash
# Runs the GUI integration tests against a real Porelo machine.
#
#   PORELO_E2E_HOST=user@host \
#   PORELO_E2E_REMOTE_SOCKET=/run/user/<uid>/porelo/porelod.sock \
#   PORELO_E2E_KEY=~/.ssh/the_key_for_that_host \
#   tool/e2e.sh [integration_test/connecting_test.dart]
#
# The app gets a config and runtime directory of its own and ssh a private agent holding only that
# key, so a running interface, its settings and the person's ssh setup are all left alone.
#
# Shell, not Java: what it builds is the environment of external programs - the app's own ssh, an
# ssh-agent, known_hosts, Xvfb - and Porelo's Java tooling speaks ssh inside the JVM, with no agent,
# no known_hosts and no forwards, and starts no program against a machine.
# The lease and the sweep around it are Java, in pom.xml.
set -euo pipefail

# A machine leased by the build (-Phetzner) names itself in this file; otherwise the caller does.
leased=build/leased.properties
forget_host=''
if [ -z "${PORELO_E2E_HOST:-}" ] && [ -f "$leased" ]; then
    value() { grep "^$1=" "$leased" | cut -d= -f2-; }
    address=$(value address)
    export PORELO_E2E_HOST="$(value user)@$address" PORELO_E2E_REMOTE_SOCKET="$(value socket)"
    export PORELO_E2E_KEY="${PORELO_E2E_KEY:-${HETZNER_KEY:-}}"
    # A fresh machine's host key is unknown, and the interface never accepts one on its own.
    mkdir -p ~/.ssh
    ssh-keyscan -H "$address" >>~/.ssh/known_hosts 2>/dev/null
    forget_host=$address
fi
: "${PORELO_E2E_HOST:?name the machine as ssh would, e.g. user@host}"
: "${PORELO_E2E_REMOTE_SOCKET:?the daemon socket on that machine}"

here=$(mktemp -d)
agent=''
# A homeserver's port is forwarded while the window runs, no longer only while its dialog is open,
# and a test ending is not a window closing. The port forwards to the test machine that run before
# this one are somebody else's and stay; the ones this run raised go.
port_forwards() { pgrep -f -- "ssh -N .*-L [0-9]+:localhost:[0-9]+ $PORELO_E2E_HOST\$" || true; }
before=" $(port_forwards | tr '\n' ' ') "
cleanup() {
    # The app raises its forwards with ssh, and a test ending is not a window closing: nothing takes
    # them down. Every one raised under this run's directory goes, even after a crash.
    pkill -f -- "-L $here/run/" 2>/dev/null || true
    for pid in $(port_forwards); do
        case "$before" in *" $pid "*) ;; *) kill "$pid" 2>/dev/null || true ;; esac
    done
    if [ -n "$agent" ]; then kill "$agent" 2>/dev/null || true; fi
    if [ -n "$forget_host" ]; then ssh-keygen -R "$forget_host" >/dev/null 2>&1 || true; fi
    rm -rf "$here"
}
trap cleanup EXIT
mkdir -p "$here/run" "$here/config"
chmod 700 "$here/run"

if [ -n "${PORELO_E2E_KEY:-}" ] || [ -n "${HETZNER_SSH:-}" ]; then
    eval "$(ssh-agent -s -a "$here/agent.sock")" >/dev/null
    agent=$SSH_AGENT_PID
    if [ -n "${PORELO_E2E_KEY:-}" ]; then
        ssh-add -q "${PORELO_E2E_KEY/#\~/$HOME}"
    else
        # CI hands the key over as material, and a secret is never written to a file: a pipe it is.
        printf '%s\n' "$HETZNER_SSH" | ssh-add -q -
    fi
fi

# Headless only: a test window on somebody's desktop takes their keyboard mid-sentence.
command -v xvfb-run >/dev/null || {
    echo "xvfb-run is missing: sudo apt install xvfb" >&2
    exit 1
}
unset WAYLAND_DISPLAY
export GDK_BACKEND=x11 XDG_RUNTIME_DIR="$here/run" XDG_CONFIG_HOME="$here/config"

# Options pass through (CI adds --machine); the target is added when none was named, or
# flutter would run `test/` instead. One file: a desktop app is started once per run, and a second
# file's start fails. The walk of a person new to Porelo empties its account, so it runs only named:
#   PORELO_E2E_NEW_PERSON=1 PORELO_E2E_HOST=<an empty account>@host … tool/e2e.sh integration_test/a_new_person_test.dart
target=integration_test/reaching_a_machine_test.dart
for argument in "$@"; do
    case "$argument" in -*) ;; *) target='' ;; esac
done
# Xvfb hides only the window: the app's notifications (notify-send) went to the person's desktop
# ("grant needed on e2e machine"). A notify-send that shows nothing comes first on the
# app's PATH. Not a D-Bus session of its own: flutter installed as a snap cannot start without theirs.
mkdir -p "$here/bin"
printf '#!/bin/sh\nexit 0\n' >"$here/bin/notify-send"
chmod 755 "$here/bin/notify-send"
export PATH="$here/bin:$PATH"

# A cancelled build signals only its step's shell, so what runs below it - Maven, this script, the
# test driving the machine - would run on until the runner kills orphans at the job's end. The test
# runs in a process group of its own and goes whole on INT or TERM, or once a process that started
# this script has ended; the cleanup above then takes the forwards down.
ancestors=''
pid=$PPID
while [ "$pid" -gt 1 ]; do
    ancestors="$ancestors $pid"
    pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
done
test_run=''
watch=''
stop() {
    trap - INT TERM
    if [ -n "$watch" ]; then kill "$watch" 2>/dev/null || true; fi
    if [ -n "$test_run" ]; then kill -TERM -- "-$test_run" 2>/dev/null || true; fi
    echo "e2e: stopped, the build that ran it was cancelled" >&2
    exit 130
}
trap stop INT TERM
setsid xvfb-run -a -s '-screen 0 1280x800x24' flutter test -d linux "$@" $target &
test_run=$!
(
    while sleep 1; do
        for ancestor in $ancestors; do
            kill -0 "$ancestor" 2>/dev/null || {
                kill -TERM $$
                exit 0
            }
        done
    done
) &
watch=$!
status=0
wait "$test_run" || status=$?
kill "$watch" 2>/dev/null || true
exit "$status"
