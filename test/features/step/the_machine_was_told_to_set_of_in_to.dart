import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was told to set {'reviewer'} of {'porelo-checkout-migrate'} in {'checkout'} to {'off'}
Future<void> theMachineWasToldToSetOfInTo(
  WidgetTester tester,
  String peer,
  String task,
  String project,
  String mode,
) async {
  expect(World.backend.moderated, [(task: task, project: project, name: peer, held: null, mode: mode)]);
}
