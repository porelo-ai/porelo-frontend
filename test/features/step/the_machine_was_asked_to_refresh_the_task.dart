import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was asked to refresh the task {'porelo-checkout-shell'}
Future<void> theMachineWasAskedToRefreshTheTask(WidgetTester tester, String task) async {
  expect(World.backend.taskRefreshes, <String>[task]);
}
