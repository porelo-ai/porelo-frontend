import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: I check the machine's own key for {'https://e2e.invalid/'} in the wizard
Future<void> iCheckTheMachinesOwnKeyForInTheWizard(WidgetTester tester, String match) async {
  await openTheConnectionWizard(tester);
  await tester.enterText(find.byKey(const Key('connection-match')), match);
  await choose(tester, 'connection-kind', 'kind-SSH_KEY');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await pumpUntilShown(tester, const Key('connection-way'));
  await choose(tester, 'connection-way', 'way-machine');
  await pumpUntil(
    tester,
    () => find.byKey(const Key('connection-key')).evaluate().isNotEmpty,
    what: 'the machine to list its keys',
  );
  await choose(tester, 'connection-key', 'key $theKey');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await untilTheMachineChecked(tester);
}
