import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';

/// Usage: Needs you holds no held saves of {'checkout'}
Future<void> needsYouHoldsNoHeldSavesOf(WidgetTester tester, String project) async {
  expect(heldSavesInNeedsYou(project), findsNothing);
}
