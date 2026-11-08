import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_open_the_machine_dialog.dart';

/// Usage: I start watching another machine
Future<void> iStartWatchingAnotherMachine(WidgetTester tester) async {
  await iOpenTheMachineDialog(tester);
  // A name, because the wizard goes on only with one; a scenario that cares names its own.
  await tester.enterText(find.byKey(const Key('machine-name')), 'the build machine');
  await World.settle(tester);
  // The socket-somebody-else-forwarded kind. Nothing is preselected in the dialog, deliberately.
  await World.pick(tester, 'machine-already-forwarded');
}
