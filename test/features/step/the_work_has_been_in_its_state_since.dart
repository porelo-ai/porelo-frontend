import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-billing-shell'} has been in its state since {'2026-10-03T08:00:00Z'}
Future<void> theWorkHasBeenInItsStateSince(WidgetTester tester, String work, String since) async {
  World.theWorkIs(work, activity: '', since: since);
  await World.settle(tester);
}
