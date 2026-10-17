import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: machine-signers no longer names {'porelo@old-box'}, committed signed
Future<void> machinesignersNoLongerNamesCommittedSigned(WidgetTester tester, String principal) async {
  expect(World.workspace.files['machine-signers'], isNot(contains(principal)));
  expect(World.workspace.files['machine-signers'], isNot(contains('# old-box')));
  expect(World.workspace.commits.last.names, <String>['machine-signers']);
  expect(World.workspace.commits.last.fingerprint, 'SHA256:person');
}
