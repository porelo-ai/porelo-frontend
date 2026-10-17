import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was told to refuse {'msg-1.json'} of {'porelo-checkout-shell'}
Future<void> theMachineWasToldToRefuseOf(WidgetTester tester, String message, String task) async {
  expect(World.backend.released, [(task: task, id: message, refuse: true)]);
}
