import 'package:flutter_test/flutter_test.dart';

import '../../support/menu_entries.dart';

/// Usage: the action {'Rename it'} is offered as unavailable
Future<void> theActionIsOfferedAsUnavailable(WidgetTester tester, String action) async {
  // Opened from its submenu first, where it stands in one, as a person would.
  final entry = await revealMenuEntryLabeled(tester, action);
  expect(entry, findsOneWidget, reason: '$action should be offered');
  expect(menuEntryEnabled(tester, entry), isFalse, reason: '$action should not be runnable now');
  expect(find.descendant(of: entry, matching: find.textContaining('Unavailable')), findsOneWidget);
}
