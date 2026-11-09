import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';
import '../support/remote.dart';

/// Usage: the host is answering through the window
Future<void> theHostIsAnsweringThroughTheWindow(WidgetTester tester) => pictured(tester, () async {
  // The version the host's porelo gives, on the host's page: read through the window's own link to its daemon.
  final version = (await onTheTestMachine('porelo --version')).trim().split(RegExp(r'\s+')).last;
  expect(version, isNotEmpty);
  await toTheMachines(tester);
  await pumpUntil(tester, () => theHostsEntry().evaluate().isNotEmpty, what: 'the host under My machines');
  await tester.ensureVisible(theHostsEntry().first);
  await tester.tap(theHostsEntry().first);
  await pumpFor(tester);
  await pumpUntil(
    tester,
    () => find.textContaining(version).evaluate().isNotEmpty,
    timeout: const Duration(minutes: 1),
    what: 'the host page to name porelo $version',
  );
});
