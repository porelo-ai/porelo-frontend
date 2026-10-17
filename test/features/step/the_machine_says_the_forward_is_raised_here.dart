import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the machine {'the build machine'} says the forward is raised here
Future<void> theMachineSaysTheForwardIsRaisedHere(WidgetTester tester, String name) async {
  await toTheMachines(tester);
  // Which kind a machine is decides what happens when it stops answering and when the window
  // closes, so its title says it rather than leaving it to be inferred.
  await tapOnScreen(tester, railEntryFor(name));
  await World.settle(tester);
  expect(
    find.descendant(
      of: find.byKey(const Key('machine-kind')),
      matching: find.textContaining('forward raised here'),
      matchRoot: true,
    ),
    findsOneWidget,
  );
}
