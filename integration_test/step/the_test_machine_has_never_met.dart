import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the test machine has never met {'github.com'}
Future<void> theTestMachineHasNeverMet(WidgetTester tester, String host) async {
  // Porelo's own file, not the account's: what a run trusted before is forgotten, so this asks again.
  await onTheTestMachine('''
set -eu
f="\$HOME/.local/state/porelo/known_hosts"
[ ! -f "\$f" ] || ssh-keygen -q -R "$host" -f "\$f" >/dev/null 2>&1 || true
rm -f "\$f.old"
echo done
''');
}
