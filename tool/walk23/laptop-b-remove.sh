#!/usr/bin/env bash
# Walk 23, laptop B, as root, after the walk: takes away what the walk added and only that, by what
# laptop-b-make.sh recorded. It brings down and removes the VPN configurations that were not here before, takes the
# /etc/hosts lines added since, removes the developer's account with its home if the walk made it, and puts back
# the porelo version that was here before. It says what it will do, refuses loudly, and may be run again.
# Usage, from the unpacked hand-over: sudo bash laptop-b-remove.sh
set -euo pipefail
current=
step() { current=$1; printf '\n== %s: %s\n' "$1" "$2"; }
refuse() { printf '%s refused: %s\n' "${current:-laptop-b-remove}" "$*" >&2; exit 1; }
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
developer=${PORELO_WALK_DEVELOPER:-walkdev}
state=/var/lib/porelo-walk23

step b-remove.1 "this runs as root, with laptop-b-make.sh's record"
[ "$(id -u)" -eq 0 ] || refuse "run it with sudo"
printf '%s\n' "$developer" | grep -Eq '^[a-z][a-z0-9-]{0,30}$' || refuse "PORELO_WALK_DEVELOPER must be a plain account name"
if [ ! -d "$state" ]; then
    echo "ok: no record in $state, so nothing of the walk is left; nothing to do"
    exit 0
fi
echo "ok: record in $state"

step b-remove.2 "the VPN configurations the walk added are down and gone"
for conf in /etc/wireguard/*.conf; do
    [ -e "$conf" ] || continue
    name=$(basename "$conf")
    if grep -qx "$name" "$state/wireguard"; then continue; fi
    echo "taking down and removing ${name%.conf}"
    wg-quick down "${name%.conf}" 2> /dev/null || true
    rm -f -- "$conf"
done
echo "ok: only the configurations from before are left"

step b-remove.3 "the /etc/hosts lines the walk added are gone"
if cmp -s /etc/hosts "$state/hosts"; then
    echo "ok: /etc/hosts is as before"
else
    added=$(grep -vxFf "$state/hosts" /etc/hosts || true)
    printf 'removing these lines:\n%s\n' "$added"
    grep -xFf "$state/hosts" /etc/hosts > /etc/hosts.walk23 || true
    cat /etc/hosts.walk23 > /etc/hosts
    rm -f /etc/hosts.walk23
    echo "ok: /etc/hosts holds only the lines from before"
fi

step b-remove.4 "the account $developer, if the walk made it"
if [ "$(cat "$state/account-was-here")" = yes ]; then
    echo "ok: $developer was here before the walk; kept"
elif id "$developer" > /dev/null 2>&1; then
    echo "ending $developer's processes and removing the account with its home"
    pkill -KILL -u "$developer" || true
    userdel --remove "$developer"
    echo "ok: $developer removed"
else
    echo "ok: $developer is gone already"
fi

step b-remove.5 "porelo is back at the version from before"
before=$(cat "$state/porelo-version")
now=$(dpkg-query -W -f='${Version}' porelo 2> /dev/null || true)
if [ "$now" = "$before" ]; then
    echo "ok: porelo ${before:-not installed}, as before"
elif [ -z "$before" ]; then
    apt-get remove -y porelo
    echo "ok: porelo removed, as it was not here before"
else
    echo "porelo $now stays: the walk replaced $before, and apt keeps no copy of it. Install $before again from where it came if you want it back."
fi

rm -rf -- "$state"
printf '\nlaptop-b-remove passed\n'
