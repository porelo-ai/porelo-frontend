#!/usr/bin/env bash
# Walk 23, laptop B, as root, after the walk, from the operator's own login, not the developer's: takes away what
# the walk added, by what laptop-b-make.sh recorded. That is the interface's VPN configurations (porelo-*) and its
# /etc/hosts lines (*.porelo.internal) added since; the developer's account with its home if the walk made it, or
# its sudo if the walk gave it; and porelo if it was not here before. A porelo the walk replaced stays at the
# walk's version, which this says. It says what it will do, refuses loudly, and may be run again.
# Usage, from the unpacked hand-over: sudo bash laptop-b-remove.sh
set -euo pipefail
current=
step() { current=$1; printf '\n== %s: %s\n' "$1" "$2"; }
refuse() { printf '%s refused: %s\n' "${current:-laptop-b-remove}" "$*" >&2; exit 1; }
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
state=/var/lib/porelo-walk23

step b-remove.1 "this runs as root, with laptop-b-make.sh's record"
[ "$(id -u)" -eq 0 ] || refuse "run it with sudo"
if [ ! -f "$state/complete" ]; then
    echo "ok: no record in $state, so nothing of the walk is left; nothing to do"
    exit 0
fi
developer=$(cat "$state/developer")
[ "${SUDO_USER:-}" != "$developer" ] || refuse "log out of $developer and run this from your own login"
echo "ok: record in $state for $developer"

step b-remove.2 "the VPN configurations the walk added are down and gone"
for conf in /etc/wireguard/porelo-*.conf; do
    [ -e "$conf" ] || continue
    name=$(basename -- "$conf")
    grep -qxF -- "$name" "$state/wireguard" && continue
    echo "taking down and removing ${name%.conf}"
    wg-quick down "${name%.conf}" 2> /dev/null || true
    rm -f -- "$conf"
done
echo "ok: no porelo VPN configuration is left that was not here before"

step b-remove.3 "the /etc/hosts lines the walk added are gone"
added=$( (grep -vxF -f "$state/hosts" /etc/hosts || true) | (grep -E '[[:space:]][^[:space:]]*\.porelo\.internal([[:space:]]|$)' || true))
if [ -z "$added" ]; then
    echo "ok: no porelo line was added to /etc/hosts"
else
    printf 'removing these lines:\n%s\n' "$added"
    kept=$(mktemp /etc/hosts.walk23.XXXXXX)
    grep -vxF -f <(printf '%s\n' "$added") /etc/hosts > "$kept" || true
    chmod --reference=/etc/hosts "$kept"
    chown --reference=/etc/hosts "$kept"
    mv -- "$kept" /etc/hosts
    echo "ok: those lines are gone; every other line stays"
fi

step b-remove.4 "the account $developer as it was before the walk"
if [ "$(cat "$state/account-was-here")" = yes ]; then
    if [ "$(cat "$state/sudo-was-given")" = no ] && id -nG "$developer" | tr ' ' '\n' | grep -qx sudo; then
        echo "taking $developer out of the sudo group, as before the walk"
        gpasswd -d "$developer" sudo
    fi
    echo "ok: $developer was here before the walk; kept"
elif id "$developer" > /dev/null 2>&1; then
    echo "ending $developer's processes and removing the account with its home"
    pkill -KILL -u "$developer" || true
    for _ in $(seq 20); do pgrep -u "$developer" > /dev/null || break; sleep 0.5; done
    pgrep -u "$developer" > /dev/null && refuse "$developer's processes do not end; log it out and run this again"
    userdel --remove "$developer"
    echo "ok: $developer removed"
else
    echo "ok: $developer is gone already"
fi

step b-remove.5 "porelo as before the walk"
before=$(cat "$state/porelo-version")
if [ "$(dpkg-query -W -f='${db:Status-Status}' porelo 2> /dev/null || true)" = installed ]; then
    now=$(dpkg-query -W -f='${Version}' porelo)
else
    now=
fi
if [ "$now" = "$before" ]; then
    echo "ok: porelo ${before:-not installed}, as before"
elif [ -z "$before" ]; then
    echo "porelo was not here before the walk; apt asks before it removes it and anything that needs it"
    apt-get remove porelo
    echo "ok: porelo removed"
else
    echo "note: porelo stays at $now; the walk replaced $before, and apt keeps no copy of it. Install $before again from where it came if you want it back."
fi

rm -rf -- "$state"
printf '\nlaptop-b-remove passed\n'
