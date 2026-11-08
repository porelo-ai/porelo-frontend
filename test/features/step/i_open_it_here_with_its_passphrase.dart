import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open it here with its passphrase
///
/// The vault's own page offers it as its main action, in the head above the vault's facts.
Future<void> iOpenItHereWithItsPassphrase(WidgetTester tester) async {
  await World.tapInView(tester, 'vault.passphrase');
}
