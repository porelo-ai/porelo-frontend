#!/usr/bin/env bash
# Prepares the signed project source shared by the interactive and automated host walks.
set -eu
set -o pipefail
umask 077

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo 'walk-project: give the existing walk folder containing keys/walk_ed25519 and its public half' >&2
    exit 64
fi
walk_project=$(cd -- "$1" && pwd)
for file in project project.bundle project-commit allowed-signers; do
    if [ -e "$walk_project/$file" ] || [ -L "$walk_project/$file" ]; then
        echo "walk-project: refusing existing $walk_project/$file" >&2
        exit 1
    fi
done
for key in walk_ed25519 walk_ed25519.pub; do
    test -f "$walk_project/keys/$key" || {
        echo "walk-project: missing $walk_project/keys/$key" >&2
        exit 1
    }
done
cleanup() {
    local status=$?
    if [ "$status" -ne 0 ]; then
        rm -rf -- "$walk_project/project" "$walk_project/project.bundle" "$walk_project/project-commit" "$walk_project/allowed-signers"
    fi
    exit "$status"
}
trap cleanup EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir "$walk_project/project"
git -C "$walk_project/project" init --initial-branch=main
git -C "$walk_project/project" config user.name 'Walk fixture'
git -C "$walk_project/project" config user.email walk@example.invalid
git -C "$walk_project/project" config gpg.format ssh
git -C "$walk_project/project" config user.signingkey "$walk_project/keys/walk_ed25519"
printf 'name: checkout\n' >"$walk_project/project/project.yml"
git -C "$walk_project/project" add project.yml
git -C "$walk_project/project" commit -S -m 'Signed walk project'
printf 'walk@example.invalid %s\n' "$(cat "$walk_project/keys/walk_ed25519.pub")" >"$walk_project/allowed-signers"
git -C "$walk_project/project" -c "gpg.ssh.allowedSignersFile=$walk_project/allowed-signers" verify-commit HEAD
git -C "$walk_project/project" rev-parse HEAD >"$walk_project/project-commit"
git -C "$walk_project/project" bundle create "$walk_project/project.bundle" HEAD main
