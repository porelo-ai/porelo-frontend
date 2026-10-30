#!/usr/bin/env bash
# Walk 23, laptop B, as root: makes the developer's account, gives it sudo (the VPN is brought up as root), and
# installs the porelo package handed over beside this script. Every handed-over file is checked against SHA256SUMS,
# and SHA256SUMS itself against the digest the walk shows, given as the one argument. It says what it will do before
# doing it, refuses loudly, and may be run again: what is in place already is left as it is. It records what was
# here before, so that laptop-b-remove.sh takes away only what the walk added; a porelo already installed is set
# aside in that record as a package of its own (dpkg-repack), so that laptop-b-remove.sh can put it back.
# Usage, from the unpacked hand-over: sudo bash laptop-b-make.sh <SHA-256 of SHA256SUMS, from the walk>
set -euo pipefail
current=
step() {
    current=$1
    printf '\n== %s: %s\n' "$1" "$2"
}
refuse() {
    printf '%s refused: %s\n' "${current:-laptop-b-make}" "$*" >&2
    exit 1
}
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
developer=${PORELO_WALK_DEVELOPER:-walkdev}
state=/var/lib/porelo-walk23
installed() { [ "$(dpkg-query -W -f='${db:Status-Status}' porelo 2>/dev/null || true)" = installed ]; }
# Whether the package file given is porelo at the version given.
porelo_at() { [ "$(dpkg-deb -f "$1" Package 2>/dev/null)" = porelo ] && [ "$(dpkg-deb -f "$1" Version 2>/dev/null)" = "$2" ]; }

step b-make.1 "this runs as root on the laptop the developer walks"
[ "$(id -u)" -eq 0 ] || refuse "run it with sudo"
if [ "$#" -ne 1 ] || ! [[ $1 =~ ^[0-9a-f]{64}$ ]]; then
    refuse "give the SHA-256 of SHA256SUMS the walk shows as the one argument"
fi
[[ $developer =~ ^[a-z][a-z0-9-]{0,30}$ ]] || refuse "PORELO_WALK_DEVELOPER must be a plain account name"
for tool in sha256sum awk apt-get dpkg-deb useradd usermod passwd wg wg-quick keepassxc-cli; do
    command -v "$tool" >/dev/null || refuse "$tool is missing; install it first"
done
echo "ok: root, developer account $developer, tools present"

step b-make.2 "every handed-over file is the one handed over"
[ "$(sha256sum <"$here/SHA256SUMS" | cut -d' ' -f1)" = "$1" ] || refuse "SHA256SUMS in $here is not the one the walk names"
(cd "$here" && sha256sum --quiet --strict -c SHA256SUMS) || refuse "the hand-over in $here does not match its SHA256SUMS"
mapfile -t debs < <(cd "$here" && find . -maxdepth 1 -name 'porelo_*_amd64.deb' -printf '%f\n')
[ "${#debs[@]}" -eq 1 ] || refuse "beside this script must be exactly one porelo_*_amd64.deb; there are ${#debs[@]}"
deb=${debs[0]}
awk -v name="$deb" '{ file = substr($0, 67); sub(/^\*/, "", file); sub(/^\.\//, "", file); if (file == name) found = 1 } END { exit !found }' \
    "$here/SHA256SUMS" || refuse "$deb is not named in SHA256SUMS"
echo "ok: $(wc -l <"$here/SHA256SUMS") files, package $deb"

step b-make.3 "what is here before the walk is recorded once"
if [ -f "$state/complete" ]; then
    [ "$(cat "$state/developer")" = "$developer" ] || refuse "the record is for $(cat "$state/developer"), not $developer"
    [ -f "$state/ca-sha256" ] || refuse "the record holds no record of the trusted host CAs; run laptop-b-remove.sh first"
    [ ! -s "$state/porelo-version" ] || porelo_at "$state/porelo-before.deb" "$(cat "$state/porelo-version")" ||
        refuse "the record names porelo $(cat "$state/porelo-version") but holds no good copy of it; run laptop-b-remove.sh first"
    echo "ok: recorded already in $state, kept"
else
    if id "$developer" >/dev/null 2>&1; then
        account=yes
        [ "$(passwd -S "$developer" | awk '{ print $2 }')" = P ] ||
            refuse "$developer is here without a password; give it one yourself, as the walk does not change it"
    elif [ -e "/home/$developer" ] || [ -L "/home/$developer" ]; then
        refuse "/home/$developer is there without an account; move it away first, so that the removal cannot take it"
    else
        account=no
    fi
    record=$(mktemp -d /var/lib/porelo-walk23.XXXXXX)
    trap 'rm -rf -- "$record"' EXIT
    printf '%s\n' "$developer" >"$record/developer"
    printf '%s\n' "$account" >"$record/account-was-here"
    if [ "$account" = yes ] && id -nG "$developer" | tr ' ' '\n' | grep -qx sudo; then sudo=yes; else sudo=no; fi
    printf '%s\n' "$sudo" >"$record/had-sudo-before"
    case $(dpkg-query -W -f='${db:Status-Status}' porelo 2>/dev/null || true) in
    installed)
        dpkg-query -W -f='${Version}\n' porelo >"$record/porelo-version"
        command -v dpkg-repack >/dev/null ||
            refuse "porelo $(cat "$record/porelo-version") is installed and dpkg-repack is missing to set it aside; install it with: sudo apt install dpkg-repack"
        echo "setting porelo $(cat "$record/porelo-version") aside as a package"
        (cd "$record" && dpkg-repack porelo >/dev/null)
        mapfile -t aside < <(find "$record" -maxdepth 1 -name 'porelo_*.deb' -printf '%f\n')
        [ "${#aside[@]}" -eq 1 ] || refuse "dpkg-repack did not leave exactly one porelo package"
        mv -- "$record/${aside[0]}" "$record/porelo-before.deb"
        porelo_at "$record/porelo-before.deb" "$(cat "$record/porelo-version")" ||
            refuse "the package dpkg-repack left is not porelo $(cat "$record/porelo-version")"
        ;;
    '' | not-installed | config-files) : >"$record/porelo-version" ;;
    *) refuse "porelo is half installed; repair it with sudo apt-get -f install and run this again" ;;
    esac
    find /etc/wireguard -maxdepth 1 -name '*.conf' -printf '%f\n' >"$record/wireguard" 2>/dev/null || : >"$record/wireguard"
    cp /etc/hosts "$record/hosts"
    # The trust the walk may add: the host CAs in the system and Firefox, by content, and Firefox's two policies.
    for place in /usr/local/share/ca-certificates /etc/pki/ca-trust/source/anchors /etc/firefox /etc/firefox/porelo \
        /etc/firefox/policies /etc/firefox/policies/policies.json /etc/firefox/porelo/managed-policy.json; do
        [ ! -L "$place" ] || refuse "$place is a symbolic link; the walk could not put it back"
    done
    for ca in /usr/local/share/ca-certificates/porelo-host-*.crt /etc/pki/ca-trust/source/anchors/porelo-host-*.crt \
        /etc/firefox/porelo/porelo-host-*.crt; do
        [ -e "$ca" ] || continue
        [ -f "$ca" ] || refuse "$ca is not a plain file; the walk could not put it back"
        sha256sum -- "$ca"
    done >"$record/ca-sha256"
    for policy in /etc/firefox/policies/policies.json /etc/firefox/porelo/managed-policy.json; do
        if [ -f "$policy" ]; then
            cp -p -- "$policy" "$record/firefox-$(basename -- "$policy")"
        elif [ -e "$policy" ]; then
            refuse "$policy is not a plain file; the walk could not put it back"
        fi
    done
    touch "$record/complete"
    rm -rf -- "$state"
    mv -- "$record" "$state"
    trap - EXIT
    chmod 0700 "$state"
    before=$(cat "$state/porelo-version")
    echo "ok: recorded in $state: porelo ${before:-not installed}${before:+, set aside}, account $account, sudo $sudo, the VPN configurations, /etc/hosts and the trusted host CAs"
fi

step b-make.4 "the account $developer, with a password, in the sudo group"
if ! id "$developer" >/dev/null 2>&1; then
    [ "$(cat "$state/account-was-here")" = no ] ||
        refuse "$developer was here before the walk and is gone; run laptop-b-remove.sh first, so that the record starts anew"
    echo "making the account $developer with a home"
    useradd --create-home --shell /bin/bash "$developer"
fi
if [ "$(passwd -S "$developer" | awk '{ print $2 }')" = P ]; then
    echo "ok: $developer is here with a password"
elif [ "$(cat "$state/account-was-here")" = no ]; then
    echo "$developer has no password yet; passwd asks it now"
    passwd "$developer"
else
    refuse "$developer was here before the walk and has lost its password; give it one yourself, as the walk does not change it"
fi
if id -nG "$developer" | tr ' ' '\n' | grep -qx sudo; then
    echo "ok: $developer is in the sudo group"
else
    echo "adding $developer to the sudo group"
    usermod -aG sudo "$developer"
    echo "ok: $developer is in the sudo group"
fi

step b-make.5 "porelo from the hand-over is installed"
wanted=$(dpkg-deb -f "$here/$deb" Version)
if installed && [ "$(dpkg-query -W -f='${Version}' porelo)" = "$wanted" ]; then
    echo "ok: porelo $wanted is installed already"
else
    echo "installing porelo $wanted from $deb"
    apt-get install -y "$here/$deb"
fi
installed && [ "$(dpkg-query -W -f='${Version}' porelo)" = "$wanted" ] || refuse "porelo $wanted did not install"
echo "ok: porelo $wanted"

printf '\nlaptop-b-make passed: log out and log in as %s, then run laptop-b-start.sh there\n' "$developer"
