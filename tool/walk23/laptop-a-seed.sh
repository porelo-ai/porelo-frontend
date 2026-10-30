#!/usr/bin/env bash
# Seeds the two private walk repositories through the caller's Git credentials and SSH signing setup. Both
# repositories are checked before either is pushed; an existing signed seed is kept and other content is refused.
# Usage, on VM A in walkadmin's account: bash /var/tmp/walk23/laptop-a-seed.sh
# Git's user.signingkey supplies the sole comment-free public signer; the protected key stays in its agent.
set +x
set -euo pipefail
umask 077
unset GIT_TRACE GIT_TRACE_PACKET GIT_TRACE_CURL GIT_CURL_VERBOSE GIT_TRACE_SETUP GIT_TRACE2 GIT_TRACE2_EVENT GIT_TRACE2_PERF
current=a-seed.start
work=
step() {
    current=$1
    printf '\n== %s: %s\n' "$1" "$2"
}
refuse() {
    printf '%s refused: %s\n' "$current" "$*" >&2
    exit 1
}
cleanup() { [ -z "$work" ] || rm -rf -- "$work"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'printf "%s failed\n" "$current" >&2' ERR

step a-seed.1 'check tools, names and your own Git signing setup'
[ "$#" -eq 0 ] || refuse 'usage on VM A: bash /var/tmp/walk23/laptop-a-seed.sh'
for tool in git python3 ssh-keygen mktemp cmp; do command -v "$tool" >/dev/null || refuse "$tool is missing"; done
organisation=${PORELO_GUIDE_ORGANISATION:-porelo-ai}
project=${PORELO_GUIDE_PROJECT:-walk6-demo}
[[ $organisation =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}$ ]] || refuse 'the organization is not a plain GitHub name'
[[ $project =~ ^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$ ]] ||
    refuse 'use a lower-case project name with letters, digits and hyphens, at most 40 characters'
[ "$(git config --bool --get commit.gpgsign || true)" = true ] ||
    refuse 'set git config --global commit.gpgsign true before seeding'
[ "$(git config --get gpg.format || true)" = ssh ] ||
    refuse 'set git config --global gpg.format ssh before seeding'
signing=$(git config --path --get user.signingkey || true)
[ -n "$signing" ] || refuse 'set git config --global user.signingkey to your ssh-ed25519 signing key file'
author=$(git config --get user.name || true)
email=$(git config --get user.email || true)
[ -n "$author" ] && [ -n "$email" ] || refuse 'set git config --global user.name and git config --global user.email'
case "$signing" in
key::*)
    public=${signing#key::}
    ;;
*)
    [[ $signing = /* ]] || signing=$PWD/$signing
    if [[ $signing = *.pub ]]; then
        public_file=$signing
    else public_file=$signing.pub; fi
    public=$(
        python3 - "$public_file" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
if p.is_symlink() or not p.is_file() or p.stat().st_size > 8192:
    sys.exit('a-seed: choose a plain ssh-ed25519 public signing key file')
try:
    text = p.read_text()
    if not re.fullmatch(r'ssh-ed25519 [A-Za-z0-9+/]+={0,2}\n?', text):
        sys.exit('a-seed: user.signingkey needs one comment-free ssh-ed25519 public line')
    print(text.removesuffix('\n'))
except (OSError, UnicodeError):
    sys.exit('a-seed: cannot read the public signing key')
PY
    ) || refuse 'set git config --global user.signingkey to an ssh-ed25519 key with a readable .pub file'
    ;;
esac
public=$(printf '%s' "$public" | python3 -c '
import base64, re, struct, sys
try:
    line = sys.stdin.read()
    assert re.fullmatch(r"ssh-ed25519 [A-Za-z0-9+/]+={0,2}", line)
    blob = base64.b64decode(line.split(" ")[1], validate=True)
    assert len(blob) == 51 and blob[:4] == struct.pack(">I", 11)
    assert blob[4:15] == b"ssh-ed25519" and blob[15:19] == struct.pack(">I", 32)
    print(line)
except (ValueError, AssertionError):
    sys.exit("a-seed: set git config --global user.signingkey to one comment-free ssh-ed25519 public key")
') || refuse 'git config --global user.signingkey must name one comment-free ssh-ed25519 public signing key'
cache=${XDG_CACHE_HOME:-$HOME/.cache}/porelo/walk23
mkdir -p -- "$cache"
work=$(mktemp -d "$cache/seed.XXXXXX")
printf 'walk %s\n' "$public" >"$work/allowed-signers"
git_options=(-c "user.name=$author" -c "user.email=$email" -c commit.gpgsign=true -c gpg.format=ssh
    -c "user.signingkey=$signing" -c "gpg.ssh.allowedSignersFile=$work/allowed-signers")
if program=$(git config --get gpg.ssh.program); then git_options+=(-c "gpg.ssh.program=$program"); fi
git_own() { GIT_TERMINAL_PROMPT=0 git "${git_options[@]}" "$@"; }

step a-seed.2 'prepare public project settings and an empty private developer list'
python3 - "$work" "$project" "$organisation" "$public" <<'PY'
import json, pathlib, sys
work, project, org, signer = sys.argv[1:]
url = f'https://github.com/{org}/{project}.git'
document = {
    'project': {'name': project, 'security_class': 'guarded', 'signers': [signer]},
    'image': {'base_image': 'ubuntu:24.04'},
    'repositories': {project: {'upstream': url}},
    'access': {'repository': f'https://github.com/{org}/{project}-access.git'},
    'mail': {'peers': {'people': {'address': 'matrix:', 'trust': 'external'}}},
}
root = pathlib.Path(work)
# JSON is YAML too, with no interpolation of a public key into YAML syntax.
(root / 'project.yml').write_text(json.dumps(document, indent=2) + '\n')
(root / 'access.yml').write_text('developers: {}\n')
PY

step a-seed.3 'check both remotes before publishing anything'
for suffix in '' -access; do
    repository=$project$suffix
    url=https://github.com/$organisation/$repository.git
    file=project.yml
    [ -z "$suffix" ] || file=access.yml
    directory=$work/$repository
    refs=$(git_own ls-remote --refs "$url" 2>/dev/null) || refuse "cannot read $repository with your Git credentials"
    if [ -z "$refs" ]; then
        echo "$repository: empty; will add one signed main commit containing $file"
        git_own init --quiet --initial-branch=main "$directory" >/dev/null 2>&1 || refuse 'Git could not initialize the seed'
        git_own -C "$directory" remote add origin "$url"
        cp -- "$work/$file" "$directory/$file"
        git_own -C "$directory" add -- "$file"
        git_own -C "$directory" commit --quiet -m 'Prepare the signed walk project' >/dev/null 2>&1 ||
            refuse 'Git could not sign; check user.signingkey, gpg.format ssh, commit.gpgsign true and your SSH agent'
    else
        [ "$(printf '%s\n' "$refs" | cut -f2)" = refs/heads/main ] || refuse "$repository has refs other than main; kept unchanged"
        git_own clone --quiet --single-branch --branch main -- "$url" "$directory" >/dev/null 2>&1 ||
            refuse "cannot clone $repository with your Git credentials"
        [ "$(git_own -C "$directory" rev-list --count HEAD)" = 1 ] || refuse "$repository has other history; kept unchanged"
        [ "$(git_own -C "$directory" ls-tree HEAD)" = "$(git_own -C "$directory" ls-tree HEAD -- "$file")" ] ||
            refuse "$repository has other content; kept unchanged"
        mode=$(git_own -C "$directory" ls-tree HEAD -- "$file")
        [[ $mode = '100644 blob '* ]] || refuse "$repository does not hold a plain $file"
        cmp -s -- "$work/$file" "$directory/$file" || refuse "$repository has different $file content; kept unchanged"
        echo "$repository: the seed content is already there; will keep its commit"
    fi
    git_own -C "$directory" verify-commit HEAD >/dev/null 2>&1 || refuse "$repository is not signed by your configured ssh-ed25519 key"
done

step a-seed.4 'publish only a missing main and read both remote commits back'
for repository in "$project-access" "$project"; do
    directory=$work/$repository
    expected=$(git_own -C "$directory" rev-parse HEAD)
    # An empty expected old ref prevents replacing a main created while the seed was being checked.
    observed=$(git_own -C "$directory" ls-remote origin refs/heads/main 2>/dev/null | cut -f1) || refuse "cannot read $repository main"
    if [ -z "$observed" ]; then
        git_own -C "$directory" push --quiet --force-with-lease=refs/heads/main: origin HEAD:refs/heads/main >/dev/null 2>&1 ||
            refuse "$repository push refused; check Git credentials and whether main was created concurrently"
    else
        [ "$observed" = "$expected" ] || refuse "$repository main changed while checking; kept unchanged"
    fi
    observed=$(git_own -C "$directory" ls-remote origin refs/heads/main 2>/dev/null | cut -f1) || refuse "cannot confirm $repository main"
    [ "$observed" = "$expected" ] || refuse "$repository main is not the signed seed commit"
    printf 'ok: %s main %s\n' "$repository" "$observed"
done
echo 'laptop-a-seed passed'
