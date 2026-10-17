import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was told to hold {'reviewer'} of {'porelo-checkout-migrate'} in {'checkout'}
Future<void> theMachineWasToldToHoldOfIn(WidgetTester tester, String peer, String task, String project) async {
  expect(World.backend.moderated, [(task: task, project: project, name: peer, held: true, mode: null)]);
}
