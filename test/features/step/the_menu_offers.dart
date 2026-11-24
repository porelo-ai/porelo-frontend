import 'package:flutter_test/flutter_test.dart';

import '../../support/menu_entries.dart';

/// Usage: the menu offers {'Work in it by hand'}
Future<void> theMenuOffers(WidgetTester tester, String label) async {
  expect(await revealMenuEntryLabeled(tester, label), findsOneWidget);
}
