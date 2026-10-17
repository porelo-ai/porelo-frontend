import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the test machine has an open vault
Future<void> theTestMachineHasAnOpenVault(WidgetTester tester) async {
  // Made there when there is none, with a passphrase kept owner-only in that account and never
  // printed; opened for as long as a run takes. Whether there is one is asked of the machine. The
  // account's own porelo first on PATH, as a login shell would put it, since a script over ssh gets
  // none.
  await onTheTestMachine(r'''
set -eu
PATH="$HOME/.local/bin:$PATH"
umask 077
f="$HOME/.config/porelo-test/vault-passphrase"
mkdir -p "$(dirname "$f")"
[ -f "$f" ] || head -c 32 /dev/urandom | base64 -w0 > "$f"
# Asked, never read off an exit code: 'vault unlock' answers 0 on an account with no vault at all.
if porelo vault list 2>&1 | grep -q '^no vault at'; then
  porelo vault init --passphrase-command="cat $f" >/dev/null
fi
porelo vault unlock --for=15m --passphrase-command="cat $f" >/dev/null
if porelo vault list 2>&1 | grep -q '^no vault at'; then
  echo "there is still no vault after making one" >&2; exit 1
fi
''');
}
