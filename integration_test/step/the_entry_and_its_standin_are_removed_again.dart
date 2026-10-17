import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';
import 'the_test_machine_has_an_entry_a_standin_service_grants.dart';

/// Usage: the entry {'e2e-grant'} and its stand-in are removed again
Future<void> theEntryAndItsStandinAreRemovedAgain(WidgetTester tester, String entry) async {
  // Removing revokes at the service first, which the stand-in answers; nothing is left behind.
  final left = await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
porelo vault remove $entry >/dev/null
pkill -f "stand_in_authorization.py $standInPort" || true
rm -f "\$HOME/stand_in_authorization.py"
porelo vault list
''');
  expect(left, isNot(contains(entry)));
}
