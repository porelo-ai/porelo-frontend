import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the machine {'the build machine'} says the forward is raised here
Future<void> theMachineSaysTheForwardIsRaisedHere(WidgetTester tester, String name) async {
  // Which kind a machine is decides what happens when it stops answering and when the window
  // closes, so its page says it rather than leaving it to be inferred.
  await toTheMachinesPage(tester, name);
  expect(
    find.descendant(
      of: find.byKey(const Key('machine-kind')),
      matching: find.textContaining('forward raised here'),
      matchRoot: true,
    ),
    findsOneWidget,
  );
}
