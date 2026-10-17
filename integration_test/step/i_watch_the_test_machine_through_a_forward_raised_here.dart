import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I watch the test machine through a forward raised here
Future<void> iWatchTheTestMachineThroughAForwardRaisedHere(WidgetTester tester) async {
  await watchAnotherMachine(tester);
  await tester.enterText(find.byKey(const Key('machine-name')), E2e.name);
  // Porelo runs there already, set up by somebody else: only connecting to it is offered and wanted.
  await choose(tester, 'machine-admin', 'machine-admin-no');
  await choose(tester, 'machine-kind-choice', 'machine-raise-it');
  await goOnInTheWizard(tester);
  await tester.enterText(find.byKey(const Key('machine-host')), E2e.host);
  await tester.enterText(find.byKey(const Key('machine-remote-socket')), E2e.remoteSocket);
  await pumpFor(tester);
  await tester.tap(find.byKey(const Key('watch-it')));
  await untilTheDialogCloses(tester);
}
