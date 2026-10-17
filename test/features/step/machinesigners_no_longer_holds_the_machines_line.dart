import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: machine-signers no longer holds the machine's line
Future<void> machinesignersNoLongerHoldsTheMachinesLine(WidgetTester tester) async {
  expect(World.workspace.files['machine-signers'], isNot(contains('porelo@vm ssh-ed25519 AAAAmsg')));
  expect(World.workspace.commits.last.names, <String>['machine-signers']);
}
