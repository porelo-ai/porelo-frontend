import 'package:flutter_test/flutter_test.dart';

import '../support/rehearsal.dart';
import '../support/remote.dart';

/// Usage: the rehearsal names its host and project
Future<void> theRehearsalNamesItsHostAndProject(WidgetTester tester) => pictured(tester, () async {
  Rehearsal.notRun = null;
  // Both named, or the run stops before anything is asked of the host.
  expect(Rehearsal.hostName, isNotEmpty);
  expect(Rehearsal.project, isNotEmpty);
  // The steps compare the screen with the host's own daemon, asked over the contract.
  expect(
    await onTheTestMachine('command -v varlinkctl || echo none'),
    isNot(contains('none')),
    reason: 'varlinkctl on the host',
  );
});
