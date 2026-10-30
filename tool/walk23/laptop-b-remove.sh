#!/usr/bin/env bash
# Walk 23, laptop B, as root, after the walk, from the operator's own login (or the developer's, if that account was
# here before the walk and is kept): takes away what the walk added, by what laptop-b-make.sh recorded. That is the
# interface's VPN configurations (porelo-*), its /etc/hosts lines (*.porelo.internal) and the host CAs it trusted in
# the system and in Firefox, with Firefox's policy as it was; the developer's account with its home if the walk made
# it, or its sudo if the walk gave it; and porelo if it was not here before, or the porelo the walk replaced, put back
# from the package laptop-b-make.sh set aside. It says what it will do, refuses loudly, and may be run again.
# Usage, from the unpacked hand-over: sudo bash laptop-b-remove.sh
set -euo pipefail
current=
step() {
    current=$1
    printf '\n== %s: %s\n' "$1" "$2"
}
refuse() {
    printf '%s refused: %s\n' "${current:-laptop-b-remove}" "$*" >&2
    exit 1
}
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
state=/var/lib/porelo-walk23

step b-remove.1 "this runs as root, with laptop-b-make.sh's record"
[ "$(id -u)" -eq 0 ] || refuse "run it with sudo"
if [ ! -f "$state/complete" ]; then
    echo "ok: no record in $state, so nothing of the walk is left; nothing to do"
    exit 0
fi
developer=$(cat "$state/developer")
[[ $developer =~ ^[a-z][a-z0-9-]{0,30}$ ]] || refuse "the record names no plain account"
was_here=$(cat "$state/account-was-here")
case $was_here in
yes) made=no ;;
no) made=yes ;;
*) refuse "the record does not say whether $developer was here before the walk" ;;
esac
had_sudo=$(cat "$state/had-sudo-before")
case $had_sudo in
yes | no) ;;
*) refuse "the record does not say whether $developer had sudo before the walk" ;;
esac
# An account the walk made loses its processes below, so nothing this runs from may belong to it, however root was
# reached. An account that was here before is kept with its processes, and may run this itself.
uid=$(id -u "$developer" 2>/dev/null || true)
pid=$$
while [ "$made" = yes ] && [ -n "$uid" ] && [ "$pid" -gt 1 ]; do
    awk -v uid="$uid" '/^Uid:/ { for (i = 2; i <= 5; i++) if ($i == uid) found = 1 } END { exit !found }' "/proc/$pid/status" &&
        refuse "this runs inside $developer's login; log out of $developer and run it from your own"
    pid=$(awk '/^PPid:/ { print $2 }' "/proc/$pid/status")
done
echo "ok: record in $state for $developer"

step b-remove.2 "the VPN configurations the walk added are down and gone"
for conf in /etc/wireguard/porelo-*.conf; do
    [ -e "$conf" ] || continue
    name=$(basename -- "$conf")
    grep -qxF -- "$name" "$state/wireguard" && continue
    echo "taking down and removing ${name%.conf}"
    wg-quick down "${name%.conf}" 2>/dev/null || true
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
    grep -vxF -f <(printf '%s\n' "$added") /etc/hosts >"$kept" || true
    chmod --reference=/etc/hosts "$kept"
    chown --reference=/etc/hosts "$kept"
    mv -- "$kept" /etc/hosts
    echo "ok: those lines are gone; every other line stays"
fi

step b-remove.4 "the host CAs the walk trusted are gone, in the system and in Firefox"
if [ ! -f "$state/ca-sha256" ]; then
    echo "note: the record holds no record of the trusted host CAs, so none is taken away; check /usr/local/share/ca-certificates, /etc/firefox/porelo and /etc/firefox/policies by hand"
else
    for place in /usr/local/share/ca-certificates /etc/pki/ca-trust/source/anchors /etc/firefox /etc/firefox/porelo \
        /etc/firefox/policies /etc/firefox/policies/policies.json /etc/firefox/porelo/managed-policy.json; do
        [ ! -L "$place" ] || refuse "$place is a symbolic link now; put it right by hand and run this again"
    done
    # A CA stays only with the very content it had before the walk; any other is the walk's.
    for ca in /usr/local/share/ca-certificates/porelo-host-*.crt /etc/pki/ca-trust/source/anchors/porelo-host-*.crt \
        /etc/firefox/porelo/porelo-host-*.crt; do
        [ -e "$ca" ] || [ -L "$ca" ] || continue
        [ -f "$ca" ] && [ ! -L "$ca" ] && sha256sum -- "$ca" | grep -qxF -f - "$state/ca-sha256" && continue
        echo "removing $ca"
        rm -f -- "$ca"
    done
    if command -v update-ca-certificates >/dev/null; then update-ca-certificates >/dev/null; fi
    if command -v update-ca-trust >/dev/null; then update-ca-trust; fi
    for policy in /etc/firefox/policies/policies.json /etc/firefox/porelo/managed-policy.json; do
        kept=$state/firefox-$(basename -- "$policy")
        if [ -f "$kept" ]; then
            install -d -m 0755 -- "$(dirname -- "$policy")"
            staged=$(mktemp "$(dirname -- "$policy")/.walk23.XXXXXX")
            if ! { cp -p -- "$kept" "$staged" && mv -f -- "$staged" "$policy"; }; then
                rm -f -- "$staged"
                refuse "$policy could not be put back; the copy stays in $kept"
            fi
        else
            rm -f -- "$policy"
        fi
    done
    echo "ok: only the host CAs and Firefox policy from before the walk are left"
fi

step b-remove.5 "porelo as before the walk"
before=$(cat "$state/porelo-version")
status=$(dpkg-query -W -f='${db:Status-Status}' porelo 2>/dev/null || true)
case $status in
installed) now=$(dpkg-query -W -f='${Version}' porelo) ;;
'' | not-installed | config-files) now= ;;
*) refuse "porelo is $status, half installed; repair it with sudo apt-get -f install and run this again" ;;
esac
if [ "$now" = "$before" ]; then
    echo "ok: porelo ${before:-not installed}, as before"
elif [ -z "$before" ]; then
    echo "porelo was not here before the walk; apt asks before it removes it and anything that needs it"
    apt-get remove porelo
    echo "ok: porelo removed"
elif [ "$(dpkg-deb -f "$state/porelo-before.deb" Package 2>/dev/null)" != porelo ] ||
    [ "$(dpkg-deb -f "$state/porelo-before.deb" Version 2>/dev/null)" != "$before" ]; then
    echo "note: porelo stays at ${now:-not installed}; the record holds no good copy of porelo $before. Install it again from where it came if you want it back."
else
    echo "putting porelo $before back in place of ${now:-nothing}"
    apt-get install -y --allow-downgrades "$state/porelo-before.deb"
    [ "$(dpkg-query -W -f='${db:Status-Status} ${Version}' porelo 2>/dev/null || true)" = "installed $before" ] ||
        refuse "porelo $before did not install; the copy stays in $state/porelo-before.deb"
    echo "ok: porelo $before, as before"
fi

step b-remove.6 "the account $developer as it was before the walk"
if [ "$was_here" = yes ] && ! id "$developer" >/dev/null 2>&1; then
    echo "ok: $developer was here before the walk and is gone now; nothing to restore"
elif [ "$was_here" = yes ]; then
    if [ "$had_sudo" = no ] && id -nG "$developer" | tr ' ' '\n' | grep -qx sudo; then
        echo "taking $developer out of the sudo group, as before the walk"
        gpasswd -d "$developer" sudo
    fi
    echo "ok: $developer was here before the walk; kept"
elif id "$developer" >/dev/null 2>&1; then
    echo "ending $developer's processes and removing the account with its home"
    pkill -KILL -U "$developer" || true
    pkill -KILL -u "$developer" || true
    left() { pgrep -U "$developer" >/dev/null || pgrep -u "$developer" >/dev/null; }
    for _ in $(seq 20); do
        left || break
        sleep 0.5
    done
    left && refuse "$developer's processes do not end; log it out and run this again"
    userdel --remove "$developer"
    echo "ok: $developer removed"
else
    echo "ok: $developer is gone already"
fi

rm -rf -- "$state"
printf '\nlaptop-b-remove passed\n'
