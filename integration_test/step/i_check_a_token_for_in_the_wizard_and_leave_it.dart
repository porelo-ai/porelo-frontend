import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: I check a token for {'https://e2e.invalid/'} in the wizard, and leave it
Future<void> iCheckATokenForInTheWizardAndLeaveIt(WidgetTester tester, String match) async {
  await openTheConnectionWizard(tester);
  await tester.enterText(find.byKey(const Key('connection-match')), match);
  await choose(tester, 'connection-kind', 'kind-TOKEN');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await pumpUntilShown(tester, const Key('connection-way'));
  await choose(tester, 'connection-way', 'way-vault');
  await tester.tap(find.byKey(const Key('wizard-next')));
  // The real daemon's dry run, which writes nothing.
  await pumpUntil(
    tester,
    () => find.byKey(const Key('connection-check-says')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to check it',
  );
  final detail = find.byKey(const Key('connection-check-detail'));
  theCheckSaid = detail.evaluate().isEmpty ? '' : tester.widget<Text>(detail).data;
  await tester.tap(find.byKey(const Key('connection-leave')));
  await pumpFor(tester);
}
