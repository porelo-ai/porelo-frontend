import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';
import 'the_test_machine_has_an_entry_a_standin_service_grants.dart';

/// Usage: the machine keeps the token of {'e2e-lasting'} itself, and removing it names where it is ended
///
/// A token no service can revoke for Porelo is kept, not removed, by a plain remove, which names the
/// place a person ends it; forgetting it is asked for in so many words.
Future<void> theMachineKeepsTheTokenOfItselfAndRemovingItNamesWhereItIsEnded(WidgetTester tester, String entry) async {
  final said = await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
porelo vault remove $entry 2>&1 || true
echo "--- listed"
porelo vault list
echo "--- forgotten"
porelo vault remove --without-revoking $entry 2>&1
pkill -f "stand_in_authorization.py $standInPort" || true
rm -f "\$HOME/stand_in_authorization.py"
echo "--- left"
porelo vault list
''');
  final kept = said.substring(said.indexOf('--- listed'), said.indexOf('--- forgotten'));
  final left = said.substring(said.indexOf('--- left'));
  expect(kept, contains(entry), reason: said);
  expect(left, isNot(contains(entry)), reason: said);
  // ignore: avoid_print
  print('remove said: ${said.substring(0, said.indexOf('--- listed')).trim()}');
}
