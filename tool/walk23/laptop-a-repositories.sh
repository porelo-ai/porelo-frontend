#!/usr/bin/env bash
# Walk 23, the Laptop, in the operator's own account: makes or checks the project's two private test repositories in
# the GitHub organisation, walk6-demo for the project and walk6-demo-access for its access file. The operator's
# token, with Administration on exactly these two, is read without echo and reaches curl only through its standard
# input, never a command line, a file or a log. It says what it will do, refuses loudly and may be run again: a
# repository that is there and private is kept.
# Optionally grants the developer read access to the project repository alone; Developers manages the access file.
# Usage: bash laptop-a-repositories.sh (PORELO_GUIDE_DEVELOPER_LOGIN supplies the optional GitHub login)
set +x
set -euo pipefail
unset GIT_TRACE GIT_TRACE_CURL GIT_CURL_VERBOSE
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
developer_login=${PORELO_GUIDE_DEVELOPER_LOGIN:-}

step a-repositories.1 "the tools and names"
for tool in curl jq; do command -v "$tool" >/dev/null || refuse "$tool is missing; install it with: sudo apt install $tool"; done
for name in "$organisation" "$project"; do
    printf '%s\n' "$name" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' || refuse "$name is not a plain GitHub name"
done
echo "ok: $organisation/$project and $organisation/$project-access"

if [ -z "${PORELO_GUIDE_DEVELOPER_LOGIN+x}" ]; then
    [ -t 0 ] || refuse 'run in a terminal, or set PORELO_GUIDE_DEVELOPER_LOGIN (empty skips the invitation)'
    IFS= read -rp 'Developer GitHub login (empty skips project read access): ' developer_login
fi
if [ -n "$developer_login" ]; then
    [[ $developer_login =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] &&
        [[ $developer_login != *--* ]] || refuse 'the developer login is not a plain GitHub login'
fi

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
    local arguments=(-q --silent --show-error --location --max-redirs 3 --proto '=https' --proto-redir '=https'
        --config - --request "$method" --header 'Accept: application/vnd.github+json'
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

if [ -n "$developer_login" ]; then
    step a-repositories.developer "grant $developer_login read access to $organisation/$project only"
    answer=$(github GET "/repos/$organisation/$project/collaborators/$developer_login/permission")
    code=${answer##*$'\n'}
    if [ "$code" = 200 ]; then
        permission=$(printf '%s' "${answer%$'\n'*}" | jq -r '.permission')
        case $permission in
        read | none) ;;
        *) refuse 'the login has more than read access already; choose the developer test account without changing that access' ;;
        esac
    elif [ "$code" != 404 ]; then
        refuse "GitHub answered $code when checking the developer's existing permission"
    fi
    answer=$(github PUT "/repos/$organisation/$project/collaborators/$developer_login" '{"permission":"pull"}')
    code=${answer##*$'\n'}
    case $code in
    201) echo "ok: project read invitation sent to $developer_login; accept it on VM B" ;;
    204) echo "ok: project read access granted to $developer_login" ;;
    *) refuse "GitHub answered $code to granting project read access" ;;
    esac
fi
unset token

printf '\nlaptop-a-repositories passed\n'
