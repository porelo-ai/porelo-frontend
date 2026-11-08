import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine the start was pressed on is forgotten
///
/// Forgotten behind whatever is open, as a forget from another window of the same settings would.
Future<void> theMachineTheStartWasPressedOnIsForgotten(WidgetTester tester) async {
  expect(
    find.byKey(const Key('first-start')),
    findsOneWidget,
    reason: 'the question before the first task is not open',
  );
  await World.machines.forget(World.machines.all.first);
  await World.settle(tester);
}
