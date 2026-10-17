import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the vault entry of that key is removed again
Future<void> theVaultEntryOfThatKeyIsRemovedAgain(WidgetTester tester) async {
  // Forgetting the record keeps the value, as the interface says; the scenario leaves nothing behind.
  final entry = theVaultEntry;
  expect(entry, isNotNull, reason: 'no vault entry was recorded');
  await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo vault remove $entry >/dev/null');
  final left = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo vault list');
  expect(left, isNot(contains(entry)));
}
