import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I send a key of this computer into the vault for {'ssh://e2e-sent.invalid/'} from the interface
Future<void> iSendAKeyOfThisComputerIntoTheVaultForFromTheInterface(WidgetTester tester, String match) async {
  final pair = await aThrowawayKeyPair();
  await openTheConnectionWizard(tester);
  await tester.enterText(find.byKey(const Key('connection-match')), match);
  await choose(tester, 'connection-kind', 'kind-SSH_KEY');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await pumpUntilShown(tester, const Key('connection-way'));
  await choose(tester, 'connection-way', 'way-computer');
  await tester.enterText(find.byKey(const Key('connection-private-key')), pair.private);
  await pumpFor(tester);
  await tester.tap(find.byKey(const Key('wizard-next')));
  await untilTheMachineChecked(tester);
  await tester.tap(find.byKey(const Key('connection-add')));
  await pumpUntil(
    tester,
    () =>
        find.textContaining('is stored on').evaluate().isNotEmpty ||
        find.textContaining('Storing the key did not work').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to say whether the key is stored',
  );
  expect(find.textContaining('Storing the key did not work'), findsNothing);
}
