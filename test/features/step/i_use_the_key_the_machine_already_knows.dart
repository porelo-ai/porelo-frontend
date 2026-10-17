import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I use the key the machine already knows
Future<void> iUseTheKeyTheMachineAlreadyKnows(WidgetTester tester) async {
  // Chosen already: of the keys in ~/.ssh, one the wizard kept before comes first.
  final chosen = tester.widget<DropdownButton<String>>(find.byKey(const Key('existing-key'))).value;
  expect(chosen, endsWith('/.ssh/porelo-the-build-machine'));
  await World.tapInView(tester, 'use-key');
}
