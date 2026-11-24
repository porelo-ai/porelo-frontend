import 'package:flutter_test/flutter_test.dart';

import '../../support/menu_entries.dart';

/// Usage: the menu does not offer {'Unlock the vault, so this can start'}
Future<void> theMenuDoesNotOffer(WidgetTester tester, String label) async {
  // Every submenu is looked into, so an entry moved into one is not taken for one gone.
  expect(await revealMenuEntryLabeled(tester, label), findsNothing);
}
