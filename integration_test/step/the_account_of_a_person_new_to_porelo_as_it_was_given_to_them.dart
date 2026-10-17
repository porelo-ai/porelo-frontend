import 'package:flutter_test/flutter_test.dart';

import '../support/new_person.dart';
import '../support/remote.dart';

/// Usage: the account of a person new to Porelo, as it was given to them
///
/// As it was made: Porelo installed on the machine and set up for the account, nothing of
/// Porelo's used yet - no daemon running, no vault, no project, no task, no connection. What an
/// earlier walk left is taken away first, the daemon stopped and its containers removed.
Future<void> theAccountOfAPersonNewToPoreloAsItWasGivenToThem(WidgetTester tester) async {
  if (!walkingAsANewPerson) {
    markTestSkipped('the walk of a new person runs only with PORELO_E2E_NEW_PERSON=1');
    return;
  }
  final left = await onTheTestMachine(r'''
set -u
systemctl --user stop porelod 2>/dev/null || true
podman rm -af >/dev/null 2>&1 || true
rm -rf "$HOME/.local/share/porelo" "$HOME/.config/porelo" "$HOME/.cache/porelo" "$HOME/work"
find "$HOME/.local/state/porelo" -mindepth 1 -maxdepth 1 ! -name default -exec rm -rf {} + 2>/dev/null || true
systemctl --user is-active porelod 2>/dev/null || true
ls -A "$HOME/.local/share" "$HOME/.local/state/porelo"
''');
  expect(left, isNot(contains('porelo\n')), reason: left);
}
