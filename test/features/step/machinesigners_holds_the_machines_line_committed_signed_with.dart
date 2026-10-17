import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: machine-signers holds the machine's line, committed signed with {'SHA256:person'}
Future<void> machinesignersHoldsTheMachinesLineCommittedSignedWith(WidgetTester tester, String fingerprint) async {
  expect(World.workspace.files['machine-signers'], contains('porelo@vm ssh-ed25519 AAAAmsg'));
  final commit = World.workspace.commits.last;
  expect(commit.names, <String>['machine-signers']);
  expect(commit.fingerprint, fingerprint);
}
