import 'package:flutter_test/flutter_test.dart';

import '../../support/menu_entries.dart';

/// Usage: the menu offers {'Work in it by hand'} as unavailable because {'forwarded'}
Future<void> theMenuOffersAsUnavailableBecause(WidgetTester tester, String label, String reason) async {
  final item = await revealMenuEntryLabeled(tester, label);
  expect(item, findsOneWidget);
  expect(menuEntryEnabled(tester, item), isFalse);
  expect(find.descendant(of: item, matching: find.textContaining(reason)), findsOneWidget);
}
