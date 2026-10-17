import 'package:flutter_test/flutter_test.dart';

import '../support/matrix.dart';
import '../support/project_file.dart';
import '../support/remote.dart';

/// Usage: the test machine has a task {'e2e-talk'} with a message held for {'reviewer'} saying {'...'}
///
/// A project declaring one peer, a task of it with a shell and no agent (no credential needed),
/// the peer held, and a person's message to it moved along once: held for a person, not sent.
Future<void> theTestMachineHasATaskWithAMessageHeldForSaying(
  WidgetTester tester,
  String name,
  String peer,
  String text,
) async {
  // The project messages through Matrix, the transport that keeps a conversation: without one it
  // would have no peers to hold a message for.
  expect(await matrixInTheAccount(), isTrue, reason: 'the Matrix transport could not be installed');
  theHeldMessage = await onTheTestMachine('''
set -eu
PATH="\$HOME/.local/bin:\$PATH"
repo="\$HOME/$name"
task="porelo-$name-$name"
porelo task stop "\$task" >/dev/null 2>&1 || true
porelo task remove "\$task" >/dev/null 2>&1 || true
porelo project unfollow --force "$name" >/dev/null 2>&1 || true
rm -rf "\$repo" "\$repo-backend.git"; mkdir -p "\$repo"
# Its work repository in the account itself: a task's start meets the host of every repository it
# works in, and a bare repository here has none to meet.
git init -q --bare -b main "\$repo-backend.git"
cd "\$repo"
git init -q -b main
cat > project.yml <<YAML
${projectFile(name, backend: '\$repo-backend.git')}
mail:
  transports:
    matrix: {}
  peers:
    $peer:
      address: "matrix:"
      trust: vouched
YAML
git add project.yml
git -c user.name=e2e -c user.email=e2e@example.invalid commit -q -m "The project $name"
porelo project follow --unverified "$name" "\$repo" >/dev/null
# The message filter, where the machine has none: without it nothing is passed or held. The Matrix
# transport the project messages through is made sure of before this runs. Taken unprivileged from the published packages into this account's data
# directory, where Porelo looks first; never over what is installed.
data="\${XDG_DATA_HOME:-\$HOME/.local/share}/porelo"
repo_url=https://fuinorg.jfrog.io/artifactory/porelo-dist-deb
for pair in porelo-message-sluice-filter:filter; do
  program=\${pair%%:*}; into=\${pair##*:}; package=\$(basename "\$program")
  [ -x "/usr/libexec/porelo/\$program" ] || [ -x "\$data/\$into/\$package" ] && continue
  work=\$(mktemp -d)
  # The newest entry's file and its digest, as the index published them; -L, since a large file
  # answers with a redirect to its storage.
  set -- \$(curl -fsSL "\$repo_url/dists/snapshots/main/binary-amd64/Packages" |
    awk -v p="\$package" '\$0 == "Package: " p {x = 1} x && /^Filename:/ {f = \$2} x && /^SHA256:/ {h = \$2}
      /^\$/ {x = 0} END {print f, h}')
  curl -fsSL -o "\$work/p.deb" "\$repo_url/\$1"
  # What is installed is what the index published, checked before anything is unpacked.
  echo "\$2  \$work/p.deb" | sha256sum -c --quiet -
  dpkg-deb -x "\$work/p.deb" "\$work/x"
  mkdir -p "\$data/\$into"
  install -m 755 "\$work/x/usr/libexec/porelo/\$program" "\$data/\$into/\$package"
  rm -rf "\$work"
done
# The task is started only for its mailbox, which does not depend on an agent. With none installed,
# as on a machine the lease made, it starts with none; with several, as on the VM, start asks for
# one, and any does: it is never run, the task gets a shell and needs no credential.
# "no agents installed" is the line porelo prints when there is none.
if porelo agents | head -1 | grep -q '^no agents installed'; then
  porelo task start -p "$name" -r backend --attach shell --no-gate --detach "$name" >/dev/null
else
  agent=\$(porelo agents | awk '\$1 == "NAME" {table = 1; next} table && NF {print \$1; exit}')
  porelo task start -p "$name" -r backend --agent "\$agent" --attach shell --no-gate --detach "$name" >/dev/null
fi
porelo talk hold "\$task" "$peer" >/dev/null
printf '%s' '$text' | porelo talk say "\$task" "$peer" >/dev/null
passed=\$(porelo talk pass "\$task" 2>&1 || true)
held=\$(porelo talk held "\$task" | awk '\$2 == "held" {print \$1; exit}')
# What the pass said, when nothing came of it: a machine without the message filter holds nothing.
case "\$held" in *.json) echo "\$held" ;; *) printf 'nothing held; the pass said:\n%s\n' "\$passed" ;; esac
''');
  expect(theHeldMessage, endsWith('.json'), reason: 'nothing was held for a person on the test machine');
}
