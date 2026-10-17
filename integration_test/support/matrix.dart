import 'remote.dart';

/// Makes sure the test machine's account can carry a project's messages over Matrix: the transport
/// and the homeserver's unit, where the machine has neither, taken unprivileged from the published
/// packages into the account, each checked against the index's SHA256, as the filter is; never over
/// what is installed. The unit runs the transport from the account's copy. Answers whether the
/// transport is there afterwards.
///
/// Matrix is the transport that keeps a conversation today; a project without one has no peers at
/// all, so every scenario that messages needs it.
Future<bool> matrixInTheAccount() async =>
    await onTheTestMachine(r'''
set -eu
data="${XDG_DATA_HOME:-$HOME/.local/share}/porelo"; units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
transport=porelo-message-transport-matrix
if [ ! -x "/usr/libexec/porelo/transports/$transport" ] && [ ! -x "$data/transports/$transport" ]; then
  repo=https://fuinorg.jfrog.io/artifactory/porelo-dist-deb
  index=$(curl -fsSL "$repo/dists/snapshots/main/binary-amd64/Packages")
  for package in $transport porelo-matrix-homeserver; do
    set -- $(printf '%s\n' "$index" | awk -v p="$package" '$0 == "Package: " p {x = 1}
      x && /^Filename:/ {f = $2} x && /^SHA256:/ {h = $2} /^$/ {x = 0} END {print f, h}')
    [ -n "${1:-}" ] || { echo "$package is not in the index" >&2; exit 1; }
    work=$(mktemp -d)
    curl -fsSL -o "$work/p.deb" "$repo/$1"
    echo "$2  $work/p.deb" | sha256sum -c --quiet -
    dpkg-deb -x "$work/p.deb" "$work/x"
    case $package in
      $transport) mkdir -p "$data/transports"
                  install -m 755 "$work/x/usr/libexec/porelo/transports/$transport" "$data/transports/";;
      *) mkdir -p "$units/porelo-matrix-homeserver.service.d"
         install -m 644 "$work/x/usr/lib/systemd/user/porelo-matrix-homeserver.service" "$units/"
         printf '[Service]\nExecStartPre=\nExecStartPre=%%h/.local/share/porelo/transports/%s homeserver-token\n' \
           "$transport" > "$units/porelo-matrix-homeserver.service.d/account.conf"
         systemctl --user daemon-reload;;
    esac
    rm -rf "$work"
  done
fi
[ -x "/usr/libexec/porelo/transports/$transport" ] || [ -x "$data/transports/$transport" ] && echo yes || echo no
''') ==
    'yes';
