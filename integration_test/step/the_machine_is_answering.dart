import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/new_person.dart';

/// Usage: the machine is answering
Future<void> theMachineIsAnswering(WidgetTester tester) async {
  await toTheMachines(tester);
  if (!walkingAsANewPerson) return;
  await pumpUntil(
    tester,
    () => find.byKey(ValueKey<String>('rail-machine ${E2e.name}')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to be among the machines',
  );
  await switchTo(tester, E2e.name);
  await pumpFor(tester, const Duration(seconds: 3));
  noteTheWindow(tester, 'the machine, watched');
}
