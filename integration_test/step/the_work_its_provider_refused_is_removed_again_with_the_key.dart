import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';
import 'work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart';

/// Usage: the work its provider refused is removed again, with the key {'anthropic'}
Future<void> theWorkItsProviderRefusedIsRemovedAgainWithTheKey(WidgetTester tester, String entry) async {
  await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
set -e
porelo task remove --force $refusedTask >/dev/null
porelo project unfollow --force $refusedByItsProvider >/dev/null
rm -rf "\$HOME/$refusedByItsProvider"
porelo vault remove --without-revoking $entry >/dev/null
''');
  final left = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo task list; porelo vault list');
  expect(left, isNot(contains(refusedTask)));
  expect(left, isNot(contains(RegExp('^$entry ', multiLine: true))), reason: 'the vault still holds $entry');
}
