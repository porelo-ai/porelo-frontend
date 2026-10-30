#!/usr/bin/env bash
# Walk 23, laptop A, in the operator's own account: makes or checks the project's two private test repositories in
# the GitHub organisation, walk6-demo for the project and walk6-demo-access for its access file. The operator's
# token, with Administration on exactly these two, is read without echo and reaches curl only through its standard
# input, never a command line, a file or a log. It says what it will do, refuses loudly and may be run again: a
# repository that is there and private is kept.
# Usage: bash laptop-a-repositories.sh
set -euo pipefail
current=
step() {
    current=$1
    printf '\n== %s: %s\n' "$1" "$2"
}
refuse() {
    printf '%s refused: %s\n' "${current:-laptop-a-repositories}" "$*" >&2
    exit 1
}
trap 'printf "\n%s failed\n" "${current:-the start}" >&2' ERR
organisation=${PORELO_GUIDE_ORGANISATION:-porelo-ai}
project=${PORELO_GUIDE_PROJECT:-walk6-demo}
api=https://api.github.com

step a-repositories.1 "the tools and names"
for tool in curl jq; do command -v "$tool" >/dev/null || refuse "$tool is missing; install it with: sudo apt install $tool"; done
for name in "$organisation" "$project"; do
    printf '%s\n' "$name" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' || refuse "$name is not a plain GitHub name"
done
echo "ok: $organisation/$project and $organisation/$project-access"

step a-repositories.2 "your token, read without echo"
[ -t 0 ] || refuse "run it in a terminal; the token is typed, never piped"
IFS= read -rsp "GitHub token with Administration on $organisation/$project and $organisation/$project-access: " token
echo
# A GitHub token is letters, digits and _; anything else is refused without saying it back.
printf '%s' "$token" | grep -Eq '^[A-Za-z0-9_]{20,255}$' || refuse "that is not a GitHub token"
# The token goes to curl as a header in its own configuration on standard input, never on its command line; -q
# keeps a ~/.curlrc from adding a trace that would print it.
github() {
    local method=$1 url=$2
    local arguments=(-q --silent --show-error --config - --request "$method" --header 'Accept: application/vnd.github+json'
        --header 'X-GitHub-Api-Version: 2022-11-28' --write-out '\n%{http_code}')
    [ "$#" -lt 3 ] || arguments+=(--data "$3")
    printf 'header = "Authorization: Bearer %s"\n' "$token" | curl "${arguments[@]}" "$api$url"
}
echo "ok: token read"

for repository in "$project" "$project-access"; do
    step "a-repositories.$repository" "$organisation/$repository is there and private"
    answer=$(github GET "/repos/$organisation/$repository")
    code=${answer##*$'\n'}
    if [ "$code" = 404 ]; then
        echo "making $organisation/$repository, private and empty"
        answer=$(github POST "/orgs/$organisation/repos" "$(jq -cn --arg name "$repository" '{name: $name, private: true}')")
        code=${answer##*$'\n'}
        [ "$code" = 201 ] || refuse "GitHub answered $code to making it; make $organisation/$repository private on github.com, give the token Administration on it, and run this again"
    elif [ "$code" != 200 ]; then
        refuse "GitHub answered $code; check the token's access to $organisation/$repository"
    fi
    private=$(printf '%s' "${answer%$'\n'*}" | jq -r '.private')
    [ "$private" = true ] || refuse "$organisation/$repository is public; the walk needs it private"
    echo "ok: $organisation/$repository, private"
done
unset token

printf '\nlaptop-a-repositories passed\n'
