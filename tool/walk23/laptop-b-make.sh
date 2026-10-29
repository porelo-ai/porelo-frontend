#!/usr/bin/env bash
# Walk 23, laptop B, as root: makes the developer's account, gives it sudo (the VPN is brought up as root), and
# installs the porelo package handed over beside this script after checking every file against SHA256SUMS. It says
# what it will do before doing it, refuses loudly, and may be run again: what is in place already is left as it is.
# It records what was here before, so that laptop-b-remove.sh takes away only what the walk added.
# Usage, from the unpacked hand-over: sudo bash laptop-b-make.sh
set -euo pipefail
current=
step() { current=$1; printf '\n== %s: %s\n' "$1" "$2"; }
refuse() { printf '%s refused: %s\n' "${current:-laptop-b-make}" "$*" >&2; exit 1; }
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
here=$(cd "$(dirname "$0")" && pwd)
developer=${PORELO_WALK_DEVELOPER:-walkdev}
state=/var/lib/porelo-walk23

step b-make.1 "this runs as root on the laptop the developer walks"
[ "$(id -u)" -eq 0 ] || refuse "run it with sudo"
printf '%s\n' "$developer" | grep -Eq '^[a-z][a-z0-9-]{0,30}$' || refuse "PORELO_WALK_DEVELOPER must be a plain account name"
for tool in sha256sum apt-get useradd usermod passwd wg wg-quick keepassxc-cli; do
    command -v "$tool" > /dev/null || refuse "$tool is missing; install it first"
done
echo "ok: root, developer account $developer, tools present"

step b-make.2 "every handed-over file is the one handed over"
(cd "$here" && sha256sum --quiet --strict -c SHA256SUMS) || refuse "the hand-over in $here does not match its SHA256SUMS"
deb=$(cd "$here" && find . -maxdepth 1 -name 'porelo_*_amd64.deb' -printf '%f\n' | head -n 1)
[ -n "$deb" ] || refuse "no porelo_*_amd64.deb beside this script"
grep -q " \(\./\)\?$deb\$" "$here/SHA256SUMS" || refuse "$deb is not named in SHA256SUMS"
echo "ok: $(wc -l < "$here/SHA256SUMS") files, package $deb"

step b-make.3 "what is here before the walk is recorded once"
if [ -d "$state" ]; then
    echo "ok: recorded already in $state, kept"
else
    install -d -m 0700 "$state"
    dpkg-query -W -f='${Version}\n' porelo > "$state/porelo-version" 2> /dev/null || : > "$state/porelo-version"
    ls /etc/wireguard > "$state/wireguard" 2> /dev/null || : > "$state/wireguard"
    cp /etc/hosts "$state/hosts"
    if id "$developer" > /dev/null 2>&1; then echo yes > "$state/account-was-here"; else echo no > "$state/account-was-here"; fi
    echo "ok: recorded in $state: porelo $(cat "$state/porelo-version"), the VPN configurations and /etc/hosts"
fi

step b-make.4 "the account $developer, in the sudo group"
if id "$developer" > /dev/null 2>&1; then
    echo "ok: $developer is here already, kept"
else
    echo "making the account $developer with a home; passwd asks its password next"
    useradd --create-home --shell /bin/bash "$developer"
    passwd "$developer"
fi
if id -nG "$developer" | tr ' ' '\n' | grep -qx sudo; then
    echo "ok: $developer is in the sudo group"
else
    usermod -aG sudo "$developer"
    echo "ok: $developer added to the sudo group"
fi

step b-make.5 "porelo from the hand-over is installed"
wanted=$(dpkg-deb -f "$here/$deb" Version)
if [ "$(dpkg-query -W -f='${Version}' porelo 2> /dev/null || true)" = "$wanted" ]; then
    echo "ok: porelo $wanted is installed already"
else
    echo "installing porelo $wanted from $deb"
    apt-get install -y "$here/$deb"
fi
[ "$(dpkg-query -W -f='${Version}' porelo)" = "$wanted" ] || refuse "porelo $wanted did not install"
echo "ok: porelo $wanted"

printf '\nlaptop-b-make passed: log out and log in as %s, then run laptop-b-start.sh there\n' "$developer"
